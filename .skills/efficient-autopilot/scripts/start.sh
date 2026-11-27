#!/usr/bin/env bash
# Usage: start.sh [--base <branch>] <work-item>...
#        start.sh --resume <run-dir>
#        start.sh --rerun <run-dir> <story-id> <fix|proof|fix,proof> <instructions>
# Starts an efficient-autopilot run in a new tmux session, from the main checkout of the current repo.
# A work item is "#<n>", an issue URL, or a description. The top pane runs the pipeline. The bottom
# pane shows progress.sh. Prints "run_dir=" and "session=".
# --rerun queues a request to fix or prove a done or parked story again, with the human's instructions.
# It reuses the run's tmux session: a new window, or only the queue when the pipeline still runs.
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

pipeline_is_running() {
  local phase
  phase=$(jq -r '.phase // ""' "$1/state.json")
  [[ "$phase" != done && "$phase" != failed:* ]]
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

session="autopilot-$(basename "$run_dir")"
session_exists=false
! tmux has-session -t "=$session" 2>/dev/null || session_exists=true
if [[ -n "$rerun_request" ]]; then
  echo "rerun=$rerun_request"
  if [[ "$session_exists" == true ]] && pipeline_is_running "$run_dir"; then
    # The running pipeline takes pending reruns after its stories. A second pipeline would race it.
    echo "run_dir=$run_dir"
    echo "session=$session"
    echo 'queued: the running pipeline does the rerun after its current work'
    exit 0
  fi
elif [[ "$session_exists" == true ]]; then
  [[ "$resuming" == true && -r "$run_dir/state.json" ]] && ! pipeline_is_running "$run_dir" ||
    fail "tmux session $session already exists"
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
if [[ "$session_exists" == true ]]; then
  window=resume
  [[ -z "$rerun_request" ]] || window="rerun-$(basename "$rerun_request" .json)"
  tmux new-window -t "=$session:" -n "$window" -c "$(<"$run_dir/repo")" "$pipeline"
  echo "run_dir=$run_dir"
  echo "session=$session"
  exit 0
fi
tmux new-session -d -s "$session" -c "$(<"$run_dir/repo")" "$pipeline"
tmux split-window -v -l 14 -t "$session" -c "$run_dir" "$progress"
# Select the pane above the new progress pane. A fixed index fails when tmux base-index is not 0.
tmux select-pane -t "$session" -U

echo "run_dir=$run_dir"
echo "session=$session"
