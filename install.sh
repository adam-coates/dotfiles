#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

# Stow merges into existing directories, so files left behind by other tools
# (e.g. omarchy's default nvim scaffold) can conflict or get loaded alongside
# our config. Remove non-stow files from directories stow will manage.
clean_dir() {
  local target="$HOME/$1"
  [[ -d "$target" ]] || return 0
  find "$target" -not -type d -delete
  find "$target" -type d -empty -delete 2>/dev/null || true
}

clean_dir ".config/nvim"
rm -rf "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy/LazyVim"

STOW_OPTS=(--ignore='\.aarch64\.json')

for pkg in */; do
  dry_run=$(stow -n -t "$HOME" "${STOW_OPTS[@]}" "$pkg" 2>&1 || true)
  conflicts=$(echo "$dry_run" | grep -oP '(?:over existing target|not owned by stow:) \K\S+' || true)

  for target in $conflicts; do
    echo "Removing conflicting $HOME/$target"
    rm -rf "$HOME/$target"
  done

  stow -t "$HOME" "${STOW_OPTS[@]}" "$pkg"
  echo "Stowed $pkg"
done

# On Apple Silicon (aarch64), the MacBook notch covers the center of the top
# bar. Replace the centered-clock layout with one that puts everything in the
# right section.
if [[ "$(uname -m)" == "aarch64" ]] && grep -q apple /proc/device-tree/compatible 2>/dev/null; then
  aarch_shell="omarchy/.config/omarchy/shell.aarch64.json"
  if [[ -f "$aarch_shell" ]]; then
    target="$HOME/.config/omarchy/shell.json"
    rm -f "$target"
    cp "$aarch_shell" "$target"
    echo "Applied aarch64 bar layout"
  fi
fi
