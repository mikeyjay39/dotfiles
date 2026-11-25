#!/usr/bin/env bash
# Claude Code status line: <model> | <branch> | ctx <N>% | 5h <N>% (resets HH:MM) | <tokens> tokens.
# Each item is skipped when it is missing.
input=$(cat)
model=$(jq -r '.model.display_name // empty' <<<"$input")
dir=$(jq -r '.workspace.current_dir // .cwd // empty' <<<"$input")
used=$(jq -r '.context_window.used_percentage // empty | round' <<<"$input")
tokens=$(jq -r '.context_window.total_input_tokens // empty' <<<"$input")
rate_limits=$(jq -c '.rate_limits // empty' <<<"$input")
session_used=$(jq -r '.five_hour.used_percentage // empty | round' <<<"$rate_limits")
session_resets_at=$(jq -r '.five_hour.resets_at // empty' <<<"$rate_limits")

# The continue-while-afk usage guard reads this file: only the status line gets rate limits.
# Write it with mv, so that a reader never sees a half-written file.
if [[ -n "$rate_limits" ]]; then
  usage_file="${XDG_RUNTIME_DIR:-/tmp}/claude-rate-limits.json"
  printf '%s\n' "$rate_limits" >"$usage_file.$$" && mv -f "$usage_file.$$" "$usage_file"
fi

branch=''
# Skip optional locks so the status line never blocks a git command.
[[ -n "$dir" ]] && branch=$(GIT_OPTIONAL_LOCKS=0 git -C "$dir" branch --show-current 2>/dev/null)
session=''
if [[ -n "$session_used" ]]; then
  session="5h ${session_used}%"
  [[ -n "$session_resets_at" ]] && session+=" (resets $(date -d "@$session_resets_at" +%H:%M))"
fi
parts=()
[[ -n "$model" ]] && parts+=("$model")
[[ -n "$branch" ]] && parts+=("$branch")
[[ -n "$used" ]] && parts+=("ctx ${used}%")
[[ -n "$session" ]] && parts+=("$session")
# Add thousands separators with sed: printf %'d depends on the locale.
[[ -n "$tokens" ]] && parts+=("$(sed -E ":a;s/([0-9])([0-9]{3})($|,)/\1,\2\3/;ta" <<<"$tokens") tokens")
out=''
for part in "${parts[@]}"; do out+="${out:+ | }$part"; done
printf '%s' "$out"
