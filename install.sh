#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

for pkg in */; do
  dry_run=$(stow -n -t "$HOME" "$pkg" 2>&1 || true)

  echo "$dry_run" | grep -oP '(?:over existing target|not owned by stow:) \K\S+' | while read -r target; do
    echo "Removing conflicting $HOME/$target"
    rm -rf "$HOME/$target"
  done

  stow -t "$HOME" "$pkg"
  echo "Stowed $pkg"
done
