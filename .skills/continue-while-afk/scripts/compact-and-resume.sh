#!/usr/bin/env bash
# Usage: compact-and-resume.sh <boss-pane> <resets-at-epoch> <state-file>
# Run it detached (setsid -f), because /compact runs while it waits.
# 1. Waits until the boss turn ends (the Stop hook sets the pane option @agent-state to done).
# 2. Sends /compact to the boss.
# 3. Sleeps until the 5-hour usage window resets, then tells the boss to resume the AFK run.
set -euo pipefail

[[ $# -eq 3 ]] || { echo "usage: $(basename "$0") <boss-pane> <resets-at-epoch> <state-file>" >&2; exit 2; }
boss_pane=$1
resets_at=$2
state_file=$3
[[ "$boss_pane" =~ ^%[0-9]+$ ]] || { echo 'compact-and-resume: invalid boss pane ID' >&2; exit 2; }
[[ "$resets_at" =~ ^[0-9]+$ ]] || { echo 'compact-and-resume: invalid reset time' >&2; exit 2; }
[[ -r "$state_file" ]] || { echo "compact-and-resume: cannot read $state_file" >&2; exit 2; }

send_to_pane="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../assign-work/scripts" && pwd)/send-to-pane.sh"
turn_end_timeout=${TURN_END_TIMEOUT_SECONDS:-600}
# A margin after the reset, so that the first request of the boss is in the new window.
reset_margin=${RESET_MARGIN_SECONDS:-120}

wait_for_turn_end() {
  local deadline=$(( $(date +%s) + turn_end_timeout ))
  until [[ "$(tmux show-options -pqv -t "$boss_pane" @agent-state)" == done ]]; do
    (( $(date +%s) < deadline )) || { echo 'compact-and-resume: boss turn did not end' >&2; exit 1; }
    sleep 2
  done
}

wait_for_turn_end
# Typed input while a turn ends can be lost, so wait a little after the Stop hook.
sleep 3
"$send_to_pane" "$boss_pane" "/compact Keep the AFK run state. The full state is in $state_file."

wake_at=$(( resets_at + reset_margin ))
# Sleep in short steps: one long sleep can oversleep when the machine suspends.
while (( (remaining = wake_at - $(date +%s)) > 0 )); do
  sleep $(( remaining > 60 ? 60 : remaining ))
done
"$send_to_pane" "$boss_pane" "From the usage guard: The 5-hour usage limit reset. Resume the AFK run. Read $state_file, then follow \"Resume after the usage limit\" in the continue-while-afk skill."
