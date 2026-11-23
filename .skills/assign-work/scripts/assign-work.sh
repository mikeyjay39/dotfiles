#!/usr/bin/env bash
# Usage: assign-work.sh --session <name> --branch <branch> --prompt-file <file>
#                       [--agent claude|cursor] [--boss-pane <pane>]
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

session='' branch='' prompt_file='' agent='' boss_pane="${TMUX_PANE:-}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --session) session=$2; shift 2 ;;
    --branch) branch=$2; shift 2 ;;
    --prompt-file) prompt_file=$2; shift 2 ;;
    --agent) agent=$2; shift 2 ;;
    --boss-pane) boss_pane=$2; shift 2 ;;
    *) usage ;;
  esac
done

[[ -n "$session" && -n "$branch" && -n "$prompt_file" ]] || usage
[[ -r "$prompt_file" ]] || fail "cannot read prompt file $prompt_file"
[[ -n "$boss_pane" ]] || fail "no boss pane. Run the boss in tmux, or pass --boss-pane."
tmux display -p -t "$boss_pane" '#{pane_id}' >/dev/null 2>&1 || fail "boss pane $boss_pane does not exist"
if tmux has-session -t "=$session" 2>/dev/null; then
  fail "tmux session $session already exists"
fi

# The worker uses the same CLI as the boss, so a Cursor boss gets Cursor workers. The nearest
# agent process wins, because a boss can start inside a shell of another agent.
detect_agent() {
  local pid=$$ program
  while [[ "$pid" -gt 1 ]]; do
    # Match only the program name (argv[0]). The full command line of a shell can hold any text.
    program=$(basename -- "$(ps -o args= -p "$pid" | awk '{print $1}')")
    case "$program" in
      claude) echo claude; return ;;
      cursor-agent | agent) echo cursor; return ;;
    esac
    pid=$(ps -o ppid= -p "$pid" | tr -d ' ')
  done
  fail "cannot detect the boss CLI. Pass --agent claude or --agent cursor."
}
[[ -n "$agent" ]] || agent=$(detect_agent)

case "$agent" in
  claude) launch="claude -n $session \"\$(cat $(printf %q "$prompt_file"))\"" ;;
  cursor) launch="cursor-agent \"\$(cat $(printf %q "$prompt_file"))\"" ;;
  *) fail "unknown agent $agent. Use claude or cursor." ;;
esac

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

# The worker prompt runs "$ASSIGN_WORK_REPORT", so it needs no path that is specific to one agent.
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
tmux new-session -d -s "$session" -c "$worktree" \
  -e "ASSIGN_WORK_BOSS_PANE=$boss_pane" \
  -e "ASSIGN_WORK_REPORT=$script_dir/report-to-boss.sh"
# The agent starts from the pane shell, not as the session command, because claude can be a shell alias.
tmux send-keys -t "$session" "$launch" Enter

echo "session=$session"
echo "worktree=$worktree"
echo "slot=$slot"
echo "agent=$agent"
echo "boss_pane=$boss_pane"
