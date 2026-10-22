#!/usr/bin/env bash
# Switch a client to the first agent pane that needs input, else the first one that is done.
# Usage: agent-jump.sh <client-name>
# @agent-state is set by ~/.cursor/hooks/agent-tmux.sh.
set -u

client="${1:?client name required}"

find_pane_in_state() {
  tmux list-panes -a -F '#{pane_id} #{@agent-state}' |
    awk -v state="$1" '$2 == state { print $1; exit }'
}

pane="$(find_pane_in_state needs-input)"
[[ -z "$pane" ]] && pane="$(find_pane_in_state done)"

if [[ -z "$pane" ]]; then
  tmux display-message -c "$client" "no agents waiting"
  exit 0
fi

# A pane target makes switch-client select its window and pane as well.
tmux switch-client -c "$client" -t "$pane"
