#!/usr/bin/env python3
"""Transcribe photos of handwritten pages in your notes with a local Ollama model.

Tag a note "ocr" (in Neovim or Obsidian, on any device) and put the photos of the
pages in it. This finds every such note in the vault, writes the transcription as
Markdown above each photo, and changes the tag to "ocr-done". The photos stay.
Tags can be in the properties (tags: [ocr]) or in the text (#ocr).

When the vault is a git repository, it pulls first (so photos added on the phone
are here) and commits and pushes the transcriptions afterwards.

Needs Ollama running and ImageMagick (with libheif for iPhone photos).
Usage: ocr_notes.py [--dry-run] [--no-git] [--vault PATH]
       (default vault: $NOTES_VAULT or ~/notes; --dry-run prints the result instead)
"""
import base64
import json
import os
import re
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
MODEL = os.environ.get("OCR_MODEL", "qwen2.5vl:7b")
OLLAMA = "http://127.0.0.1:11434"
TODO_TAG, DONE_TAG = "ocr", "ocr-done"
BACKUPS = Path.home() / ".local/share/ocr-notes/backups"
IMAGE_EXT = {".jpg", ".jpeg", ".png", ".heic", ".heif", ".webp", ".gif"}
SHOWABLE = {".jpg", ".jpeg", ".png", ".webp", ".gif"}  # what Obsidian and the preview can display

# ![[file.jpg]] or ![[file.jpg|300]], ![alt](path) or [name](path), <img src="path">
LINK = re.compile(r"!\[\[(?P<wiki>[^\]|#]+)(?:[|#][^\]]*)?\]\]"
                  r"|!?\[[^\]]*\]\((?P<md><[^>]+>|[^)\s]+)(?:\s+\"[^\"]*\")?\)"
                  r"|<img[^>]*\bsrc=\"(?P<img>[^\"]+)\"[^>]*>")
FRONTMATTER = re.compile(r"\A---\n(.*?\n)---[ \t]*\n", re.S)
INLINE_TAG = re.compile(r"(?<![\w/#-])#ocr(?![\w/-])")


def log(msg: str) -> None:
    print(f"{time.strftime('%H:%M:%S')} {msg}", flush=True)


def build_prompt() -> str:
    prompt = (HERE / "prompt.txt").read_text()
    vocab = HERE / "vocab.txt"
    if vocab.exists() and vocab.read_text().strip():
        prompt += ("\nWords and terms the writer often uses (only use them where they match the handwriting):\n"
                   + vocab.read_text())
    return prompt


# --- tags ------------------------------------------------------------------

def fm_tags(fm: str) -> list[str]:
    """The tags in a frontmatter block: [a, b], a list of "- a" lines, or "a, b"."""
    m = re.search(r"^tags:[ \t]*(.*)$", fm, re.M)
    if not m:
        return []
    value = m.group(1).strip()
    if value.startswith("["):
        return [t.strip().strip("'\"") for t in value.strip("[]").split(",") if t.strip()]
    if value:
        return [t.strip().strip("'\"") for t in value.split(",") if t.strip()]
    rest = fm[m.end():].split("\n")
    tags = []
    for line in rest[1:]:
        item = re.match(r"^\s+-\s*(.+?)\s*$", line)
        if not item:
            break
        tags.append(item.group(1).strip("'\""))
    return tags


def is_todo(text: str) -> bool:
    m = FRONTMATTER.match(text)
    if m and TODO_TAG in [t.lstrip("#") for t in fm_tags(m.group(1))]:
        return True
    return bool(INLINE_TAG.search(text[m.end():] if m else text))


def retag(text: str) -> str:
    """ocr -> ocr-done, in the properties and in the text."""
    m = FRONTMATTER.match(text)
    body_start = 0
    if m:
        fm = m.group(1)
        t = re.search(r"^tags:.*(?:\n[ \t]+-.*)*", fm, re.M)
        if t:
            block = re.sub(r"(?<=[\[,\s:-])(['\"]?)#?ocr\1(?=\s*(?:,|\]|$))", r"\g<1>" + DONE_TAG + r"\1", t.group(0), flags=re.M)
            fm = fm[:t.start()] + block + fm[t.end():]
        text = "---\n" + fm + "---\n" + text[m.end():]
        body_start = len("---\n" + fm + "---\n")
    return text[:body_start] + INLINE_TAG.sub("#" + DONE_TAG, text[body_start:])


# --- finding the photos ----------------------------------------------------

class Vault:
    def __init__(self, root: Path):
        self.root = root
        self.by_name: dict[str, list[Path]] = {}
        for d, dirs, files in os.walk(root):
            dirs[:] = [x for x in dirs if not x.startswith(".")]
            for f in files:
                self.by_name.setdefault(f.lower(), []).append(Path(d, f))

    def notes(self):
        for paths in self.by_name.values():
            for p in paths:
                if p.suffix == ".md":
                    yield p

    def resolve(self, note: Path, target: str) -> Path | None:
        """The file a link points to: relative to the note, to the vault, or by name anywhere."""
        target = urllib.parse.unquote(target.strip().strip("<>"))
        if re.match(r"^[a-z][\w+.-]*://", target):
            return None
        for base in (note.parent, self.root):
            p = (base / target).resolve()
            if p.is_file():
                return p
        hits = self.by_name.get(Path(target).name.lower(), [])
        return hits[0].resolve() if hits else None


def link_target(m: re.Match) -> str:
    return m.group("wiki") or m.group("md") or m.group("img")


# --- OCR -------------------------------------------------------------------

def to_jpeg(path: Path) -> bytes:
    """Any image (including HEIC) as an upright JPEG of at most 2000px."""
    with tempfile.TemporaryDirectory() as tmp:
        out = Path(tmp, "out.jpg")
        subprocess.run(["magick", f"{path}[0]", "-auto-orient", "-resize", "2000x2000>", "-quality", "90", str(out)],
                       check=True, capture_output=True)
        return out.read_bytes()


def transcribe(image: bytes, prompt: str) -> str:
    body = {
        "model": MODEL,
        "stream": False,
        "options": {"temperature": 0, "num_ctx": 8192},
        "messages": [{"role": "user", "content": prompt, "images": [base64.b64encode(image).decode()]}],
    }
    req = urllib.request.Request(f"{OLLAMA}/api/chat", json.dumps(body).encode(), {"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=900) as r:
        text = json.load(r)["message"]["content"].strip()
    # strip a ```markdown fence if the model wraps its whole answer in one
    return re.sub(r"^```(?:markdown|md)\n|\n?```$", "", text) if text.startswith("```m") else text


def md_link(note: Path, file: Path) -> str:
    rel = os.path.relpath(file, note.parent)
    return f"![{file.name}](<{rel}>)" if " " in rel else f"![{file.name}]({rel})"


def process(vault: Vault, note: Path, prompt: str, dry_run: bool) -> bool:
    text = note.read_text(encoding="utf-8")
    fm = FRONTMATTER.match(text)
    body_start = fm.end() if fm else 0
    photos = []
    for m in LINK.finditer(text, body_start):
        file = vault.resolve(note, link_target(m))
        if file and file.suffix.lower() in IMAGE_EXT and file not in [p for _, p in photos]:
            photos.append((m, file))
    log(f"{note.relative_to(vault.root)}: {len(photos)} photo(s)")

    inserts = {}  # match start -> Markdown to put above that link
    for n, (m, file) in enumerate(photos, 1):
        start = time.time()
        jpeg = to_jpeg(file)
        result = transcribe(jpeg, prompt)
        log(f"  page {n}: {time.time() - start:.0f}s")
        if not result:
            log(f"  page {n}: the model returned no text, skipping")
            continue
        # iPhone photos (HEIC) can't be displayed, so show a JPEG copy above the original link
        if file.suffix.lower() not in SHOWABLE:
            copy = file.with_suffix(".jpg")
            if copy.exists():
                copy = file.with_name(file.stem + "-page.jpg")
            if not dry_run:
                copy.write_bytes(jpeg)
            result += "\n\n" + md_link(note, copy)
        inserts[m.start()] = result

    if not inserts:
        log(f"  nothing could be transcribed; the note stays tagged '{TODO_TAG}'")
        return False
    out, last = [], 0
    for pos in sorted(inserts):
        out += [text[last:pos], inserts[pos], "\n\n"]
        last = pos
    new = retag("".join(out) + text[last:])
    if dry_run:
        print(new)
        return False
    BACKUPS.mkdir(parents=True, exist_ok=True)
    rel = str(note.relative_to(vault.root)).replace("/", "__")
    (BACKUPS / f"{time.strftime('%Y%m%d-%H%M%S')}-{rel}").write_text(text, encoding="utf-8")
    note.write_text(new, encoding="utf-8")
    log(f"  transcribed and tagged {DONE_TAG}")
    return True


# --- git -------------------------------------------------------------------

def git(root: Path, *args: str) -> subprocess.CompletedProcess:
    env = dict(os.environ, GIT_TERMINAL_PROMPT="0", GIT_SSH_COMMAND="ssh -oBatchMode=yes -oConnectTimeout=8")
    return subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True, env=env)


def synced(root: Path) -> bool:
    return git(root, "rev-parse", "--abbrev-ref", "@{u}").returncode == 0


def pull(root: Path) -> None:
    if synced(root):
        res = git(root, "pull", "--rebase", "--autostash", "-q")
        if res.returncode != 0:
            git(root, "rebase", "--abort")
            log("couldn't pull (offline, or a conflict); working on what is here")


def commit_push(root: Path, message: str) -> None:
    if git(root, "rev-parse", "--is-inside-work-tree").returncode != 0:
        return
    git(root, "add", "-A")
    if git(root, "diff", "--cached", "--quiet").returncode != 0:
        git(root, "commit", "-q", "-m", message)
    if synced(root) and git(root, "push", "-q").returncode != 0:
        log("couldn't push; Neovim's next sync will")


# --- main ------------------------------------------------------------------

def main() -> int:
    args = sys.argv[1:]
    dry_run, use_git = "--dry-run" in args, "--no-git" not in args
    root = Path(args[args.index("--vault") + 1] if "--vault" in args
                else os.environ.get("NOTES_VAULT") or Path.home() / "notes").expanduser().resolve()
    if not root.is_dir():
        log(f"no vault at {root}")
        return 1
    if use_git and not dry_run:
        pull(root)
    vault = Vault(root)
    todo = [n for n in vault.notes() if is_todo(n.read_text(encoding="utf-8", errors="replace"))]
    if not todo:
        log(f"no notes tagged '{TODO_TAG}'")
        return 0
    try:
        urllib.request.urlopen(f"{OLLAMA}/api/version", timeout=5)
    except (urllib.error.URLError, OSError):
        log(f"{len(todo)} note(s) tagged '{TODO_TAG}' but Ollama is not running")
        return 1
    prompt = build_prompt()
    done = failed = 0
    for note in todo:
        try:
            done += process(vault, note, prompt, dry_run)
        except Exception as e:  # keep going with the other notes
            failed += 1
            log(f"  failed: {e}")
    if done and use_git:
        commit_push(root, f"ocr: {done} note{'s' if done != 1 else ''} transcribed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
