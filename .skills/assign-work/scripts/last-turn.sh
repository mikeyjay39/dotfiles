#!/usr/bin/env bash
# Usage: last-turn.sh <session>
# Prints the worker's last turn in a compact form, so the boss reads less text.
# Claude: the final assistant message of the turn, from the session transcript.
# It leaves out the TUI frame, spinners, tool output, and the narration between tool calls.
# Cursor, OpenCode, or a missing transcript: the last 60 non-empty lines of the pane.
# LAST_TURN_LINES (default 80) limits the output.
set -euo pipefail
[[ $# -eq 1 ]] || { echo "usage: $(basename "$0") <session>" >&2; exit 2; }
session=$1
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
lines=${LAST_TURN_LINES:-80}

# Keep only the text after the last tool call or the last human or boss message: the final
# message of the turn. A user entry with only tool results does not start a new message.
read -r -d '' last_message_filter <<'JQ' || true
reduce (inputs | select(.isSidechain != true and .isMeta != true)) as $entry ([];
  if $entry.type == "user" and
     ([$entry.message.content // [] | if type == "string" then {type: "text"} else .[] end
       | select(.type != "tool_result")] | length > 0)
  then []
  elif $entry.type == "assistant"
  then reduce ($entry.message.content // [] | .[]?) as $part (.;
    if $part.type == "tool_use" then [] elif $part.type == "text" then . + [$part.text] else . end)
  else . end)
| join("\n\n")
JQ

pane_tail() {
  local pane
  pane=$("$script_dir/worker-pane.sh" "$session")
  tmux capture-pane -p -J -S -200 -t "$pane" | awk 'NF' | tail -60
}

# Claude Code keeps transcripts per working folder, with each non-alphanumeric character as "-".
transcript_file() {
  local worktree id folder
  worktree=$(tmux display -p -t "=$session:" '#{session_path}')
  id=$(tmux show-options -qv -t "=$session:" @assign_work_claude_session)
  folder="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/${worktree//[^a-zA-Z0-9]/-}"
  if [[ -n "$id" ]]; then
    echo "$folder/$id.jsonl"
    return
  fi
  # Older sessions have no registered ID. Use the newest transcript of the worktree.
  [[ -d "$folder" ]] || return 0
  find "$folder" -maxdepth 1 -name '*.jsonl' -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-
}

tmux has-session -t "=$session" 2>/dev/null || { echo "last-turn: session $session does not exist" >&2; exit 1; }
agent=$(tmux show-options -qv -t "=$session:" @assign_work_agent)
[[ -n "$agent" ]] || agent=$("$script_dir/worker-pane.sh" "$session" --agent)
if [[ "$agent" != claude ]]; then
  pane_tail
  exit 0
fi

transcript=$(transcript_file)
if [[ -z "$transcript" || ! -r "$transcript" ]]; then
  echo "last-turn: no transcript for $session. Showing the pane." >&2
  pane_tail
  exit 0
fi
message=$(jq -rn "$last_message_filter" "$transcript")
[[ -n "$message" ]] || message='(The last message has no text. Read the pane for tool output.)'
tail -n "$lines" <<<"$message"
