#!/bin/sh

PERCENTAGE="$(pmset -g batt | grep -Eo "\d+%" | cut -d% -f1)"
CHARGING="$(pmset -g batt | grep 'AC Power')"

if [ "$PERCENTAGE" = "" ]; then
  exit 0
fi

case "${PERCENTAGE}" in
  100) ICON="󰁹"; COLOR=0xFFA8B666
  ;;
  9[0-9]) ICON="󰂂"; COLOR=0xFFA8B666
  ;;
  8[0-9]) ICON="󰂁"; COLOR=0xFFA8B666
  ;;
  7[0-9]) ICON="󰂀"; COLOR=0xFFA8B666
  ;;
  6[0-9]) ICON="󰁿"; COLOR=0xFFD8A656
  ;;
  5[0-9]) ICON="󰁾"; COLOR=0xFFD8A656
  ;;
  4[0-9]) ICON="󰁽"; COLOR=0xFFD8A656
  ;;
  3[0-9]) ICON="󰁼"; COLOR=0xFFEA6862
  ;;
  2[0-9]) ICON="󰁻"; COLOR=0xFFEA6862
  ;;
  1[0-9]) ICON="󰁺"; COLOR=0xFFEA6862
  ;;
  *) ICON="󰂎"
esac

#case "${PERCENTAGE}" in
#  9[0-9]|100) ICON="􀛨"; COLOR=0xFFA8B666
#  ;;
#  [6-8][0-9]) ICON="􀺸"; COLOR=0xFFA8B666
#  ;;
#  [3-5][0-9]) ICON="􀺶"; COLOR=0xFFD8A656
#  ;;
#  [1-2][0-9]) ICON="􀛩"; COLOR=0xFFEA6862
#  ;;
#  *) ICON="􀛪"
#esac

if [[ "$CHARGING" != "" ]]; then
  ICON=""
  COLOR=0xFFA8B666
fi

# The item invoking this script (name $NAME) will get its icon and label
# updated with the current battery status
sketchybar --set "$NAME" icon.font="JetBrainsMono Nerd Font:Medium:18:0" icon="$ICON" icon.color="$COLOR" label="${PERCENTAGE}%"
