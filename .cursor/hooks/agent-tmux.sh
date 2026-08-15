#!/usr/bin/env bash
# Cursor / Claude agent lifecycle → tmux pane state + desktop notify.
# Usage: agent-tmux.sh <running|done|needs-input|off> [agent-name]
# Always drains stdin (hook JSON). Exit 0 so agents never fail-closed on notify.
set -u

state="${1:-done}"
agent="${2:-agent}"
payload="$(cat || true)"

status=""
hook_event=""
if command -v jq >/dev/null 2>&1 && [[ -n "$payload" ]]; then
  status="$(printf '%s' "$payload" | jq -r '.status // empty' 2>/dev/null || true)"
  hook_event="$(printf '%s' "$payload" | jq -r '.hook_event_name // empty' 2>/dev/null || true)"
fi

# Cursor stop: skip cancelled turns
if [[ "$state" == "done" && "$status" == "aborted" ]]; then
  exit 0
fi

case "$state" in
  running) label="running"; urgency="low"; icon="dialog-information"; do_notify=0; do_sound=0 ;;
  needs-input) label="needs input"; urgency="critical"; icon="dialog-warning"; do_notify=1; do_sound=1 ;;
  off) label="idle"; urgency="low"; icon="dialog-information"; do_notify=0; do_sound=0 ;;
  *)
    state="done"
    label="done"
    [[ -n "$status" && "$status" != "completed" ]] && label="done ($status)"
    urgency="normal"
    icon="dialog-information"
    do_notify=1
    do_sound=1
    ;;
esac

title="${agent} agent"
body="$label"
[[ -n "$hook_event" ]] && body="$body · $hook_event"

if [[ "$do_notify" -eq 1 ]] && command -v notify-send >/dev/null 2>&1; then
  notify-send -u "$urgency" -i "$icon" "$title" "$body" 2>/dev/null || true
fi

if [[ "$do_sound" -eq 1 ]] && command -v paplay >/dev/null 2>&1; then
  sound=""
  case "$state" in
    done) sound="/usr/share/sounds/freedesktop/stereo/complete.oga" ;;
    needs-input) sound="/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga" ;;
  esac
  if [[ -n "$sound" && -r "$sound" ]]; then
    paplay "$sound" 2>/dev/null || true
  fi
fi

tmux_bin="$(command -v tmux || true)"
[[ -z "$tmux_bin" ]] && exit 0
"$tmux_bin" list-sessions >/dev/null 2>&1 || exit 0

set_pane_state() {
  local pane="$1"
  "$tmux_bin" set-option -p -t "$pane" @agent-state "$state" 2>/dev/null || true
  "$tmux_bin" set-option -p -t "$pane" @agent-name "$agent" 2>/dev/null || true
  "$tmux_bin" set-option -w -t "$pane" @agent-state "$state" 2>/dev/null || true
  "$tmux_bin" set-option -w -t "$pane" @agent-name "$agent" 2>/dev/null || true
}

if [[ -n "${TMUX_PANE:-}" ]]; then
  set_pane_state "$TMUX_PANE"
elif [[ "$state" != "off" ]]; then
  # IDE hooks often run outside a pane: stamp panes whose process looks like an agent.
  while IFS= read -r pane; do
    [[ -n "$pane" ]] && set_pane_state "$pane"
  done < <(
    "$tmux_bin" list-panes -a -F '#{pane_id} #{pane_current_command}' 2>/dev/null |
      awk 'tolower($2) ~ /cursor|claude|agent/ { print $1 }'
  )
fi

if [[ "$do_notify" -eq 1 ]]; then
  "$tmux_bin" display-message -d 4000 "${agent}: ${label}" 2>/dev/null || true
fi
exit 0
