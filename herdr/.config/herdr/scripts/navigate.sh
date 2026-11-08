#!/usr/bin/env bash
# Seamless Ctrl-h/j/k/l between herdr panes and Neovim windows, like
# vim-tmux-navigator. Bound in config.toml; usage: navigate.sh left|down|up|right
#
# If the focused pane is running Neovim, the key is passed through and Neovim
# decides: it moves between its own windows, and at an edge it asks herdr to
# focus the next pane (see utils/navigate.lua in the nvim config).
# Anywhere else, herdr moves focus directly.

dir=$1
herdr=${HERDR_BIN_PATH:-herdr}
pane=$HERDR_ACTIVE_PANE_ID
declare -A key=([left]=ctrl+h [down]=ctrl+j [up]=ctrl+k [right]=ctrl+l)

if "$herdr" pane process-info --pane "$pane" |
	jq -e '.result.process_info.foreground_processes[] | select(.name == "nvim" or .name == "vim")' >/dev/null; then
	exec "$herdr" pane send-keys "$pane" "${key[$dir]}"
fi
exec "$herdr" pane focus --pane "$pane" --direction "$dir"
