#!/bin/bash

update() {
  source "$CONFIG_DIR/icons.sh"
  #CURRENT_WIFI="$(/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I)"
  #SSID="$(echo "$CURRENT_WIFI" | grep -o "SSID: .*" | sed 's/^SSID: //')"
  SSID="$(networksetup -listallhardwareports | awk '/Wi-Fi/{getline; print $2}' | xargs networksetup -getairportnetwork | sed "s/Current Wi-Fi Network: //")"
  #SSID="$(/System/Library/PrivateFrameworks/Apple80211.framework/Resources/airport -I | awk -F ' SSID: '  '/ SSID: / {print $2}')"
  #IP="$(ipconfig getifaddr en0)"
  #CURR_TX="$(echo "$CURRENT_WIFI" | grep -o "lastTxRate: .*" | sed 's/^lastTxRate: //')"

down=$(/Users/adam/.config/sketchybar/plugins/get_down.py)


if [ -n "$SSID" ] || [ ${#SSID} -gt 1 ]; then
    ICON="$WIFI_CONNECTED"
    LABEL=$(echo "$SSID ($down)")
fi

if [ ${#SSID} -gt 30 ]; then
    ICON="$WIFI_DISCONNECTED"
    LABEL=$(echo "Disconnected")
fi


  #ICON="$([ -n "$SSID" ] && echo "$WIFI_CONNECTED" || echo "$WIFI_DISCONNECTED")"
  #LABEL="$([ -n "$SSID" ] && echo "$SSID ($down)" || echo "Disconnected")"

  sketchybar --set $NAME icon="$ICON" label="$LABEL"
}

click() {
  CURRENT_WIDTH="$(sketchybar --query $NAME | jq -r .label.width)"

  WIDTH=0
  if [ "$CURRENT_WIDTH" -eq "0" ]; then
    WIDTH=dynamic
  fi

  sketchybar --animate sin 20 --set $NAME label.width="$WIDTH"
}

case "$SENDER" in
  "wifi_change") update
  ;;
  "mouse.clicked") click
  ;;
esac
