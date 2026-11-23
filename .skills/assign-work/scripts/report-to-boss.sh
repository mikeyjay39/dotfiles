#!/usr/bin/env bash
# Usage: report-to-boss.sh <message>
# Run from inside a worker started by assign-work.sh. Types "From worker <session>: <message>"
# into the boss pane and submits it.
set -euo pipefail

[[ $# -ge 1 && -n "$1" ]] || { echo "usage: $(basename "$0") <message>" >&2; exit 2; }
[[ -n "${TMUX_PANE:-}" ]] || { echo "report-to-boss: not in a tmux pane" >&2; exit 1; }

session=$(tmux display -p -t "$TMUX_PANE" '#S')
# Read from the session, because the shell that runs this can start before the variable is set.
boss_pane=$(tmux show-environment -t "$session" ASSIGN_WORK_BOSS_PANE 2>/dev/null | cut -d= -f2-) ||
  { echo "report-to-boss: session $session has no ASSIGN_WORK_BOSS_PANE" >&2; exit 1; }
[[ -n "$boss_pane" ]] || { echo "report-to-boss: session $session has no ASSIGN_WORK_BOSS_PANE" >&2; exit 1; }

exec "$(dirname "$0")/send-to-pane.sh" "$boss_pane" "From worker $session: $*"
