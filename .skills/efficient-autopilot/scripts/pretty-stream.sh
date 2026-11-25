#!/usr/bin/env bash
# Usage: pretty-stream.sh <label>
# Reads `claude -p --output-format stream-json` events on stdin. Prints one short line per event,
# so that a human can watch a headless step live. Lines that are not JSON pass through.
set -euo pipefail
label=${1:?usage: pretty-stream.sh <label>}

jq -R -r --unbuffered --arg label "$label" '
  def clip($n): gsub("\\s+"; " ") | if length > $n then .[0:$n] + "…" else . end;
  def tool_target: .input | (.command // .file_path // .pattern // .path // .url // .description // tostring);
  (fromjson? // {type: "text", text: .}) as $e
  | "[\($label)] " + (
      if $e.type == "system" and $e.subtype == "init" then "start model=\($e.model) session=\($e.session_id)"
      elif $e.type == "assistant" then
        ($e.message.content // [] | map(
          if .type == "tool_use" then "\(.name) \(tool_target | clip(140))"
          elif .type == "text" and (.text | length) > 0 then "» \(.text | clip(160))"
          else empty end) | join("\n[\($label)] ")) | select(length > 0)
      elif $e.type == "rate_limit_event" then
        "usage \(($e.rate_limit_info.unifiedWindows.five_hour.utilization // 0) * 100 | floor)% of 5 h (\($e.rate_limit_info.status))"
      elif $e.type == "result" then
        "end \($e.subtype) turns=\($e.num_turns) error=\($e.is_error) cost=$\($e.total_cost_usd // 0 | . * 100 | round / 100)"
      elif $e.type == "text" then $e.text
      else empty end)
' 2>/dev/null || true
