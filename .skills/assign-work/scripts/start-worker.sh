#!/usr/bin/env bash
# Usage: start-worker.sh --session <name> --worktree <path> --prompt-file <file>
#                        --boss-pane <pane-id> [--agent claude|cursor|opencode] [--model <model>]
# Boss     -> Launcher: worker name, worktree, CLI, model, boss pane, prompt
# Launcher -> OpenCode API: create session at explicit location (OpenCode only)
# Launcher -> tmux: create pane; register pane, CLI, and Claude or OpenCode session ID
# Launcher -> Worker CLI: prompt with explicit report command
# Worker   -> Boss pane: report with explicit worker name
set -euo pipefail
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$script_dir/worker-cli.sh"
fail() { echo "start-worker: $*" >&2; exit 1; }
session='' worktree='' prompt_file='' boss_pane='' agent='' model=''
while (( $# )); do
  [[ $# -ge 2 && -n "$2" ]] || fail "missing value for $1"
  case "$1" in
    --session) session=$2 ;;
    --worktree) worktree=$2 ;;
    --prompt-file) prompt_file=$2 ;;
    --boss-pane) boss_pane=$2 ;;
    --agent) agent=$2 ;;
    --model) model=$2 ;;
    *) fail "unknown option $1" ;;
  esac
  shift 2
done
[[ "$session" =~ ^[a-zA-Z0-9_-]+$ ]] || fail 'invalid or missing session name'
[[ -d "$worktree" && -r "$prompt_file" ]] || fail 'worktree or prompt file is not readable'
[[ "$boss_pane" =~ ^%[0-9]+$ ]] || fail 'pass an explicit boss pane ID, such as %1'
tmux display -p -t "$boss_pane" '#{pane_id}' >/dev/null || fail 'boss pane does not exist'
if tmux has-session -t "=$session" 2>/dev/null; then fail "session $session already exists"; fi
[[ -n "$agent" ]] || agent=$(detect_agent)
case "$agent" in
  claude) cli=claude; command -v uuidgen >/dev/null || fail 'uuidgen is required for the Claude session ID' ;;
  cursor) cli=cursor-agent ;;
  opencode) cli=opencode; command -v python3 >/dev/null || fail 'python3 is required for OpenCode JSON' ;;
  *) fail "unknown agent $agent" ;;
esac
command -v "$cli" >/dev/null || fail "$cli is not installed"
# The OpenCode V2 TUI has no model option. Its model comes from the OpenCode configuration.
[[ -z "$model" || "$agent" != opencode ]] || fail 'OpenCode has no --model option. Select the model in the OpenCode configuration.'
model_args=()
[[ -z "$model" ]] || model_args=(--model "$model")
worktree=$(cd "$worktree" && pwd)
report_command=$(printf '%q ' "$script_dir/report-to-boss.sh" --session "$session" --boss-pane "$boss_pane")
prompt=$(cat "$prompt_file")
prompt+=$'\n\nWorker report identity (use this command, not inherited environment):\n'
prompt+="${report_command}\"<kind>: <text>\""
prompt+=$'\nSend started, question, blocked, pr, and done reports. Do not infer identity from TMUX_PANE or per-worker variables.'
opencode_session='' claude_session=''
case "$agent" in
  claude)
    # A known session ID lets last-turn.sh read the transcript, not the pane.
    claude_session=$(uuidgen | tr '[:upper:]' '[:lower:]')
    printf -v launch '%q ' claude -n "$session" --session-id "$claude_session" "${model_args[@]}" "$prompt"
    ;;
  cursor) printf -v launch '%q ' cursor-agent "${model_args[@]}" "$prompt" ;;
  opencode)
    # Create at an explicit location: the shared server can have a different working directory.
    body=$(python3 -c 'import json,sys; print(json.dumps({"title":sys.argv[1],"location":{"directory":sys.argv[2]}}))' "$session" "$worktree")
    response=$(opencode api post /api/session --data "$body") || fail 'OpenCode session creation failed'
    opencode_session=$(python3 -c 'import json,re,sys; s=json.load(sys.stdin)["data"]["id"]; assert re.fullmatch(r"ses[a-zA-Z0-9_-]+",s); print(s)' <<<"$response") || fail 'invalid OpenCode session response'
    printf -v launch 'opencode --session %q --prompt %q %q' "$opencode_session" "$prompt" "$worktree"
    ;;
esac
pane=$(tmux new-session -d -P -F '#{pane_id}' -s "$session" -c "$worktree" \
  -e "ASSIGN_WORK_BOSS_PANE=$boss_pane" -e "ASSIGN_WORK_REPORT=$script_dir/report-to-boss.sh")
[[ "$pane" =~ ^%[0-9]+$ ]] || fail 'tmux did not return a pane ID'
# The trailing colon makes the target an exact session match. tmux 3.8 option commands
# reject a bare "=name" target ("no such session").
tmux set-option -t "=$session:" @assign_work_pane "$pane"
tmux set-option -t "=$session:" @assign_work_agent "$agent"
tmux set-option -t "=$session:" @assign_work_opencode_session "$opencode_session"
tmux set-option -t "=$session:" @assign_work_claude_session "$claude_session"
# Type only a short command. A new shell can still be in canonical tty mode, which drops
# typed input past 4095 bytes on one line, so a long prompt would arrive cut off.
launch_file=$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/assign-work-launch-$session.XXXXXX") ||
  fail 'cannot create the launch file'
printf 'rm -f -- "$0"\n%s\n' "$launch" >"$launch_file"
"$script_dir/send-to-pane.sh" "$pane" "$(printf 'bash %q' "$launch_file")"
printf 'session=%s\npane=%s\nagent=%s\nboss_pane=%s\nopencode_session=%s\nclaude_session=%s\n' \
  "$session" "$pane" "$agent" "$boss_pane" "$opencode_session" "$claude_session"
