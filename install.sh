#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

for pkg in */; do
  stow -t "$HOME" "$pkg"
  echo "Stowed $pkg"
done
