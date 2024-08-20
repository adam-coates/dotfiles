#!/usr/bin/env bash
#

#
sketchybar --add item ram right \
           --set ram update_freq=30 \
                        icon="􀫦" \
                        icon.font="SF Pro:Semibold:15.0" \
                        icon.color=0xFFD8A656 \
                        icon.y_offset=-6 \
                        label.font="SF Pro:Semibold:10.0" \
                        y_offset=7 \
                        background.y_offset=-7 \
                        script="$PLUGIN_DIR/ram.sh" \
           --add item ram_percent right \
           --set ram_percent update_freq=30 \
                        icon.font="SF Pro:Semibold:10.0" \
                        label.font="SF Pro:Semibold:10.0" \
                        background.padding_right=-70 \
                        background.drawing=0ff \
                        y_offset=-5 \
