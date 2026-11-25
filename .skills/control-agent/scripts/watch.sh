#!/usr/bin/env bash
# Usage: watch.sh <tmux-session> [<tmux-session> ...]
# Exits 0 with one "IDLE: <session>" line for each idle session. A session is idle when its
# pane is not busy and does not change for IDLE_SECONDS.
# After the first idle session, it waits up to BATCH_SECONDS for others, so that workers that
# stop together wake the boss one time, not one time each.
# A worker that sent a question, blocked, or done report up to REPORT_GRACE_SECONDS before it
# went still is not reported. The boss already has that report, so a second wake-up costs a turn.
# Exits 1 with "GONE: <session>" when a session no longer exists.
# Exits 2 with "UNKNOWN: <session>" when identity or status checks fail.
# Boss -> registered pane -> CLI identity -> OpenCode API or legacy screen -> idle timer
#      -> recent stop report? skip : collect -> batch window -> print all idle sessions
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/worker-state.sh"

POLL_SECONDS="${POLL_SECONDS:-15}"
IDLE_SECONDS="${IDLE_SECONDS:-300}"
BATCH_SECONDS="${BATCH_SECONDS:-30}"
REPORT_GRACE_SECONDS="${REPORT_GRACE_SECONDS:-120}"

if [[ $# -eq 0 ]]; then
  echo "usage: $(basename "$0") <tmux-session> [...]" >&2
  exit 2
fi

declare -A last_hash
declare -A still_since
declare -A idle
batch_deadline=''

print_idle() {
  local session
  for session in "$@"; do
    [[ -z "${idle[$session]:-}" ]] || echo "IDLE: $session"
  done
}

# reported_before_stop <session> <still-since>
reported_before_stop() {
  local time='' kind=''
  read -r time kind <<<"$(last_report "$1")"
  [[ "$time" =~ ^[0-9]+$ ]] || return 1
  case "$kind" in
    question | blocked | done) ;;
    *) return 1 ;;
  esac
  (( $2 - time <= REPORT_GRACE_SECONDS ))
}

while true; do
  now=$(date +%s)
  for session in "$@"; do
    [[ -z "${idle[$session]:-}" ]] || continue
    status=0
    read_worker "$session" || status=$?
    case "$status" in
      0) ;;
      1) print_idle "$@"; echo "GONE: $session"; exit 1 ;;
      *) print_idle "$@"; echo "UNKNOWN: $session ($worker_error)"; exit 2 ;;
    esac
    if [[ "$worker_busy" == true ]]; then
      unset 'last_hash[$session]' 'still_since[$session]'
      continue
    fi

    hash=$(md5sum <<<"$worker_screen" | cut -d' ' -f1)
    if [[ "${last_hash[$session]:-}" != "$hash" ]]; then
      last_hash[$session]=$hash
      still_since[$session]=$now
      continue
    fi

    (( now - still_since[$session] >= IDLE_SECONDS )) || continue
    if reported_before_stop "$session" "${still_since[$session]}"; then
      continue
    fi
    idle[$session]=1
    [[ -n "$batch_deadline" ]] || batch_deadline=$((now + BATCH_SECONDS))
  done

  if [[ -n "$batch_deadline" ]] && (( now >= batch_deadline || ${#idle[@]} == $# )); then
    print_idle "$@"
    exit 0
  fi
  sleep "$POLL_SECONDS"
done
