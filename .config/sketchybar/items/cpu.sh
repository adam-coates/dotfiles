#!/usr/bin/env bash
#
sketchybar --add item cpu right \
           --set cpu update_freq=2 \
                        icon="􀫥" \
                        icon.color=0xFF89B582 \
                        script="$PLUGIN_DIR/cpu.sh"
