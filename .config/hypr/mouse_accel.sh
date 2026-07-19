#!/bin/bash
STATE_FILE="/tmp/mouse_accel_state"
DEFAULT_SPEED=10
STEP=10
MAX_SPEED=200
TIME_THRESHOLD_MS=100

now_ms() { date +%s%3N; }

if [[ -f "$STATE_FILE" ]]; then
    read -r last_time last_speed < "$STATE_FILE"
else
    last_time=0
    last_speed=$DEFAULT_SPEED
fi

current_time=$(now_ms)
delta=$((current_time - last_time))

if (( delta <= TIME_THRESHOLD_MS )); then
    new_speed=$((last_speed + STEP))
    [[ $new_speed -gt $MAX_SPEED ]] && new_speed=$MAX_SPEED
else
    new_speed=$DEFAULT_SPEED
fi

echo "$current_time $new_speed" > "$STATE_FILE"
echo $new_speed   
