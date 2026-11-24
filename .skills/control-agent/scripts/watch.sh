#!/usr/bin/env bash
# Usage: watch.sh <tmux-session> [<tmux-session> ...]
# Exits 0 with "IDLE: <session>" when one session's pane is idle and still for IDLE_SECONDS.
# Exits 1 with "GONE: <session>" when a session no longer exists.
# Exits 2 with "UNKNOWN: <session>" when identity or status checks fail.
# Boss -> registered pane -> CLI identity -> OpenCode API or legacy screen -> idle timer
set -euo pipefail
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../assign-work/scripts" && pwd)

POLL_SECONDS="${POLL_SECONDS:-15}"
IDLE_SECONDS="${IDLE_SECONDS:-90}"
# Claude Code prints "… (12s" or "… (3m" next to its spinner while a turn runs.
BUSY_PATTERN="${BUSY_PATTERN:-…[[:space:]]*\([0-9]+[ms]|Thinking|Running tool|Generating}"

if [[ $# -eq 0 ]]; then
  echo "usage: $(basename "$0") <tmux-session> [...]" >&2
  exit 2
fi

declare -A last_hash
declare -A still_since

while true; do
  now=$(date +%s)
  for session in "$@"; do
    if ! tmux has-session -t "=$session" 2>/dev/null; then
      echo "GONE: $session"
      exit 1
    fi
    target=$("$script_dir/worker-pane.sh" "$session") || { echo "UNKNOWN: $session (worker pane)"; exit 2; }
    pane=$(tmux capture-pane -p -t "$target") || { echo "UNKNOWN: $session (capture)"; exit 2; }
    agent=$(tmux show-options -qv -t "=$session:" @assign_work_agent) || { echo "UNKNOWN: $session (CLI option)"; exit 2; }
    live_agent=$("$script_dir/worker-pane.sh" "$session" --agent) || { echo "UNKNOWN: $session (CLI process)"; exit 2; }
    if [[ "$agent" == opencode || "$live_agent" == opencode ]]; then
      opencode_session=$(tmux show-options -qv -t "=$session:" @assign_work_opencode_session) || { echo "UNKNOWN: $session (session option)"; exit 2; }
      status=0
      "$script_dir/opencode-idle.sh" "$opencode_session" || status=$?
      case "$status" in
        0) ;;
        1) unset 'last_hash[$session]' 'still_since[$session]'; continue ;;
        *) echo "UNKNOWN: $session (OpenCode identity or API)"; exit 2 ;;
      esac
    elif grep -qE "$BUSY_PATTERN" <<<"$pane"; then
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
