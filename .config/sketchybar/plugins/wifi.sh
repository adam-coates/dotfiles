#!/bin/bash

update() {
  source "$CONFIG_DIR/icons.sh"
  #CURRENT_WIFI="$(/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I)"
  #SSID="$(echo "$CURRENT_WIFI" | grep -o "SSID: .*" | sed 's/^SSID: //')"
  SSID="$(ipconfig getsummary en0 | awk -F ' SSID : '  '/ SSID : / {print $2}')"
  #SSID="$(/System/Library/PrivateFrameworks/Apple80211.framework/Resources/airport -I | awk -F ' SSID: '  '/ SSID: / {print $2}')"
  #IP="$(ipconfig getifaddr en0)"
  #CURR_TX="$(echo "$CURRENT_WIFI" | grep -o "lastTxRate: .*" | sed 's/^lastTxRate: //')"



if [ -n "$SSID" ] || [ ${#SSID} -gt 1 ]; then
    ICON="$WIFI_CONNECTED"
    LABEL=$(echo "$SSID")
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
