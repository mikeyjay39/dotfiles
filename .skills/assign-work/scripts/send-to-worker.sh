#!/usr/bin/env bash
# Usage: send-to-worker.sh <session> <message>
# Types "From the control session: <message>" into the agent pane of a worker session and submits it.
# The target is the pane that runs the agent (claude or cursor-agent), not the active pane: a human
# can open more windows in the session, and text typed into a shell or an editor runs as keys there.
set -euo pipefail

[[ $# -ge 2 ]] || { echo "usage: $(basename "$0") <session> <message>" >&2; exit 2; }
session=$1
shift

fail() { echo "send-to-worker: $*" >&2; exit 1; }

tmux has-session -t "=$session" 2>/dev/null || fail "tmux session $session does not exist"

is_agent_program() {
  case "$(basename -- "$1")" in
    claude | cursor-agent | agent) return 0 ;;
    *) return 1 ;;
  esac
}

# The agent can be the pane's foreground command, or a child of the pane shell (claude can be a
# shell alias, and cursor-agent can show as node). Match only argv[0], because the full command
# line of a shell can hold any text.
pane_runs_agent() {
  local current_command=$1 pane_pid=$2 child_pid
  is_agent_program "$current_command" && return 0
  for child_pid in $(pgrep -P "$pane_pid" 2>/dev/null); do
    is_agent_program "$(ps -o args= -p "$child_pid" | awk '{print $1}')" && return 0
  done
  return 1
}

agent_panes=()
while read -r pane_id current_command pane_pid; do
  if pane_runs_agent "$current_command" "$pane_pid"; then agent_panes+=("$pane_id"); fi
done < <(tmux list-panes -s -t "=$session" -F '#{pane_id} #{pane_current_command} #{pane_pid}')

case ${#agent_panes[@]} in
  0) fail "no pane in session $session runs claude or cursor-agent" ;;
  1) ;;
  *) fail "more than one pane in session $session runs an agent (${agent_panes[*]}). Send with send-to-pane.sh <pane-id> instead." ;;
esac

exec "$(dirname "$0")/send-to-pane.sh" "${agent_panes[0]}" "From the control session: $*"
