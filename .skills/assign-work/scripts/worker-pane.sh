#!/usr/bin/env bash
# Usage: worker-pane.sh <session>
# Resolve one agent pane. Do not use the session's active window.
set -euo pipefail
[[ $# -eq 1 || ( $# -eq 2 && "$2" == --agent ) ]] || exit 2
session=$1
source "$(dirname "$0")/worker-cli.sh"
fail() { echo "worker-pane: $*" >&2; exit 1; }
tmux has-session -t "=$session" 2>/dev/null || fail "session $session does not exist"
process_runs_agent() {
  local pid=$1 depth=$2 child
  (( depth < 8 )) || return 1
  local program
  program=$(ps -o args= -p "$pid" | awk '{print $1}')
  if is_agent_program "$program"; then basename -- "$program"; return 0; fi
  for child in $(pgrep -P "$pid" 2>/dev/null); do
    process_runs_agent "$child" "$((depth + 1))" && return 0
  done
  return 1
}
registered_pane=$(tmux show-options -qv -t "=$session:" @assign_work_pane)
panes=$(tmux list-panes -s -t "=$session" -F '#{pane_id} #{pane_current_command} #{pane_pid}')
agent_panes=()
agent_programs=()
while read -r pane_id current_command pane_pid; do
  [[ -z "$registered_pane" || "$pane_id" == "$registered_pane" ]] || continue
  program=''
  if is_agent_program "$current_command"; then
    program=$(basename -- "$current_command")
  else
    program=$(process_runs_agent "$pane_pid" 0) || continue
  fi
  if [[ -n "$program" ]]; then
    agent_panes+=("$pane_id")
    agent_programs+=("$program")
  fi
done <<<"$panes"
case ${#agent_panes[@]} in
  0) fail "no worker pane in $session runs claude, cursor-agent, or opencode" ;;
  1) if [[ "${2:-}" == --agent ]]; then printf '%s\n' "${agent_programs[0]}"; else printf '%s\n' "${agent_panes[0]}"; fi ;;
  *) fail "more than one pane in $session runs an agent. Use send-to-pane.sh with an explicit pane ID." ;;
esac
