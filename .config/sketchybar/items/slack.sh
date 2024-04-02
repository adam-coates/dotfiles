#!/usr/bin/env bash
#
sketchybar  --add   item slack q \
            --set   slack \
                    update_freq=10 \
                    script="$PLUGIN_DIR/slack.sh" \
                    background.padding_left=5  \
                    icon.font="JetBrainsMono Nerd Font:Medium:18:0" \
           --subscribe slack system_woke
