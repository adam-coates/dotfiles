#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

for pkg in */; do
  # Dry run to find conflicts
  conflicts=$(stow -n -t "$HOME" "$pkg" 2>&1 | grep "existing target" | grep -oP 'existing target \K\S+')

  # Remove conflicting files/dirs so stow can create symlinks
  for target in $conflicts; do
    echo "Removing conflicting $HOME/$target"
    rm -rf "$HOME/$target"
  done

  stow -t "$HOME" "$pkg"
  echo "Stowed $pkg"
done
