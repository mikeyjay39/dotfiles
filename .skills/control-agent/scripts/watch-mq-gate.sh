#!/usr/bin/env bash
# Usage: watch-mq-gate.sh [repo]
# The merge-queue gate closes when a main-release run on main fails and opens when one passes.
# Exits with "OPEN: <run>" when a main-release run on main succeeds after the latest failure.
set -uo pipefail
repo="${1:-valstro/omskit}"
poll_seconds="${POLL_SECONDS:-120}"
while true; do
  runs=$(gh run list --repo "$repo" --workflow main-release.yaml --branch main --limit 15 \
    --json databaseId,status,conclusion,updatedAt,headSha 2>/dev/null) || { sleep "$poll_seconds"; continue; }
  last_failure=$(jq -r '[.[]|select(.status=="completed" and .conclusion=="failure")|.updatedAt]|max // ""' <<<"$runs")
  opened=$(jq -r --arg f "$last_failure" '[.[]|select(.status=="completed" and .conclusion=="success" and .updatedAt > $f)]|max_by(.updatedAt)|if . then "\(.databaseId) \(.headSha[:10]) \(.updatedAt)" else "" end' <<<"$runs")
  if [[ -n "$opened" ]]; then echo "OPEN: $opened (after failure at $last_failure)"; exit 0; fi
  sleep "$poll_seconds"
done
