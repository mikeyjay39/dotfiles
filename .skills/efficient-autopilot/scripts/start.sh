#!/usr/bin/env bash
# Usage: start.sh [--base <branch>] <work-item>...
#        start.sh --resume <run-dir>
#        start.sh --rerun <run-dir> <story-id> <fix|proof|fix,proof> <instructions>
# Starts an efficient-autopilot run in a tmux window, from the main checkout of the current repo.
# A work item is "#<n>", an issue URL, or a description. The top pane runs the pipeline. The bottom
# pane shows progress.sh. Prints "run_dir=", "session=", and "window=".
# --rerun queues a request to fix or prove a done or parked story again, with the human's instructions.
# All runs of a repo share one tmux session, autopilot-<repo>. Each start opens a window in it.
# A rerun only queues when the pipeline of its run still runs.
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

usage() {
  sed -n '2,4p' "$0" | sed 's/^# //' >&2
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

# Writes <run-dir>/reruns/<n>.json. Prints the request file.
queue_rerun() {
  local run_dir=$1 id=$2 steps=$3 instructions=$4 status n request
  [[ -r "$run_dir/plan.json" && -r "$run_dir/state.json" ]] || fail "$run_dir has no plan. Only a planned run can rerun a story"
  jq -e --arg id "$id" '.stories | any(.id == $id)' "$run_dir/plan.json" >/dev/null || fail "story $id is not in the plan"
  status=$(jq -r --arg id "$id" '.stories[$id].status // "queued"' "$run_dir/state.json")
  [[ "$status" == done || "$status" == parked ]] || fail "story $id is $status. Only a done or parked story can rerun"
  [[ "$steps" =~ ^(fix|proof|fix,proof)$ ]] || fail "steps must be fix, proof, or fix,proof, not $steps"
  [[ -n "${instructions// /}" ]] || fail 'give the instructions for the rerun'
  mkdir -p "$run_dir/reruns"
  n=$(($(find "$run_dir/reruns" -name '*.json' | wc -l) + 1))
  request="$run_dir/reruns/$n.json"
  jq -n --argjson n "$n" --arg id "$id" --arg steps "$steps" --arg text "$instructions" --arg at "$(date -Is)" \
    '{n: $n, story: $id, steps: ($steps | split(",")), instructions: $text, status: "pending", requested_at: $at}' >"$request"
  echo "$request"
}

# True when the run's state says it works and a window of the run is still open. A run that stopped
# without a state update (a reboot, a killed window) does not count.
pipeline_is_alive() {
  local run_dir=$1 session=$2 phase
  [[ -r "$run_dir/state.json" ]] || return 1
  phase=$(jq -r '.phase // ""' "$run_dir/state.json")
  [[ "$phase" != done && "$phase" != failed:* ]] || return 1
  tmux list-windows -t "=$session" -F '#W' 2>/dev/null | grep -q "^$(basename "$run_dir")"
}

[[ $# -ge 1 ]] || usage
command -v tmux >/dev/null || fail 'tmux is not installed'

# The first story is based on this branch, and its PR targets it. Default: the default branch of origin.
base=''
if [[ "$1" == --base ]]; then
  [[ $# -ge 3 && -n "$2" ]] || usage
  base=$2
  shift 2
fi

rerun_request='' resuming=false
if [[ "$1" == --rerun ]]; then
  [[ -z "$base" ]] || fail '--base and --rerun cannot go together'
  [[ $# -eq 5 && -r "$2/repo" ]] || usage
  run_dir=$(cd "$2" && pwd)
  rerun_request=$(queue_rerun "$run_dir" "$3" "$4" "$5")
elif [[ "$1" == --resume ]]; then
  # A resumed run keeps the base branch of its first start.
  [[ -z "$base" ]] || fail '--base and --resume cannot go together'
  [[ $# -eq 2 && -r "$2/repo" ]] || usage
  run_dir=$(cd "$2" && pwd)
  resuming=true
else
  repo=$(git rev-parse --show-toplevel 2>/dev/null) || fail 'run this from a git repo'
  [[ "$(git rev-parse --git-dir)" == "$(git rev-parse --git-common-dir)" ]] ||
    fail 'run this from the main checkout, not from a worktree'
  if [[ -n "$base" ]]; then
    git check-ref-format --branch "$base" >/dev/null 2>&1 || fail "base branch name $base is not valid"
    git ls-remote --exit-code --heads origin "$base" >/dev/null ||
      fail "base branch $base is not on origin. Push it first"
  fi
  run_dir=$(new_run_dir "$repo" "$@")
  [[ -z "$base" ]] || printf '%s\n' "$base" >"$run_dir/base"
fi

# One tmux session per repo. Each run, resume, and rerun is a window in it, so new work never opens
# another session.
session="autopilot-$(basename "$(<"$run_dir/repo")")"
run_id=$(basename "$run_dir")
if [[ -n "$rerun_request" ]]; then
  echo "rerun=$rerun_request"
  window="$run_id-rerun-$(basename "$rerun_request" .json)"
  if pipeline_is_alive "$run_dir" "$session"; then
    # The running pipeline takes pending reruns after its stories. A second pipeline would race it.
    echo "run_dir=$run_dir"
    echo "session=$session"
    echo 'queued: the running pipeline does the rerun after its current work'
    exit 0
  fi
elif [[ "$resuming" == true ]]; then
  window="$run_id-resume"
  ! pipeline_is_alive "$run_dir" "$session" || fail "the pipeline of $run_id still runs in tmux session $session"
else
  window=$run_id
fi

printf -v pipeline '%q ' "$script_dir/autopilot.sh" "$run_dir"
# Keep the machine awake during the run. systemd-inhibit is absent on some hosts, and fails
# when it cannot reach the system bus. Then the run continues without the inhibitor.
if command -v systemd-inhibit >/dev/null && systemd-inhibit --list >/dev/null 2>&1; then
  printf -v pipeline '%q ' systemd-inhibit --what=sleep:idle --who=efficient-autopilot \
    --why='Autopilot run in progress' "$script_dir/autopilot.sh" "$run_dir"
fi
printf -v progress '%q ' watch -n 10 "$script_dir/progress.sh" "$run_dir"
pipeline+="; echo; echo 'Run ended. Summary: $run_dir/summary.md. Press Enter to close.'; read -r"

if tmux has-session -t "=$session" 2>/dev/null; then
  window_id=$(tmux new-window -d -P -F '#{window_id}' -t "=$session:" -n "$window" -c "$(<"$run_dir/repo")" "$pipeline")
else
  window_id=$(tmux new-session -d -P -F '#{window_id}' -s "$session" -n "$window" -c "$(<"$run_dir/repo")" "$pipeline")
fi
tmux split-window -d -v -l 14 -t "$window_id" -c "$run_dir" "$progress"

echo "run_dir=$run_dir"
echo "session=$session"
echo "window=$window"
