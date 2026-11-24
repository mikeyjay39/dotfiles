#!/usr/bin/env bash
# Cursor / Claude / OpenCode lifecycle → tmux pane state + desktop notify.
# Usage: agent-tmux.sh <running|done|needs-input|off> [agent-name]
# OpenCode also requires: --pane <id> --session <id> --client <token> --generation <number> [--quiet]
# Always drains stdin (hook JSON). Exit 0 so agents never fail-closed on notify.
set -u

state="${1:-done}"
agent="${2:-agent}"
payload="$(cat || true)"

# OpenCode events come from a shared server. Only the TUI can bind its session to a pane.
quiet=0
if [[ "$agent" == opencode ]]; then
  shift 2
  pane='' session='' client='' generation=''
  while (( $# )); do
    if [[ "$1" == --quiet ]]; then quiet=1; shift; continue; fi
    [[ $# -ge 2 ]] || exit 0
    case "$1" in
      --pane) pane=$2 ;;
      --session) session=$2 ;;
      --client) client=$2 ;;
      --generation) generation=$2 ;;
      *) exit 0 ;;
    esac
    shift 2
  done
  [[ "$pane" =~ ^%[0-9]+$ && "$session" =~ ^ses[a-zA-Z0-9_-]+$ && "$client" =~ ^[a-zA-Z0-9_-]+$ && "$generation" =~ ^[1-9][0-9]*$ ]] || exit 0
  # Serialize binding and updates across plugin reloads, not only within one TUI instance.
  exec 9>"${XDG_RUNTIME_DIR:-/tmp}/opencode-tmux-pane-${pane#%}.lock" || exit 0
  flock -w 3 9 || exit 0
  binding=$(tmux show-options -pqv -t "$pane" @opencode-binding 2>/dev/null) || exit 0
  if [[ "$state" == bind ]]; then
    if [[ -n "$binding" ]]; then
      IFS='|' read -r previous_session previous_generation previous_client extra <<<"$binding"
      [[ "$previous_session" =~ ^ses[a-zA-Z0-9_-]+$ && "$previous_generation" =~ ^[1-9][0-9]*$ && -n "$previous_client" && -z "$extra" ]] || exit 0
      # Compare canonical decimal strings without integer overflow.
      if (( ${#generation} < ${#previous_generation} )); then exit 0; fi
      if (( ${#generation} == ${#previous_generation} )); then
        [[ "$generation" < "$previous_generation" ]] && exit 0
        [[ "$generation" == "$previous_generation" && "$client" != "$previous_client" ]] && exit 0
      fi
    fi
    tmux set-option -p -t "$pane" @opencode-binding "$session|$generation|$client" 2>/dev/null || true
    exit 0
  fi
  [[ "$binding" == "$session|$generation|$client" ]] || exit 0
  TMUX_PANE=$pane
fi

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
if [[ "$quiet" -eq 1 ]]; then do_notify=0; do_sound=0; fi

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

# Show or hide the agent status line now that the state changed.
~/.config/tmux/agent-status-lines.sh 2>/dev/null || true

[[ "$do_notify" -eq 1 ]] || exit 0

message="${agent}: ${label}"
if [[ -n "${TMUX_PANE:-}" ]]; then
  location="$("$tmux_bin" display-message -p -t "$TMUX_PANE" '#S:#I' 2>/dev/null || true)"
  [[ -n "$location" ]] && message="$message · $location"
fi

# Send to every client, so you see agents in background sessions too.
while IFS= read -r client; do
  [[ -n "$client" ]] && "$tmux_bin" display-message -c "$client" -d 4000 "$message" 2>/dev/null || true
done < <("$tmux_bin" list-clients -F '#{client_name}' 2>/dev/null)
exit 0
