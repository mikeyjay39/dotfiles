#!/usr/bin/env bash
# Show the second status line only for sessions that have something to put on it:
# an agent in another session (see @agent_elsewhere), or the open session tree (key hints).
# @agent-state is set by ~/.cursor/hooks/agent-tmux.sh.
set -u

# Sessions that own at least one window with a visible agent state.
agent_sessions="$(
  tmux list-windows -a -F '#{session_id} #{@agent-state}' |
    awk '$2 ~ /^(running|done|needs-input)$/ { print $1 }' |
    sort -u
)"

has_agent_elsewhere() {
  [[ -n "$agent_sessions" ]] && grep -qvxF "$1" <<<"$agent_sessions"
}

tmux list-sessions -F '#{session_id} #{pane_mode}' | while read -r session mode; do
  if [[ "$mode" == "tree-mode" ]] || has_agent_elsewhere "$session"; then
    tmux set-option -t "$session" status 2
  else
    tmux set-option -t "$session" -u status
  fi
done
