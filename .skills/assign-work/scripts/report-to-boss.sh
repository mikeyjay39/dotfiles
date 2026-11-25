#!/usr/bin/env bash
# Usage: report-to-boss.sh [--session <worker> --boss-pane <pane-id>] <message>
# Run from inside a worker started by assign-work.sh. Types "From worker <session>: <message>"
# into the boss pane and submits it. Then it records the report time and kind in the worker
# session, so that watch.sh does not wake the boss a second time for the same stop.
set -euo pipefail

if [[ "${1:-}" == --session ]]; then
  [[ $# -ge 5 && "$3" == --boss-pane && "$2" =~ ^[a-zA-Z0-9_-]+$ && "$4" =~ ^%[0-9]+$ ]] || {
    echo 'report-to-boss: use --session <worker> --boss-pane <pane-id> <message>' >&2; exit 2;
  }
  session=$2 boss_pane=$4
  shift 4
  [[ -n "$1" ]] || exit 2
else
  [[ $# -ge 1 && -n "$1" ]] || { echo "usage: $(basename "$0") <message>" >&2; exit 2; }
  [[ -n "${TMUX_PANE:-}" ]] || { echo "report-to-boss: not in a tmux pane" >&2; exit 1; }
  session=$(tmux display -p -t "$TMUX_PANE" '#S')
  # Read from the session, because the shell that runs this can start before the variable is set.
  boss_pane=$(tmux show-environment -t "$session" ASSIGN_WORK_BOSS_PANE 2>/dev/null | cut -d= -f2-) ||
    { echo "report-to-boss: session $session has no ASSIGN_WORK_BOSS_PANE" >&2; exit 1; }
  [[ -n "$boss_pane" ]] || { echo "report-to-boss: session $session has no ASSIGN_WORK_BOSS_PANE" >&2; exit 1; }
fi

# A typed newline submits the boss input early, so a report is always one line.
message=$*
message=${message//$'\n'/ }
"$(dirname "$0")/send-to-pane.sh" "$boss_pane" "From worker $session: $message"
tmux set-option -t "=$session:" @assign_work_last_report "$(date +%s) ${message%%:*}" ||
  echo "report-to-boss: the report was sent, but its time was not recorded. The watcher can wake the boss again." >&2
