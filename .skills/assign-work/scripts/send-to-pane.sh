#!/usr/bin/env bash
# Usage: send-to-pane.sh <tmux-target> <text>
# Types <text> literally into an agent's input, then submits it. The Enter goes in a second call,
# because an Enter sent with the text can arrive before the agent's input box takes the paste.
# A lock per target keeps two senders (for example two workers) from mixing their text.
set -euo pipefail

[[ $# -eq 2 ]] || { echo "usage: $(basename "$0") <tmux-target> <text>" >&2; exit 2; }
target=$1
text=$2

pane_id=$(tmux display -p -t "$target" '#{pane_id}' 2>/dev/null) ||
  { echo "send-to-pane: tmux target $target does not exist" >&2; exit 1; }
[[ "$pane_id" =~ ^%[0-9]+$ ]] || { echo 'send-to-pane: invalid pane ID' >&2; exit 1; }
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/assign-work-pane-${pane_id#%}.lock"
flock -w 30 9 || { echo "send-to-pane: timed out on the lock for $target" >&2; exit 1; }

tmux send-keys -t "$pane_id" -l "$text"
sleep 0.5
tmux send-keys -t "$pane_id" Enter
