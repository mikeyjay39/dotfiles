#!/usr/bin/env bash
# Usage: watch-merge-queue.sh <pr> [owner/repo]
# Exits when the PR merges, closes, leaves the merge queue without merging, or loses auto-merge.
set -uo pipefail
pr="$1"; repo="${2:-valstro/omskit}"; owner="${repo%/*}"; name="${repo#*/}"
was_queued=false
while true; do
  out=$(gh api graphql -f query="query{repository(owner:\"$owner\",name:\"$name\"){pullRequest(number:$pr){state mergedAt isInMergeQueue mergeQueueEntry{state position} autoMergeRequest{enabledAt}}}}" --jq '.data.repository.pullRequest' 2>/dev/null) || { sleep 60; continue; }
  state=$(jq -r .state <<<"$out"); queued=$(jq -r .isInMergeQueue <<<"$out"); auto=$(jq -r '.autoMergeRequest != null' <<<"$out")
  if [[ "$state" == "MERGED" ]]; then echo "MERGED: $out"; exit 0; fi
  if [[ "$state" == "CLOSED" ]]; then echo "CLOSED: $out"; exit 1; fi
  if [[ "$queued" == "true" ]]; then was_queued=true; fi
  if [[ "$was_queued" == "true" && "$queued" == "false" ]]; then echo "LEFT_QUEUE: $out"; exit 2; fi
  if [[ "$queued" == "false" && "$auto" == "false" ]]; then echo "NO_AUTOMERGE: $out"; exit 3; fi
  sleep 60
done
