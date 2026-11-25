#!/usr/bin/env bash
# Mock-only tests for watch-usage.sh. A temporary usage file stands in for the status line output.
set -euo pipefail
watch="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/watch-usage.sh"
tmp=$(mktemp -d)
trap 'rm -r -- "$tmp"' EXIT
export XDG_RUNTIME_DIR=$tmp USAGE_POLL_SECONDS=1
usage_file="$tmp/claude-rate-limits.json"
future=$(( $(date +%s) + 3600 ))
past=$(( $(date +%s) - 60 ))

fail() { echo "FAIL: $*" >&2; exit 1; }
write_usage() { printf '{"five_hour":{"used_percentage":%s,"resets_at":%s}}\n' "$1" "$2" >"$usage_file"; }

# Runs the watcher for at most 3 s. Prints its output and exit code; 124 means it still polled.
run_watch() {
  local status=0 output
  output=$(timeout 3 "$watch" "$@") || status=$?
  printf '%s|%s' "$output" "$status"
}

result=$(run_watch)
[[ "$result" == UNKNOWN:*'|2' ]] || fail "missing file: $result"

echo 'not json' >"$usage_file"
result=$(run_watch)
[[ "$result" == UNKNOWN:*'|2' ]] || fail "invalid file: $result"

write_usage 50 "$future"
[[ "$(run_watch)" == '|124' ]] || fail 'below the threshold must keep polling'

write_usage 95 "$past"
[[ "$(run_watch)" == '|124' ]] || fail 'a past reset must keep polling'

write_usage 90.4 "$future"
result=$(run_watch)
[[ "$result" == "USAGE: 90% resets_at=$future|0" ]] || fail "at the threshold: $result"

write_usage 85 "$future"
result=$(run_watch 80)
[[ "$result" == "USAGE: 85% resets_at=$future|0" ]] || fail "custom threshold: $result"

write_usage 50 "$future"
( sleep 1.5; write_usage 92 "$future" ) &
result=$(run_watch)
wait
[[ "$result" == "USAGE: 92% resets_at=$future|0" ]] || fail "rise while polling: $result"

echo 'usage tests passed'
