#!/usr/bin/env bash
# Mirror Hyprland's runtime log into a durable directory.
# Runtime path: $XDG_RUNTIME_DIR/hypr/<instance>/hyprland.log (cleared on logout).
# Durable path: $XDG_STATE_HOME/hyprland/logs/ (kept across crashes).

set -euo pipefail

STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
LOG_DIR="$STATE_HOME/hyprland/logs"
KEEP_COUNT=10
PID_FILE="$LOG_DIR/mirror.pid"

mkdir -p "$LOG_DIR"

if [[ -f "$PID_FILE" ]]; then
	old_pid="$(cat "$PID_FILE" 2>/dev/null || true)"
	if [[ -n "${old_pid:-}" ]] && kill -0 "$old_pid" 2>/dev/null; then
		kill "$old_pid" 2>/dev/null || true
		# Give the old tail a moment to exit.
		sleep 0.2
	fi
fi

sig="${HYPRLAND_INSTANCE_SIGNATURE:-}"
if [[ -z "$sig" ]]; then
	echo "hypr-durable-log: HYPRLAND_INSTANCE_SIGNATURE is not set" >&2
	exit 1
fi

runtime_log="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/$sig/hyprland.log"
# Wait briefly for Hyprland to create the log file.
i=0
while [[ ! -f "$runtime_log" && "$i" -lt 50 ]]; do
	i=$((i + 1))
	sleep 0.1
done
if [[ ! -f "$runtime_log" ]]; then
	echo "hypr-durable-log: runtime log not found: $runtime_log" >&2
	exit 1
fi

stamp="$(date +%Y%m%d-%H%M%S)"
short_sig="${sig:0:12}"
dest="$LOG_DIR/hyprland-${stamp}-${short_sig}.log"
latest="$LOG_DIR/latest.log"

# Seed with current contents, then follow new lines.
cp -- "$runtime_log" "$dest"
ln -sfn "$(basename "$dest")" "$latest"

# Prune old session logs. Keep the newest KEEP_COUNT files.
mapfile -t old_logs < <(ls -1t "$LOG_DIR"/hyprland-*.log 2>/dev/null || true)
if ((${#old_logs[@]} > KEEP_COUNT)); then
	for stale in "${old_logs[@]:$KEEP_COUNT}"; do
		rm -f -- "$stale"
	done
fi

# Follow in the background for the rest of the session.
(
	# Avoid job-control noise when Hyprland reaps this process on exit.
	exec tail -n 0 -F -- "$runtime_log" >>"$dest" 2>/dev/null
) &
echo $! >"$PID_FILE"
