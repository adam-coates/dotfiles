#!/bin/sh
SCRIPT="$HOME/.config/herdr/scripts/pomodoro.sh"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/pomodoro"
STATE_FILE="$STATE_DIR/state"
CONF_FILE="$STATE_DIR/config"

# Load config defaults
WORK=25; SHORT_BREAK=5; LONG_BREAK=15; LONG_BREAK_AFTER=4
[ -f "$CONF_FILE" ] && . "$CONF_FILE"

# Load current state
phase="" end="" paused_left="" count=0
[ -f "$STATE_FILE" ] && . "$STATE_FILE"

current_status() {
  if [ -z "$phase" ]; then
    echo "No timer running"
    return
  fi
  if [ -n "$paused_left" ]; then
    mins=$(( paused_left / 60 ))
    secs=$(( paused_left % 60 ))
    case "$phase" in
      work)        printf " %02d:%02d PAUSED (session #%d)" "$mins" "$secs" "$count" ;;
      short_break) printf " %02d:%02d PAUSED" "$mins" "$secs" ;;
      long_break)  printf " %02d:%02d PAUSED" "$mins" "$secs" ;;
    esac
  else
    now=$(date +%s)
    left=$(( end - now ))
    [ "$left" -lt 0 ] && left=0
    mins=$(( left / 60 ))
    secs=$(( left % 60 ))
    case "$phase" in
      work)        printf " %02d:%02d (session #%d)" "$mins" "$secs" "$count" ;;
      short_break) printf " %02d:%02d" "$mins" "$secs" ;;
      long_break)  printf " %02d:%02d" "$mins" "$secs" ;;
    esac
  fi
}

build_options() {
  if [ -z "$phase" ]; then
    printf " Start Work (%dm)\n" "$WORK"
    printf " Short Break (%dm)\n" "$SHORT_BREAK"
    printf " Long Break (%dm)\n" "$LONG_BREAK"
    echo "─────────────────"
    echo " Configure"
  elif [ -n "$paused_left" ]; then
    echo " Resume"
    echo " Stop"
    echo " Skip Phase"
    echo "─────────────────"
    echo " Configure"
  else
    echo " Pause"
    echo " Stop"
    echo " Skip Phase"
    echo "─────────────────"
    echo " Configure"
  fi
}

configure_menu() {
  clear
  echo ""
  echo "  Pomodoro Configuration"
  echo "  ━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  new_work=$(gum input --placeholder "$WORK" --prompt "  Work (min):         " --width 5 --value "$WORK")
  [ -z "$new_work" ] && return
  new_short=$(gum input --placeholder "$SHORT_BREAK" --prompt "  Short break (min):  " --width 5 --value "$SHORT_BREAK")
  [ -z "$new_short" ] && return
  new_long=$(gum input --placeholder "$LONG_BREAK" --prompt "  Long break (min):   " --width 5 --value "$LONG_BREAK")
  [ -z "$new_long" ] && return
  new_every=$(gum input --placeholder "$LONG_BREAK_AFTER" --prompt "  Long break every:   " --width 5 --value "$LONG_BREAK_AFTER")
  [ -z "$new_every" ] && return

  "$SCRIPT" config "$new_work" "$new_short" "$new_long" "$new_every"
  echo ""
  gum style --foreground 6 "  Saved!"
  sleep 1
}

main() {
  while true; do
    clear
    status=$(current_status)

    echo ""
    gum style --foreground 6 --bold "  Pomodoro Timer"
    echo "  ━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    gum style --foreground 7 "  $status"
    echo ""

    choice=$(build_options | gum choose --cursor "▸ " --cursor.foreground 6)

    case "$choice" in
      *"Start Work"*)
        "$SCRIPT" start
        break
        ;;
      *"Short Break"*)
        "$SCRIPT" stop 2>/dev/null
        phase="short_break"
        end=$(( $(date +%s) + SHORT_BREAK * 60 ))
        paused_left=""
        count=${count:-0}
        mkdir -p "$STATE_DIR"
        cat > "$STATE_FILE" <<EOF
phase=$phase
end=$end
paused_left=$paused_left
count=$count
EOF
        break
        ;;
      *"Long Break"*)
        "$SCRIPT" stop 2>/dev/null
        phase="long_break"
        end=$(( $(date +%s) + LONG_BREAK * 60 ))
        paused_left=""
        count=${count:-0}
        mkdir -p "$STATE_DIR"
        cat > "$STATE_FILE" <<EOF
phase=$phase
end=$end
paused_left=$paused_left
count=$count
EOF
        break
        ;;
      *"Resume"*)
        "$SCRIPT" pause_toggle
        break
        ;;
      *"Pause"*)
        "$SCRIPT" pause_toggle
        break
        ;;
      *"Stop"*)
        "$SCRIPT" stop
        break
        ;;
      *"Skip"*)
        "$SCRIPT" skip
        break
        ;;
      *"Configure"*)
        configure_menu
        # Reload config
        WORK=25; SHORT_BREAK=5; LONG_BREAK=15; LONG_BREAK_AFTER=4
        [ -f "$CONF_FILE" ] && . "$CONF_FILE"
        # Reload state
        phase="" end="" paused_left="" count=0
        [ -f "$STATE_FILE" ] && . "$STATE_FILE"
        ;;
      *)
        break
        ;;
    esac
  done
}

main
