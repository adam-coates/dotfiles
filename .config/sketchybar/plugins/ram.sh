#!/usr/bin/env bash
#
ram_percent=$( /Users/adam/.config/sketchybar/plugins/get_ram.py | awk 'NR==1')
ram_used_gb=$( /Users/adam/.config/sketchybar/plugins/get_ram.py | awk 'NR==2')


#echo $ram_percent
#echo "$ram_used_gb"

sketchybar -m --set ram_percent label=$ram_percent
sketchybar -m --set $NAME label=$ram_used_gb
