#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

for pkg in */; do
  # Dry run to find conflicts, extract target paths
  dry_run=$(stow -n -t "$HOME" "$pkg" 2>&1 || true)
  conflicts=$(echo "$dry_run" | sed -n 's/.*existing target \([^ ]*\).*/\1/p')

  for target in $conflicts; do
    echo "Removing conflicting $HOME/$target"
    rm -rf "$HOME/$target"
  done

  stow -t "$HOME" "$pkg"
  echo "Stowed $pkg"
done
