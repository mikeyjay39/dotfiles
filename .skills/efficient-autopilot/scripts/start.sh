#!/usr/bin/env bash
# Usage: start.sh <work-item>...
#        start.sh --resume <run-dir>
# Starts an efficient-autopilot run in a new tmux session, from the main checkout of the current repo.
# A work item is "#<n>", an issue URL, or a description. The top pane runs the pipeline. The bottom
# pane shows progress.sh. Prints "run_dir=" and "session=".
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

usage() {
  sed -n '2,3p' "$0" | sed 's/^# //' >&2
  exit 2
}

fail() {
  echo "start: $*" >&2
  exit 1
}

new_run_dir() {
  local repo=$1 run_id item
  run_id=$(date +%Y%m%d-%H%M%S)
  run_dir="${XDG_STATE_HOME:-$HOME/.local/state}/efficient-autopilot/$(basename "$repo")/$run_id"
  mkdir -p "$run_dir"
  printf '%s\n' "$repo" >"$run_dir/repo"
  {
    echo "Work items given to the run:"
    for item in "${@:2}"; do
      printf -- '- %s\n' "$item"
    done
  } >"$run_dir/input.md"
  echo "$run_dir"
}

[[ $# -ge 1 ]] || usage
command -v tmux >/dev/null || fail 'tmux is not installed'

if [[ "$1" == --resume ]]; then
  [[ $# -eq 2 && -r "$2/repo" ]] || usage
  run_dir=$(cd "$2" && pwd)
else
  repo=$(git rev-parse --show-toplevel 2>/dev/null) || fail 'run this from a git repo'
  [[ "$(git rev-parse --git-dir)" == "$(git rev-parse --git-common-dir)" ]] ||
    fail 'run this from the main checkout, not from a worktree'
  run_dir=$(new_run_dir "$repo" "$@")
fi

session="autopilot-$(basename "$run_dir")"
! tmux has-session -t "=$session" 2>/dev/null || fail "tmux session $session already exists"

printf -v pipeline '%q ' "$script_dir/autopilot.sh" "$run_dir"
# Keep the machine awake during the run. systemd-inhibit is absent on some hosts.
if command -v systemd-inhibit >/dev/null; then
  printf -v pipeline '%q ' systemd-inhibit --what=sleep:idle --who=efficient-autopilot \
    --why='Autopilot run in progress' "$script_dir/autopilot.sh" "$run_dir"
fi
printf -v progress '%q ' watch -n 10 "$script_dir/progress.sh" "$run_dir"

tmux new-session -d -s "$session" -c "$(<"$run_dir/repo")" \
  "$pipeline; echo; echo 'Run ended. Summary: $run_dir/summary.md. Press Enter to close.'; read -r"
tmux split-window -v -l 14 -t "$session" -c "$run_dir" "$progress"
tmux select-pane -t "$session:0.0"

echo "run_dir=$run_dir"
echo "session=$session"
