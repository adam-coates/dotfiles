#!/bin/sh
dir="${HERDR_ACTIVE_PANE_CWD:-.}"
branch=$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null) || exit 0
dirty=""
git -C "$dir" diff --quiet 2>/dev/null || dirty=" +"
git -C "$dir" diff --cached --quiet 2>/dev/null || dirty=" +"
echo " $branch$dirty"
