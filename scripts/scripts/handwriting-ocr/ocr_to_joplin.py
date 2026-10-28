#!/usr/bin/env python3
"""Transcribe photos of handwritten pages in Joplin notes with a local Ollama model.

Tag a note "ocr" in Joplin (on any device). When this script runs on the desktop,
it reads each image attached to that note, inserts the transcription as Markdown
above the image, and swaps the "ocr" tag for "ocr-done". The photos are kept.

Needs Joplin desktop running (Web Clipper service on) and Ollama running.
Usage: ocr_to_joplin.py [--dry-run]
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
import uuid
from pathlib import Path

HERE = Path(__file__).resolve().parent
MODEL = os.environ.get("OCR_MODEL", "qwen2.5vl:7b")
OLLAMA = "http://127.0.0.1:11434"
JOPLIN = "http://127.0.0.1:41184"
JOPLIN_SETTINGS = Path.home() / ".config/joplin-desktop/settings.json"
TODO_TAG, DONE_TAG = "ocr", "ocr-done"
BACKUPS = Path.home() / ".local/share/ocr-to-joplin/backups"
# Embedded images ![..](:/id), plain file links [..](:/id) (how Joplin iOS attaches HEIC photos), or <img src=":/id">
IMAGE_LINK = re.compile(r"!?\[[^\]]*\]\(:/([0-9a-f]{32})\)|<img[^>]*src=\":/([0-9a-f]{32})\"[^>]*>")
BROWSER_IMAGES = {"image/jpeg", "image/png", "image/gif", "image/webp"}


def log(msg: str) -> None:
    print(f"{time.strftime('%H:%M:%S')} {msg}", flush=True)


def build_prompt() -> str:
    prompt = (HERE / "prompt.txt").read_text()
    vocab = HERE / "vocab.txt"
    if vocab.exists() and vocab.read_text().strip():
        prompt += ("\nWords and terms the writer often uses (only use them where they match the handwriting):\n"
                   + vocab.read_text())
    return prompt


# --- Joplin data API -------------------------------------------------------

TOKEN = json.loads(JOPLIN_SETTINGS.read_text())["api.token"]


def joplin(method: str, path: str, body=None, raw: bool = False, **params):
    params["token"] = TOKEN
    url = f"{JOPLIN}{path}?{urllib.parse.urlencode(params)}"
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data, {"Content-Type": "application/json"}, method=method)
    with urllib.request.urlopen(req, timeout=60) as r:
        content = r.read()
    if raw:
        return content
    return json.loads(content) if content else None


def joplin_all(path: str, **params) -> list:
    items, page = [], 1
    while True:
        res = joplin("GET", path, page=page, **params)
        items += res["items"]
        if not res.get("has_more"):
            return items
        page += 1


def tag_id(title: str, create: bool = False) -> str | None:
    for tag in joplin_all("/tags", fields="id,title"):
        if tag["title"] == title:
            return tag["id"]
    return joplin("POST", "/tags", {"title": title})["id"] if create else None


# --- OCR -------------------------------------------------------------------

def to_jpeg(data: bytes) -> bytes:
    """Convert any image (including HEIC) to an upright JPEG of at most 2000px."""
    with tempfile.TemporaryDirectory() as tmp:
        src, dst = Path(tmp, "in"), Path(tmp, "out.jpg")
        src.write_bytes(data)
        subprocess.run(["magick", str(src), "-auto-orient", "-resize", "2000x2000>", "-quality", "90", str(dst)],
                       check=True, capture_output=True)
        return dst.read_bytes()


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


# --- main ------------------------------------------------------------------

def upload_jpeg(data: bytes, title: str) -> str:
    """Add a JPEG to Joplin as a new resource and return its id."""
    boundary = uuid.uuid4().hex
    body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"props\"\r\n\r\n"
            f"{json.dumps({'title': title})}\r\n"
            f"--{boundary}\r\nContent-Disposition: form-data; name=\"data\"; filename=\"{title}\"\r\n"
            f"Content-Type: image/jpeg\r\n\r\n").encode() + data + f"\r\n--{boundary}--\r\n".encode()
    url = f"{JOPLIN}/resources?{urllib.parse.urlencode({'token': TOKEN})}"
    req = urllib.request.Request(url, body, {"Content-Type": f"multipart/form-data; boundary={boundary}"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)["id"]


def process_note(note_id: str, prompt: str, todo: str, dry_run: bool) -> None:
    note = joplin("GET", f"/notes/{note_id}", fields="id,title,body")
    images = {r["id"]: r for r in joplin_all(f"/notes/{note_id}/resources", fields="id,mime,title")
              if r["mime"].startswith("image/")}
    log(f"note '{note['title']}': {len(images)} image(s)")

    inserts = {}  # resource id -> Markdown to put above its link
    for n, rid in enumerate(dict.fromkeys(m[0] or m[1] for m in IMAGE_LINK.findall(note["body"])), 1):
        if rid not in images:
            continue
        start = time.time()
        jpeg = to_jpeg(joplin("GET", f"/resources/{rid}/file", raw=True))
        text = transcribe(jpeg, prompt)
        log(f"  page {n}: {time.time() - start:.0f}s")
        if not text:
            log(f"  page {n}: model returned no text, skipping")
            continue
        # Joplin can't display HEIC, so show a JPEG copy of the page above the original file link
        if images[rid]["mime"] not in BROWSER_IMAGES and not dry_run:
            name = Path(images[rid]["title"] or rid).stem + ".jpg"
            text += f"\n\n![{name}](:/{upload_jpeg(jpeg, name)})"
        inserts[rid] = text

    if not inserts:
        log(f"  no images could be transcribed; leaving the note tagged '{TODO_TAG}'")
        return

    def insert(match: re.Match) -> str:
        rid = match[1] or match[2]
        if rid not in inserts:
            return match[0]
        return f"{inserts.pop(rid)}\n\n{match[0]}"

    new_body = IMAGE_LINK.sub(insert, note["body"])
    if dry_run:
        print(new_body)
        return

    BACKUPS.mkdir(parents=True, exist_ok=True)
    (BACKUPS / f"{note_id}-{time.strftime('%Y%m%d-%H%M%S')}.md").write_text(note["body"])
    joplin("PUT", f"/notes/{note_id}", {"body": new_body})
    joplin("POST", f"/tags/{tag_id(DONE_TAG, create=True)}/notes", {"id": note_id})
    joplin("DELETE", f"/tags/{todo}/notes/{note_id}")
    log(f"  updated and tagged {DONE_TAG}")


def main() -> int:
    dry_run = "--dry-run" in sys.argv
    try:
        joplin("GET", "/ping", raw=True)
    except (urllib.error.URLError, OSError):
        log("Joplin desktop is not running (or Web Clipper service is off); nothing to do")
        return 0
    todo = tag_id(TODO_TAG)
    notes = joplin_all(f"/tags/{todo}/notes", fields="id") if todo else []
    if not notes:
        log(f"no notes tagged '{TODO_TAG}'")
        return 0
    try:
        urllib.request.urlopen(f"{OLLAMA}/api/version", timeout=5)
    except (urllib.error.URLError, OSError):
        log(f"{len(notes)} note(s) tagged '{TODO_TAG}' but Ollama is not running")
        return 1
    prompt = build_prompt()
    failed = 0
    for note in notes:
        try:
            process_note(note["id"], prompt, todo, dry_run)
        except Exception as e:  # keep going with the other notes
            failed += 1
            log(f"  failed: {e}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
