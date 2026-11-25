#!/usr/bin/env bash
# Usage: progress.sh <run-dir>
# Prints one screen of run status from state.json, with no model call. Use it with `watch`.
set -euo pipefail
run_dir=${1:?usage: progress.sh <run-dir>}
state="$run_dir/state.json"
plan="$run_dir/plan.json"

echo "efficient-autopilot run $(basename "$run_dir")   $(date '+%H:%M:%S')"
if [[ -r "$run_dir/usage.json" ]]; then
  jq -r '"5 h usage: \(.utilization * 100 | floor)%  resets \(.resets_at | strftime("%H:%M")) UTC"' "$run_dir/usage.json"
fi
if [[ -r "$run_dir/paused.json" ]]; then
  jq -r '"PAUSED: \(.reason) until \(.until | strftime("%H:%M")) UTC"' "$run_dir/paused.json"
fi
[[ -r "$state" ]] || { echo "phase: starting"; exit 0; }
jq -r '"phase: \(.phase // "starting")"' "$state"
[[ -r "$plan" ]] || exit 0

echo
jq -r --slurpfile state "$state" '
  ["STORY", "STATUS", "LAST STEP", "FIXES", "PR"],
  (.stories[] | . as $story | ($state[0].stories[$story.id] // {}) as $s
    | [$story.id, ($s.status // "queued"), ($s.step // "-"), ($s.fix_rounds // 0 | tostring), ($s.pr_url // "-")])
  | @tsv' "$plan" | column -t -s $'\t'

latest=$(ls -t "$run_dir"/logs/*.jsonl 2>/dev/null | head -1 || true)
[[ -n "$latest" ]] || exit 0
echo
echo "last events ($(basename "$latest")):"
tail -n 40 "$latest" | "$(dirname "$0")/pretty-stream.sh" "$(basename "$latest" .jsonl)" | tail -n 5
