#!/bin/sh
SCRIPT="$HOME/.config/herdr/scripts/pomodoro.sh"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/pomodoro"
STATE_FILE="$STATE_DIR/state"
CONF_FILE="$STATE_DIR/config"

# Read omarchy theme colors
THEME=$(omarchy theme current 2>/dev/null)
THEME_DIR=$(omarchy theme dir "$THEME" 2>/dev/null)
COLORS_FILE="$THEME_DIR/colors.toml"

get_color() {
  if [ -f "$COLORS_FILE" ]; then
    sed -n "s/^${1} *= *\"\(.*\)\"/\1/p" "$COLORS_FILE" | head -1
  fi
}

C_ACCENT=$(get_color accent)
C_FG=$(get_color foreground)
C_MUTED=$(get_color muted)
C_GREEN=$(get_color green)
C_YELLOW=$(get_color yellow)
C_RED=$(get_color red)
C_CYAN=$(get_color cyan)

# Fallbacks if no theme found
: "${C_ACCENT:=#89b4fa}" "${C_FG:=#cdd6f4}" "${C_MUTED:=#585b70}"
: "${C_GREEN:=#a6e3a1}" "${C_YELLOW:=#f9e2af}" "${C_RED:=#f38ba8}" "${C_CYAN:=#89b482}"

# Load config defaults
WORK=25; SHORT_BREAK=5; LONG_BREAK=15; LONG_BREAK_AFTER=4
[ -f "$CONF_FILE" ] && . "$CONF_FILE"

# Load current state
phase="" end="" paused_left="" count=0
[ -f "$STATE_FILE" ] && . "$STATE_FILE"

current_status() {
  if [ -z "$phase" ]; then
    gum style --foreground "$C_MUTED" "  No timer running"
    return
  fi
  if [ -n "$paused_left" ]; then
    mins=$(( paused_left / 60 ))
    secs=$(( paused_left % 60 ))
    case "$phase" in
      work)        label=" WORK"; color="$C_YELLOW" ;;
      short_break) label=" SHORT BREAK"; color="$C_GREEN" ;;
      long_break)  label=" LONG BREAK"; color="$C_CYAN" ;;
    esac
    gum style --foreground "$color" "$(printf "  %s  %02d:%02d  ⏸ PAUSED  #%d" "$label" "$mins" "$secs" "$count")"
  else
    now=$(date +%s)
    left=$(( end - now ))
    [ "$left" -lt 0 ] && left=0
    mins=$(( left / 60 ))
    secs=$(( left % 60 ))
    case "$phase" in
      work)        label=" WORK"; color="$C_ACCENT" ;;
      short_break) label=" SHORT BREAK"; color="$C_GREEN" ;;
      long_break)  label=" LONG BREAK"; color="$C_CYAN" ;;
    esac
    gum style --foreground "$color" "$(printf "  %s  %02d:%02d  #%d" "$label" "$mins" "$secs" "$count")"
  fi
}

build_options() {
  if [ -z "$phase" ]; then
    printf " Start Work (%dm)\n" "$WORK"
    printf " Short Break (%dm)\n" "$SHORT_BREAK"
    printf " Long Break (%dm)\n" "$LONG_BREAK"
    echo "─────────────────────"
    echo " Configure"
  elif [ -n "$paused_left" ]; then
    echo " Resume"
    echo " Stop"
    echo " Skip Phase"
    echo "─────────────────────"
    echo " Configure"
  else
    echo " Pause"
    echo " Stop"
    echo " Skip Phase"
    echo "─────────────────────"
    echo " Configure"
  fi
}

configure_menu() {
  clear
  echo ""
  gum style --foreground "$C_ACCENT" --bold "  Pomodoro Configuration"
  gum style --foreground "$C_MUTED" "  ━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  new_work=$(gum input --placeholder "$WORK" --prompt "  Work (min):         " --prompt.foreground "$C_FG" --cursor.foreground "$C_ACCENT" --width 5 --value "$WORK")
  [ -z "$new_work" ] && return
  new_short=$(gum input --placeholder "$SHORT_BREAK" --prompt "  Short break (min):  " --prompt.foreground "$C_FG" --cursor.foreground "$C_ACCENT" --width 5 --value "$SHORT_BREAK")
  [ -z "$new_short" ] && return
  new_long=$(gum input --placeholder "$LONG_BREAK" --prompt "  Long break (min):   " --prompt.foreground "$C_FG" --cursor.foreground "$C_ACCENT" --width 5 --value "$LONG_BREAK")
  [ -z "$new_long" ] && return
  new_every=$(gum input --placeholder "$LONG_BREAK_AFTER" --prompt "  Long break every:   " --prompt.foreground "$C_FG" --cursor.foreground "$C_ACCENT" --width 5 --value "$LONG_BREAK_AFTER")
  [ -z "$new_every" ] && return

  "$SCRIPT" config "$new_work" "$new_short" "$new_long" "$new_every"
  echo ""
  gum style --foreground "$C_GREEN" "  Saved!"
  sleep 1
}

main() {
  while true; do
    clear
    echo ""
    gum style --foreground "$C_ACCENT" --bold "  Pomodoro Timer"
    gum style --foreground "$C_MUTED" "  ━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    current_status
    echo ""

    choice=$(build_options | gum choose \
      --cursor "▸ " \
      --cursor.foreground "$C_ACCENT" \
      --selected.foreground "$C_ACCENT")

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
        WORK=25; SHORT_BREAK=5; LONG_BREAK=15; LONG_BREAK_AFTER=4
        [ -f "$CONF_FILE" ] && . "$CONF_FILE"
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
