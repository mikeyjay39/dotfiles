#!/usr/bin/env bash
# Usage: status.sh [<tmux-session> ...]
# Prints one line per worker: session, CLI, busy | waiting | gone | unknown, and the last report.
# With no argument, it lists each tmux session that assign-work registered.
# Use it in place of reading each pane, when the boss only needs to know who waits.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/worker-state.sh"

registered_sessions() {
  local session
  for session in $(tmux list-sessions -F '#{session_name}'); do
    [[ -z "$(tmux show-options -qv -t "=$session:" @assign_work_pane)" ]] || echo "$session"
  done
}

describe_report() {
  local time='' kind=''
  read -r time kind <<<"$(last_report "$1")"
  [[ "$time" =~ ^[0-9]+$ ]] || { echo 'no report'; return; }
  echo "last report $(( ($(date +%s) - time) / 60 ))m ago: $kind"
}

describe_worker() {
  local session=$1 agent status=0 state
  read_worker "$session" || status=$?
  case "$status" in
    0) if [[ "$worker_busy" == true ]]; then state=busy; else state=waiting; fi ;;
    1) printf '%s\t-\tgone\n' "$session"; return ;;
    *) state="unknown ($worker_error)" ;;
  esac
  agent=$(tmux show-options -qv -t "=$session:" @assign_work_agent)
  printf '%s\t%s\t%s\t%s\n' "$session" "${agent:--}" "$state" "$(describe_report "$session")"
}

if [[ $# -eq 0 ]]; then
  mapfile -t sessions < <(registered_sessions)
  set -- "${sessions[@]}"
fi
[[ $# -gt 0 ]] || { echo 'status: no registered worker sessions' >&2; exit 1; }
for session in "$@"; do
  describe_worker "$session"
done
