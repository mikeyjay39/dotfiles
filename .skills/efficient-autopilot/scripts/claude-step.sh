#!/usr/bin/env bash
# Usage: claude-step.sh --run-dir <dir> --label <label> --model <model> --cwd <dir> --prompt-file <file>
#                       --tools <tools> [--allow <rules>] [--schema <file>] [--resume <session-id>]
#                       [--add-dir <dir>] [--skills]
# Runs one headless `claude -p` step. It shows each event as a short line on stderr, keeps the raw
# events in <run-dir>/logs, and prints the final `result` event as one JSON line on stdout.
# Before each call, and after a usage-limit error, it waits for the 5-hour usage window to reset.
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
skill_dir=$(dirname "$script_dir")
usage_threshold=${AUTOPILOT_USAGE_THRESHOLD:-0.9}
usage_margin_seconds=120
limit_wait_seconds=${AUTOPILOT_LIMIT_WAIT_SECONDS:-1800}
max_limit_waits=12
max_api_retries=2

usage() {
  sed -n '2,4p' "$0" | sed 's/^# //' >&2
  exit 2
}

fail() {
  echo "claude-step: $*" >&2
  exit 1
}

run_dir='' label='' model='' cwd='' prompt_file='' tools='' allow='' schema='' resume='' add_dir='' skills=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skills) skills=true; shift; continue ;;
  esac
  [[ $# -ge 2 ]] || usage
  case "$1" in
    --run-dir) run_dir=$2 ;;
    --label) label=$2 ;;
    --model) model=$2 ;;
    --cwd) cwd=$2 ;;
    --prompt-file) prompt_file=$2 ;;
    --tools) tools=$2 ;;
    --allow) allow=$2 ;;
    --schema) schema=$2 ;;
    --resume) resume=$2 ;;
    --add-dir) add_dir=$2 ;;
    *) usage ;;
  esac
  shift 2
done
[[ -n "$run_dir" && -n "$label" && -n "$model" && -n "$cwd" && -n "$prompt_file" && -n "$tools" ]] || usage
[[ -r "$prompt_file" ]] || fail "cannot read prompt file $prompt_file"
[[ -z "$schema" || -r "$schema" ]] || fail "cannot read schema $schema"

usage_file="$run_dir/usage.json"
mkdir -p "$run_dir/logs"

# Waits until the 5-hour window resets when the last known usage is at the threshold or more.
# Headless runs do not run the status line, so the usage comes from the last rate_limit_event.
wait_for_usage_window() {
  [[ -r "$usage_file" ]] || return 0
  local utilization resets_at now
  read -r utilization resets_at < <(jq -r '"\(.utilization) \(.resets_at)"' "$usage_file")
  now=$(date +%s)
  awk -v u="$utilization" -v t="$usage_threshold" 'BEGIN { exit !(u >= t) }' || return 0
  ((resets_at > now)) || return 0
  sleep_until "$resets_at" "usage is $(awk -v u="$utilization" 'BEGIN { printf "%d", u * 100 }')%"
}

sleep_until() {
  local resets_at=$1 reason=$2 seconds
  seconds=$((resets_at - $(date +%s) + usage_margin_seconds))
  ((seconds > 0)) || return 0
  echo "[$label] pause: $reason. Resume at $(date -d "@$((resets_at + usage_margin_seconds))" '+%H:%M')." >&2
  jq -n --argjson until "$((resets_at + usage_margin_seconds))" --arg reason "$reason" \
    '{until: $until, reason: $reason}' >"$run_dir/paused.json"
  echo "$(date -Is) $label $reason" >>"$run_dir/usage-pauses.log"
  sleep "$seconds"
  rm -f "$run_dir/paused.json"
}

# Keeps the newest five-hour usage from the events of one attempt.
record_usage() {
  local events=$1 latest
  latest=$(jq -R -c 'fromjson? | select(.type == "rate_limit_event") | .rate_limit_info
    | {status, utilization: (.unifiedWindows.five_hour.utilization // 0),
       resets_at: (.unifiedWindows.five_hour.resetsAt // .resetsAt // 0)}' "$events" 2>/dev/null | tail -1)
  [[ -z "$latest" ]] || printf '%s\n' "$latest" >"$usage_file"
}

is_usage_limit_error() {
  local result=$1
  [[ -r "$usage_file" ]] && [[ $(jq -r '.status' "$usage_file") == rejected ]] && return 0
  jq -e '(.result // "") | test("usage limit|rate limit|hit your limit"; "i")' <<<"$result" >/dev/null
}

build_command() {
  command=(claude -p --model "$model" --output-format stream-json --verbose
    --strict-mcp-config --permission-mode acceptEdits
    --settings "$skill_dir/settings/deny.json" --tools "$tools")
  [[ -z "$allow" ]] || command+=(--allowedTools "$allow")
  [[ "$skills" == true ]] || command+=(--disable-slash-commands)
  [[ -z "$schema" ]] || command+=(--json-schema "$(jq -c . "$schema")")
  [[ -z "$add_dir" ]] || command+=(--add-dir "$add_dir")
  [[ -z "$resume" ]] || command+=(--resume "$resume")
  return 0
}

# The CLI can exit before it writes all of a large `result` event, so the last log line is cut off.
# The StructuredOutput tool call before it holds the same output. Prints a result event made from the
# last such call that the tool accepted, or nothing.
recovered_result() {
  local events=$1
  jq -R -n -c --arg session "$attempt_session" '
    [inputs | fromjson?] as $events
    | ($events | map(select(.type == "user") | .message.content[]? | select(.type == "tool_result")
        | {key: .tool_use_id, value: (.is_error // false)}) | from_entries) as $failed
    | [$events[] | select(.type == "assistant") | .message.content[]?
        | select(.type == "tool_use" and .name == "StructuredOutput" and $failed[.id] == false)]
    | last // empty
    | {type: "result", subtype: "success", is_error: false, session_id: $session, structured_output: .input,
       result: "Recovered from the StructuredOutput tool call, because the result event was cut off."}' "$events"
}

# Runs one attempt. Sets `attempt_result` to the result event, or to "" when there is none.
run_attempt() {
  local attempt=$1 input=$2 events="$run_dir/logs/$label.$1.jsonl" status
  build_command
  set +e
  (cd "$cwd" && "${command[@]}" <"$input") | tee "$events" | "$script_dir/pretty-stream.sh" "$label" >&2
  status=${PIPESTATUS[0]}
  set -e
  record_usage "$events"
  # `fromjson?` skips a line that is cut off, so that one bad line does not stop the script.
  attempt_result=$(jq -R -c 'fromjson? | select(.type == "result")' "$events" | tail -1)
  # jq stops at the first match. `jq | head -1` fails with SIGPIPE on a long log, and pipefail then stops the script.
  attempt_session=$(jq -R -rn 'first(inputs | fromjson? | select(.session_id != null) | .session_id) // empty' "$events")
  if [[ -z "$attempt_result" && -n "$schema" ]]; then
    attempt_result=$(recovered_result "$events")
    [[ -z "$attempt_result" ]] || echo "[$label] the result event is cut off. Recovered the structured output." >&2
  fi
  [[ $status -eq 0 || -n "$attempt_result" ]] || attempt_result=''
}

continue_prompt="$run_dir/logs/$label.continue.md"
printf 'The last turn stopped because of an error. Continue the task from where you stopped. Give the same structured output.\n' >"$continue_prompt"

no_result='{}'
input=$prompt_file limit_waits=0 api_retries=0 attempt=0
while true; do
  attempt=$((attempt + 1))
  wait_for_usage_window
  run_attempt "$attempt" "$input"
  if [[ -n "$attempt_result" ]] && jq -e '.is_error == false' <<<"$attempt_result" >/dev/null; then
    printf '%s\n' "$attempt_result"
    exit 0
  fi
  # A partial session keeps its work. Resume it, so that the retry does not start again from zero.
  if [[ -n "$attempt_session" ]]; then
    resume=$attempt_session
    input=$continue_prompt
  fi
  if is_usage_limit_error "${attempt_result:-$no_result}"; then
    ((limit_waits < max_limit_waits)) || fail "usage limit did not reset after $max_limit_waits waits"
    limit_waits=$((limit_waits + 1))
    resets_at=$(jq -r '.resets_at // 0' "$usage_file" 2>/dev/null || echo 0)
    ((resets_at > $(date +%s))) || resets_at=$(($(date +%s) + limit_wait_seconds))
    sleep_until "$resets_at" "usage limit reached"
    continue
  fi
  ((api_retries < max_api_retries)) || fail "step failed: $(jq -r '.result // .subtype // "no result"' <<<"${attempt_result:-$no_result}" | head -c 400)"
  api_retries=$((api_retries + 1))
  echo "[$label] error. Retry $api_retries of $max_api_retries in 60 s." >&2
  sleep 60
done
