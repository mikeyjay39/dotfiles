#!/usr/bin/env bash
# Usage: requeue-when-open.sh <pr> [owner/repo]
# Waits until the merge queue looks open (a green "Main release", or another PR merged through the
# queue), then turns on auto-merge (squash) and follows the PR through the queue.
# Exits 0 when the PR merges, 1 when it closes, 3 after 3 attempts that the queue removed,
# 4 when auto-merge cannot be turned on.
set -uo pipefail
pr="$1"; repo="${2:-valstro/omskit}"; poll="${POLL_SECONDS:-300}"
here=$(dirname "$0")
for attempt in 1 2 3; do
  since=$(date -u +%FT%TZ)
  echo "attempt $attempt: waiting for the queue to open (since $since)"
  while true; do
    green=$(gh run list -R "$repo" --workflow "Main release" --limit 5 --json conclusion,status,createdAt \
      --jq "[.[]|select(.status==\"completed\" and .conclusion==\"success\" and .createdAt>\"$since\")]|length" 2>/dev/null)
    merged=$(gh pr list -R "$repo" --state merged --limit 10 --json number,mergedAt \
      --jq "[.[]|select(.mergedAt>\"$since\" and .number!=$pr)]|length" 2>/dev/null)
    [[ "${green:-0}" -gt 0 || "${merged:-0}" -gt 0 ]] && break
    sleep "$poll"
  done
  echo "queue looks open (green=$green merged=$merged); enabling auto-merge"
  gh pr merge "$pr" -R "$repo" --auto --squash || { echo "could not enable auto-merge"; exit 4; }
  "$here/watch-merge-queue.sh" "$pr" "$repo"; rc=$?
  [[ $rc -eq 0 ]] && exit 0
  [[ $rc -eq 1 ]] && exit 1
  echo "removed from the queue (rc=$rc); waiting again"
done
exit 3
