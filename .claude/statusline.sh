#!/usr/bin/env bash
# Claude Code status line: <branch> | ctx <N>%
set -u
input="$(cat)"
dir="$(jq -r '.workspace.current_dir // .cwd // empty' <<<"$input")"
used="$(jq -r '.context_window.used_percentage // empty' <<<"$input")"

branch="$(git -C "${dir:-.}" branch --show-current 2>/dev/null)"
line=""
[[ -n "$branch" ]] && line="⎇ $branch"
if [[ -n "$used" ]]; then
  [[ -n "$line" ]] && line+=" | "
  line+="ctx $(printf '%.0f' "$used")%"
fi
printf '%s' "$line"
