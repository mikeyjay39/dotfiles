#!/usr/bin/env bash
# Usage: watch-usage.sh [threshold-percent]
# Exits when the 5-hour session usage of the Claude account reaches the threshold (default 90).
# It prints "USAGE: <pct>% resets_at=<epoch>". ~/.claude/statusline.sh writes the usage file,
# because only the status line gets rate limits. A poll reads a local file and uses no tokens.
# A reset time in the past is stale data from the last window, so it never fires.
# Exits 2 with "UNKNOWN: ..." when the file is absent or not valid, so a failed check never looks safe.
set -euo pipefail

threshold=${1:-90}
poll_seconds=${USAGE_POLL_SECONDS:-60}
usage_file="${XDG_RUNTIME_DIR:-/tmp}/claude-rate-limits.json"
[[ "$threshold" =~ ^[0-9]+$ ]] || { echo "usage: $(basename "$0") [threshold-percent]" >&2; exit 2; }

# Prints "<used-percent> <resets-at>", or fails when the file has no usable 5-hour data.
read_usage() {
  [[ -r "$usage_file" ]] || return 1
  jq -er '.five_hour | select(.used_percentage != null and .resets_at != null)
    | "\(.used_percentage | floor) \(.resets_at | floor)"' "$usage_file" 2>/dev/null
}

while true; do
  usage=$(read_usage) || { echo "UNKNOWN: no 5-hour usage in $usage_file"; exit 2; }
  read -r used resets_at <<<"$usage"
  if (( used >= threshold && resets_at > $(date +%s) )); then
    echo "USAGE: ${used}% resets_at=$resets_at"
    exit 0
  fi
  sleep "$poll_seconds"
done
