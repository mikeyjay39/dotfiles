#!/usr/bin/env bash
# Usage: assign-work.sh --session <name> --branch <branch> --prompt-file <file>
#                       [--agent claude|cursor|opencode] [--boss-pane <pane>]
# Creates (or reuses) a worktrunk worktree for <branch> from fresh origin/main, starts a tmux
# session in it, and starts a worker agent there with the prompt. The worker reports back to
# the boss pane with report-to-boss.sh. Prints "key=value" lines for the boss to parse.
set -euo pipefail

usage() {
  sed -n '2,3p' "$0" | sed 's/^# //' >&2
  exit 2
}

fail() {
  echo "assign-work: $*" >&2
  exit 1
}

session='' branch='' prompt_file='' agent='' boss_pane="${TMUX_PANE:-}" boss_pane_explicit=false
while [[ $# -gt 0 ]]; do
  [[ $# -ge 2 && -n "$2" ]] || usage
  case "$1" in
    --session) session=$2; shift 2 ;;
    --branch) branch=$2; shift 2 ;;
    --prompt-file) prompt_file=$2; shift 2 ;;
    --agent) agent=$2; shift 2 ;;
    --boss-pane) boss_pane=$2; boss_pane_explicit=true; shift 2 ;;
    *) usage ;;
  esac
done

[[ -n "$session" && -n "$branch" && -n "$prompt_file" ]] || usage
[[ -r "$prompt_file" ]] || fail "cannot read prompt file $prompt_file"
[[ -n "$boss_pane" ]] || fail "no boss pane. Run the boss in tmux, or pass --boss-pane."
boss_pane=$(tmux display -p -t "$boss_pane" '#{pane_id}' 2>/dev/null) || fail 'boss pane does not exist'
if tmux has-session -t "=$session" 2>/dev/null; then
  fail "tmux session $session already exists"
fi

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$script_dir/worker-cli.sh"
[[ -n "$agent" ]] || agent=$(detect_agent)

case "$agent" in
  claude | cursor | opencode) ;;
  *) fail "unknown agent $agent. Use claude, cursor, or opencode." ;;
esac
[[ "$agent" != opencode || "$boss_pane_explicit" == true ]] || fail 'OpenCode requires an explicit --boss-pane. Tool variables can belong to the shared server.'

git fetch -q origin main
if git show-ref --verify --quiet "refs/heads/$branch"; then
  wt switch "$branch" --no-cd -y >&2
else
  wt switch --create "$branch" --base origin/main --no-cd -y >&2
fi

worktree=$(git worktree list --porcelain |
  awk -v ref="refs/heads/$branch" '/^worktree /{path=substr($0, 10)} $0 == "branch " ref {print path}')
[[ -n "$worktree" ]] || fail "no worktree found for branch $branch"

slot=0
if [[ -f "$worktree/.env.tilt.ports" ]]; then
  slot=$(grep -oP 'for slot \K[0-9]+' "$worktree/.env.tilt.ports" || echo 0)
fi

"$script_dir/start-worker.sh" --session "$session" --worktree "$worktree" \
  --prompt-file "$prompt_file" --boss-pane "$boss_pane" --agent "$agent"

echo "worktree=$worktree"
echo "slot=$slot"
