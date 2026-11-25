#!/usr/bin/env bash
# Shared worker checks for watch.sh and status.sh. Source this file; do not run it.
assign_work_scripts=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../assign-work/scripts" && pwd)

# Claude Code prints "… (12s" or "… (3m" next to its spinner while a turn runs.
BUSY_PATTERN="${BUSY_PATTERN:-…[[:space:]]*\([0-9]+[ms]|Thinking|Running tool|Generating}"

# read_worker <session>
# Sets worker_screen and worker_busy (true or false).
# Returns 1 when the session is gone. Returns 2 and sets worker_error when a check fails.
read_worker() {
  local session=$1 target agent live_agent opencode_session status=0
  worker_screen='' worker_busy=false worker_error=''
  tmux has-session -t "=$session" 2>/dev/null || return 1
  target=$("$assign_work_scripts/worker-pane.sh" "$session") || { worker_error='worker pane'; return 2; }
  worker_screen=$(tmux capture-pane -p -t "$target") || { worker_error='capture'; return 2; }
  agent=$(tmux show-options -qv -t "=$session:" @assign_work_agent) || { worker_error='CLI option'; return 2; }
  live_agent=$("$assign_work_scripts/worker-pane.sh" "$session" --agent) || { worker_error='CLI process'; return 2; }
  if [[ "$agent" == opencode || "$live_agent" == opencode ]]; then
    # The OpenCode screen can keep old busy words, so only its API decides.
    opencode_session=$(tmux show-options -qv -t "=$session:" @assign_work_opencode_session) ||
      { worker_error='session option'; return 2; }
    "$assign_work_scripts/opencode-idle.sh" "$opencode_session" || status=$?
    case "$status" in
      0) ;;
      1) worker_busy=true ;;
      *) worker_error='OpenCode identity or API'; return 2 ;;
    esac
  elif grep -qE "$BUSY_PATTERN" <<<"$worker_screen"; then
    worker_busy=true
  fi
}

# last_report <session>
# Prints "<epoch> <kind>" of the last report that report-to-boss.sh recorded, or nothing.
last_report() {
  tmux show-options -qv -t "=$1:" @assign_work_last_report
}
