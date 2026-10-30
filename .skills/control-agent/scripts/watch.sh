#!/usr/bin/env bash
# Usage: watch.sh <tmux-session> [<tmux-session> ...]
# Exits 0 with "IDLE: <session>" when one session's pane is idle and still for IDLE_SECONDS.
# Exits 1 with "GONE: <session>" when a session no longer exists.
set -euo pipefail

POLL_SECONDS="${POLL_SECONDS:-15}"
IDLE_SECONDS="${IDLE_SECONDS:-90}"
# Claude Code prints "… (12s" or "… (3m" next to its spinner while a turn runs.
BUSY_PATTERN='…[[:space:]]*\([0-9]+[ms]'

if [[ $# -eq 0 ]]; then
  echo "usage: $(basename "$0") <tmux-session> [...]" >&2
  exit 2
fi

declare -A last_hash
declare -A still_since

while true; do
  now=$(date +%s)
  for session in "$@"; do
    if ! pane=$(tmux capture-pane -p -t "$session" 2>/dev/null); then
      echo "GONE: $session"
      exit 1
    fi

    if grep -qE "$BUSY_PATTERN" <<<"$pane"; then
      unset 'last_hash[$session]' 'still_since[$session]'
      continue
    fi

    hash=$(md5sum <<<"$pane" | cut -d' ' -f1)
    if [[ "${last_hash[$session]:-}" != "$hash" ]]; then
      last_hash[$session]=$hash
      still_since[$session]=$now
      continue
    fi

    if (( now - still_since[$session] >= IDLE_SECONDS )); then
      echo "IDLE: $session"
      exit 0
    fi
  done
  sleep "$POLL_SECONDS"
done
