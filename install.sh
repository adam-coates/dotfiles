#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

# Stow merges into existing directories: files already in ~ (e.g. Omarchy's
# default hooks, themes and plugins) stay where they are, and our files are
# linked in alongside them. A target is replaced only when one of our files
# lives at the same path, and the original is moved to $BACKUP_DIR first.
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

backup_target() {
  local rel="$1"
  local src="$HOME/$rel"
  [[ -e "$src" || -L "$src" ]] || return 0
  mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
  mv "$src" "$BACKUP_DIR/$rel"
  echo "  backed up conflicting ~/$rel"
}

# Remove non-stow files from directories where a stray file would be loaded
# alongside our config (e.g. Omarchy's default nvim scaffold).
clean_dir() {
  local target="$HOME/$1"
  [[ -d "$target" && ! -L "$target" ]] || return 0
  local rel
  while IFS= read -r -d '' f; do
    rel="${f#"$HOME"/}"
    backup_target "$rel"
  done < <(find "$target" -not -type d -print0)
  find "$target" -type d -empty -delete 2>/dev/null || true
}

clean_dir ".config/nvim"
rm -rf "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy/LazyVim"

# Stow refuses absolute symlinks inside a package, and one bad entry aborts the
# whole package. These are linked by hand below instead.
STOW_OPTS=(
  --ignore='\.aarch64\.json'
  --ignore='superwhisper-panel'
)

# Packages that only make sense on an Omarchy (Arch + Hyprland) machine. They
# are skipped elsewhere, e.g. on macOS.
OMARCHY_PKGS=(omarchy hypr)

is_omarchy() {
  [[ -d /usr/share/omarchy ]] || command -v omarchy >/dev/null 2>&1
}

is_omarchy_pkg() {
  local p
  for p in "${OMARCHY_PKGS[@]}"; do
    [[ "$p" == "$1" ]] && return 0
  done
  return 1
}

failed=()

for pkg in */; do
  pkg="${pkg%/}"
  if is_omarchy_pkg "$pkg" && ! is_omarchy; then
    echo "Skipped $pkg (not running Omarchy)"
    continue
  fi
  dry_run=$(stow -n -t "$HOME" "${STOW_OPTS[@]}" "$pkg" 2>&1 || true)
  # sed -E rather than grep -P so this also works with macOS's BSD tools.
  conflicts=$(echo "$dry_run" | sed -nE 's/.*(over existing target |not owned by stow: |neither a link nor a directory: )([^ ]+).*/\2/p' | sort -u)

  for target in $conflicts; do
    backup_target "$target"
  done

  if stow -t "$HOME" "${STOW_OPTS[@]}" "$pkg"; then
    echo "Stowed $pkg"
  else
    echo "FAILED to stow $pkg" >&2
    failed+=("$pkg")
  fi
done

# Absolute symlinks that stow can't manage.
link_absolute() {
  local link="$1" dest="$2"
  [[ -e "$dest" ]] || return 0
  if [[ -e "$link" && ! -L "$link" ]]; then
    backup_target "${link#"$HOME"/}"
  fi
  mkdir -p "$(dirname "$link")"
  ln -sfn "$dest" "$link"
}

if is_omarchy; then
  link_absolute "$HOME/.config/omarchy/plugins/superwhisper-panel" \
    /opt/superwhisper/assets/omarchy-plugin/superwhisper-panel
fi

# On Apple Silicon (aarch64), the MacBook notch covers the center of the top
# bar. Replace the centered-clock layout with one that puts everything in the
# right section.
if is_omarchy && [[ "$(uname -m)" == "aarch64" ]] && grep -q apple /proc/device-tree/compatible 2>/dev/null; then
  aarch_shell="omarchy/.config/omarchy/shell.aarch64.json"
  if [[ -f "$aarch_shell" ]]; then
    target="$HOME/.config/omarchy/shell.json"
    rm -f "$target"
    cp "$aarch_shell" "$target"
    echo "Applied aarch64 bar layout"
  fi
fi

# Omarchy renders our themed templates (omarchy/.config/omarchy/themed/*.tpl,
# e.g. the markdown preview's theme) only when a theme is applied, so reapply
# the current one now that they're in place.
if command -v omarchy-theme-refresh >/dev/null 2>&1; then
  omarchy-theme-refresh
  echo "Refreshed Omarchy theme"
fi

[[ -d "$BACKUP_DIR" ]] && echo "Replaced files were backed up to $BACKUP_DIR"

if ((${#failed[@]})); then
  echo "Some packages failed to stow: ${failed[*]}" >&2
  exit 1
fi
