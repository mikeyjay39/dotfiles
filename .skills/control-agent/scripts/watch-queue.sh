#!/usr/bin/env bash
# Usage: watch-queue.sh <pr-number> [repo]
# Exits with MERGED when the PR merges, CLOSED when it closes, or DEQUEUED when it leaves the merge queue
# without merging (a failed queue run), so the caller can read the failure and requeue.
pr=$1
repo=${2:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}
owner=${repo%/*}
name=${repo#*/}
poll_seconds=${POLL_SECONDS:-120}

while sleep "$poll_seconds"; do
  # A failed poll (network, rate limit) is skipped, so it does not look like a dequeue.
  status=$(gh api graphql -f query="query{repository(owner:\"$owner\",name:\"$name\"){pullRequest(number:$pr){state autoMergeRequest{enabledAt} mergeQueueEntry{state}}}}" \
    --jq '.data.repository.pullRequest | "\(.state) \(.mergeQueueEntry.state // "NONE") \(if .autoMergeRequest then "AUTO" else "MANUAL" end)"') || continue
  case "$status" in
    MERGED*) echo "MERGED"; exit 0 ;;
    CLOSED*) echo "CLOSED"; exit 0 ;;
    # Auto-merge waits outside the queue until the PR's checks pass. A failed queue run turns it off.
    "OPEN NONE MANUAL") echo "DEQUEUED"; exit 0 ;;
  esac
done
