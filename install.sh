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

for pkg in */; do
  dry_run=$(stow -n -t "$HOME" "$pkg" 2>&1 || true)
  conflicts=$(echo "$dry_run" | grep -oP '(?:over existing target|not owned by stow:) \K\S+' || true)

  for target in $conflicts; do
    echo "Removing conflicting $HOME/$target"
    rm -rf "$HOME/$target"
  done

  stow -t "$HOME" "$pkg"
  echo "Stowed $pkg"
done
