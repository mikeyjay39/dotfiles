#!/usr/bin/env bash
# Claude Code status line: <model> | <branch> | ctx <N>% | <tokens> tokens.
# Each item is skipped when it is missing.
input=$(cat)
model=$(jq -r '.model.display_name // empty' <<<"$input")
dir=$(jq -r '.workspace.current_dir // .cwd // empty' <<<"$input")
used=$(jq -r '.context_window.used_percentage // empty | round' <<<"$input")
tokens=$(jq -r '.context_window.total_input_tokens // empty' <<<"$input")
branch=''
# Skip optional locks so the status line never blocks a git command.
[[ -n "$dir" ]] && branch=$(GIT_OPTIONAL_LOCKS=0 git -C "$dir" branch --show-current 2>/dev/null)
parts=()
[[ -n "$model" ]] && parts+=("$model")
[[ -n "$branch" ]] && parts+=("$branch")
[[ -n "$used" ]] && parts+=("ctx ${used}%")
# Add thousands separators with sed: printf %'d depends on the locale.
[[ -n "$tokens" ]] && parts+=("$(sed -E ":a;s/([0-9])([0-9]{3})($|,)/\1,\2\3/;ta" <<<"$tokens") tokens")
out=''
for part in "${parts[@]}"; do out+="${out:+ | }$part"; done
printf '%s' "$out"
