#!/bin/sh
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/pomodoro"
STATE_FILE="$STATE_DIR/state"
CONF_FILE="$STATE_DIR/config"

mkdir -p "$STATE_DIR"

# Defaults (minutes)
WORK=25
SHORT_BREAK=5
LONG_BREAK=15
LONG_BREAK_AFTER=4

load_conf() {
  [ -f "$CONF_FILE" ] && . "$CONF_FILE"
}

save_conf() {
  cat > "$CONF_FILE" <<EOF
WORK=$WORK
SHORT_BREAK=$SHORT_BREAK
LONG_BREAK=$LONG_BREAK
LONG_BREAK_AFTER=$LONG_BREAK_AFTER
EOF
}

load_state() {
  phase="" end="" paused_left="" count=0
  [ -f "$STATE_FILE" ] && . "$STATE_FILE"
}

save_state() {
  cat > "$STATE_FILE" <<EOF
phase=$phase
end=$end
paused_left=$paused_left
count=$count
EOF
}

clear_state() {
  rm -f "$STATE_FILE"
}

load_conf

case "${1:-status}" in
  start)
    phase="work"
    end=$(( $(date +%s) + WORK * 60 ))
    paused_left=""
    count=1
    save_state
    echo "Pomodoro #1 started (${WORK}m)"
    ;;

  stop)
    clear_state
    echo "Pomodoro stopped"
    ;;

  toggle)
    load_state
    if [ -n "$phase" ]; then
      clear_state
      echo "Pomodoro stopped"
    else
      phase="work"
      end=$(( $(date +%s) + WORK * 60 ))
      paused_left=""
      count=1
      save_state
      echo "Pomodoro #1 started (${WORK}m)"
    fi
    ;;

  pause)
    load_state
    [ -z "$phase" ] && echo "No timer running" && exit 0
    [ -n "$paused_left" ] && echo "Already paused" && exit 0
    now=$(date +%s)
    paused_left=$(( end - now ))
    [ "$paused_left" -lt 0 ] && paused_left=0
    end=""
    save_state
    echo "Paused"
    ;;

  resume)
    load_state
    [ -z "$phase" ] && echo "No timer running" && exit 0
    [ -z "$paused_left" ] && echo "Not paused" && exit 0
    end=$(( $(date +%s) + paused_left ))
    paused_left=""
    save_state
    echo "Resumed"
    ;;

  pause_toggle)
    load_state
    [ -z "$phase" ] && echo "No timer running" && exit 0
    if [ -n "$paused_left" ]; then
      end=$(( $(date +%s) + paused_left ))
      paused_left=""
      save_state
      echo "Resumed"
    else
      now=$(date +%s)
      paused_left=$(( end - now ))
      [ "$paused_left" -lt 0 ] && paused_left=0
      end=""
      save_state
      echo "Paused"
    fi
    ;;

  skip)
    load_state
    [ -z "$phase" ] && echo "No timer running" && exit 0
    if [ "$phase" = "work" ]; then
      if [ $(( count % LONG_BREAK_AFTER )) -eq 0 ]; then
        phase="long_break"
        end=$(( $(date +%s) + LONG_BREAK * 60 ))
      else
        phase="short_break"
        end=$(( $(date +%s) + SHORT_BREAK * 60 ))
      fi
    else
      count=$(( count + 1 ))
      phase="work"
      end=$(( $(date +%s) + WORK * 60 ))
    fi
    paused_left=""
    save_state
    echo "Skipped to $phase"
    ;;

  config)
    WORK="${2:-$WORK}"
    SHORT_BREAK="${3:-$SHORT_BREAK}"
    LONG_BREAK="${4:-$LONG_BREAK}"
    LONG_BREAK_AFTER="${5:-$LONG_BREAK_AFTER}"
    save_conf
    echo "Config: work=${WORK}m short=${SHORT_BREAK}m long=${LONG_BREAK}m every=${LONG_BREAK_AFTER}"
    ;;

  status)
    load_state
    [ -z "$phase" ] && exit 0

    if [ -n "$paused_left" ]; then
      mins=$(( paused_left / 60 ))
      secs=$(( paused_left % 60 ))
      case "$phase" in
        work)        label="" ;;
        short_break) label="" ;;
        long_break)  label="" ;;
      esac
      printf "%s %02d:%02d ⏸\n" "$label" "$mins" "$secs"
      exit 0
    fi

    now=$(date +%s)
    left=$(( end - now ))

    if [ "$left" -le 0 ]; then
      if [ "$phase" = "work" ]; then
        if [ $(( count % LONG_BREAK_AFTER )) -eq 0 ]; then
          phase="long_break"
          end=$(( now + LONG_BREAK * 60 ))
        else
          phase="short_break"
          end=$(( now + SHORT_BREAK * 60 ))
        fi
      else
        count=$(( count + 1 ))
        phase="work"
        end=$(( now + WORK * 60 ))
      fi
      paused_left=""
      save_state
      left=$(( end - now ))
    fi

    mins=$(( left / 60 ))
    secs=$(( left % 60 ))
    case "$phase" in
      work)        label="" ;;
      short_break) label="" ;;
      long_break)  label="" ;;
    esac
    printf "%s %02d:%02d #%d\n" "$label" "$mins" "$secs" "$count"
    ;;
esac
