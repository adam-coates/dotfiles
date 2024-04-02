#!/usr/bin/env bash
#

sketchybar --add item calendar right \
           --set calendar icon=􀧞  \
                update_freq=30 \
                icon.color=0xFFD3859B \
                script="$PLUGIN_DIR/calendar.sh" \
                click_script="$PLUGIN_DIR/zen.sh" \
                --subscribe calendar system_woke


