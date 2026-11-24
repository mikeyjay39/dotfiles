#!/usr/bin/env bash
# Mock-only tests. No agent, tmux server, worktree, or API starts here.
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
watch="$root/../control-agent/scripts/watch.sh"
tmp=$(mktemp -d "${TMPDIR:-/tmp/opencode}/worker-tests.XXXXXX")
trap 'rm -r -- "$tmp"' EXIT
mkdir "$tmp/bin" "$tmp/worktree"
export MOCK_DIR=$tmp
export XDG_RUNTIME_DIR=$tmp
export PATH="$tmp/bin:$PATH"
printf 'Implement the test. Literal text: $(touch "%s/NOT_ALLOWED")\n' "$tmp" >"$tmp/prompt"

cat >"$tmp/bin/mock" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
name=${0##*/}
printf '%s' "$name" >>"$MOCK_DIR/log"
printf ' <%s>' "$@" >>"$MOCK_DIR/log"
printf '\n' >>"$MOCK_DIR/log"
case "$name" in
  tmux)
    case "$1" in
      display)
        [[ ${MOCK_NO_BOSS:-0} == 0 ]] || exit 1
        if [[ ${*: -1} == '#S' ]]; then echo wk-test; else echo "${MOCK_TARGET:-%7}"; fi ;;
      has-session) [[ ${MOCK_EXISTS:-1} == 1 ]] ;;
      new-session) [[ ${MOCK_NEW_FAIL:-0} == 0 ]] || exit 1; echo %7 ;;
      show-options)
        case "${*: -1}" in
          @assign_work_pane) printf '%s' "${MOCK_REGISTERED:-}" ;;
          @assign_work_agent) printf '%s' "${MOCK_AGENT:-}" ;;
          @assign_work_opencode_session) printf '%s' "${MOCK_SESSION_ID:-}" ;;
        esac ;;
      list-panes) printf '%s\n' "${MOCK_PANES:-%7 claude 100}" ;;
      capture-pane) [[ ${MOCK_CAPTURE_FAIL:-0} == 0 ]] || exit 1; printf '%s\n' "${MOCK_SCREEN:-Ready}" ;;
      show-environment) echo ASSIGN_WORK_BOSS_PANE=%1 ;;
      send-keys)
        [[ ${MOCK_SEND_FAIL:-0} == 0 ]] || exit 1
        if [[ ${4:-} == -l ]]; then printf '%s' "$5" >"$MOCK_DIR/launch-code"; fi ;;
      set-option) ;;
      *) exit 91 ;;
    esac ;;
  opencode)
    if [[ ${1:-} == api ]]; then
      [[ ${MOCK_API_FAIL:-0} == 0 ]] || exit 1
      if [[ $2 == post ]]; then
        echo "${MOCK_CREATE_RESPONSE:-{\"data\":{\"id\":\"ses_worker\"}}}"
      elif [[ $3 == /api/session/active ]]; then
        count=0
        [[ ! -f "$MOCK_DIR/active-count" ]] || read -r count <"$MOCK_DIR/active-count"
        count=$((count + 1)); echo "$count" >"$MOCK_DIR/active-count"
        if (( count <= ${MOCK_BUSY_POLLS:-0} )); then
          echo '{"data":{"ses_worker":{"type":"running"}}}'
        else
          echo "${MOCK_ACTIVE_RESPONSE:-{\"data\":{\"ses_other\":{\"type\":\"running\"}}}}"
        fi
      else
        echo "${MOCK_INFO_RESPONSE:-{\"data\":{\"id\":\"ses_worker\"}}}"
      fi
    fi ;;
  claude | cursor-agent) ;;
  ps)
    if [[ $2 == ppid= ]]; then
      echo "${MOCK_PARENT:-40}"
    elif [[ ${*: -1} == 40 ]]; then
      echo "${MOCK_ANCESTOR:-bash}"
    elif [[ ${*: -1} == 200 ]]; then
      echo "${MOCK_CHILD:-bash}"
    else
      echo "${MOCK_PROCESS:-bash}"
    fi ;;
  pgrep) [[ ${MOCK_CHILD:-} && ${*: -1} == 100 ]] && echo 200 || exit 1 ;;
  git)
    case "$1" in
      fetch) ;;
      show-ref) exit 1 ;;
      worktree) printf 'worktree %s\nbranch refs/heads/test/worker\n' "$MOCK_DIR/worktree" ;;
      *) exit 92 ;;
    esac ;;
  wt) ;;
  date)
    count=0
    [[ ! -f "$MOCK_DIR/date-count" ]] || read -r count <"$MOCK_DIR/date-count"
    count=$((count + 1)); echo "$count" >"$MOCK_DIR/date-count"; echo "$((count * 100))" ;;
  sleep)
    count=0
    [[ ! -f "$MOCK_DIR/sleep-count" ]] || read -r count <"$MOCK_DIR/sleep-count"
    count=$((count + 1)); echo "$count" >"$MOCK_DIR/sleep-count"
    (( count < 12 )) || exit 93 ;;
esac
MOCK
chmod +x "$tmp/bin/mock"
for cli in tmux opencode claude cursor-agent ps pgrep git wt date sleep; do ln -s mock "$tmp/bin/$cli"; done

checks=0
check() {
  local expected=$1 label=$2 status=0
  shift 2
  : >"$tmp/log"
  rm -f "$tmp/active-count" "$tmp/date-count" "$tmp/sleep-count"
  "$@" >"$tmp/out" 2>"$tmp/err" || status=$?
  if [[ $status != "$expected" ]]; then
    echo "FAIL: $label (expected $expected, got $status)" >&2
    cat "$tmp/out" "$tmp/err" >&2
    exit 1
  fi
  checks=$((checks + 1))
  echo "ok $checks - $label"
}
contains() { grep -Fq -- "$2" "$1" || { echo "Missing: $2 in $1" >&2; cat "$1" >&2; exit 1; }; }
absent() { if grep -Fq -- "$2" "$1"; then echo "Unexpected: $2 in $1" >&2; exit 1; fi; }

for cli in claude cursor opencode; do
  check 0 "$cli launch" env MOCK_EXISTS=0 "$root/scripts/start-worker.sh" --agent "$cli" \
    --session wk-test --worktree "$tmp/worktree" --prompt-file "$tmp/prompt" --boss-pane %1
  contains "$tmp/log" '<@assign_work_pane> <%7>'
  contains "$tmp/log" '<@assign_work_agent>'
  contains "$tmp/log" '<set-option> <-t> <=wk-test:> <@assign_work_pane>'
  contains "$tmp/log" '<send-keys> <-t> <%7> <-l> <bash '
  absent "$tmp/log" '--auto'
  absent "$tmp/log" '--yolo'
  if [[ $cli == opencode ]]; then
    contains "$tmp/log" '"location": {"directory":'
    contains "$tmp/out" 'opencode_session=ses_worker'
  fi
  launch=$(cat "$tmp/launch-code")
  check 0 "$cli launch preserves literal prompt arguments" bash -c "$launch"
  contains "$tmp/log" 'Literal text: $(touch'
  contains "$tmp/log" 'report-to-boss.sh'
  contains "$tmp/log" '--session wk-test --boss-pane %1'
  [[ ! -e "$tmp/NOT_ALLOWED" ]] || { echo 'Prompt text executed as shell code' >&2; exit 1; }
  case "$cli" in
    claude) contains "$tmp/log" 'claude <-n> <wk-test>' ;;
    cursor) contains "$tmp/log" 'cursor-agent <Implement the test.' ;;
    opencode) contains "$tmp/log" 'opencode <--session> <ses_worker> <--prompt>'; contains "$tmp/log" "<$tmp/worktree>" ;;
  esac
done
for program in claude cursor-agent agent opencode; do
  expected=$program
  [[ $program != cursor-agent && $program != agent ]] || expected=cursor
  check 0 "detect $program ancestor" env MOCK_ANCESTOR="$program" bash -c 'source "$1"; detect_agent' _ "$root/scripts/worker-cli.sh"
  contains "$tmp/out" "$expected"
done
check 0 'nearest CLI wins' env MOCK_PROCESS=cursor-agent MOCK_ANCESTOR=claude bash -c 'source "$1"; detect_agent' _ "$root/scripts/worker-cli.sh"
contains "$tmp/out" cursor
check 1 'shared server cannot identify client' env MOCK_PARENT=1 bash -c 'source "$1"; detect_agent' _ "$root/scripts/worker-cli.sh"
check 1 'do not detect CLI names in shell arguments' env MOCK_PROCESS='bash -c opencode' MOCK_PARENT=1 bash -c 'source "$1"; detect_agent' _ "$root/scripts/worker-cli.sh"

start=("$root/scripts/start-worker.sh" --session wk-test --worktree "$tmp/worktree" --prompt-file "$tmp/prompt" --boss-pane %1)
check 1 'reject duplicate session' "${start[@]}" --agent opencode
check 1 'reject unknown CLI' env MOCK_EXISTS=0 "${start[@]}" --agent other
check 1 'reject missing option value' "${start[@]}" --agent
check 1 'reject missing boss pane' env MOCK_EXISTS=0 MOCK_NO_BOSS=1 "${start[@]}" --agent claude
check 1 'reject OpenCode API failure' env MOCK_EXISTS=0 MOCK_API_FAIL=1 "${start[@]}" --agent opencode
absent "$tmp/log" '<new-session>'
check 1 'reject invalid session response' env MOCK_EXISTS=0 MOCK_CREATE_RESPONSE='{"data":{"id":"wrong"}}' "${start[@]}" --agent opencode
absent "$tmp/log" '<new-session>'
check 1 'surface tmux launch failure' env MOCK_EXISTS=0 MOCK_NEW_FAIL=1 "${start[@]}" --agent cursor
check 1 'surface send failure' env MOCK_EXISTS=0 MOCK_SEND_FAIL=1 "${start[@]}" --agent claude
check 2 'assign rejects missing option value' "$root/scripts/assign-work.sh" --session
check 1 'OpenCode assign rejects inherited boss target' env MOCK_EXISTS=0 TMUX_PANE=%99 "$root/scripts/assign-work.sh" --session wk-test --branch test/worker --prompt-file "$tmp/prompt" --agent opencode
absent "$tmp/log" 'git <fetch>'
check 0 'assign retains origin/main base' env MOCK_EXISTS=0 "$root/scripts/assign-work.sh" --session wk-test --branch test/worker --prompt-file "$tmp/prompt" --agent opencode --boss-pane %1
contains "$tmp/log" 'wt <switch> <--create> <test/worker> <--base> <origin/main>'

for program in claude cursor-agent opencode; do
  check 0 "route to $program, not active shell" env MOCK_PANES=$'%8 bash 101\n%7 '"$program 100" "$root/scripts/send-to-worker.sh" wk-test 'Do not merge.'
  contains "$tmp/log" '<send-keys> <-t> <%7> <-l> <From the control session: Do not merge.>'
  contains "$tmp/log" '<send-keys> <-t> <%7> <Enter>'
  absent "$tmp/log" '<send-keys> <-t> <%8>'
done
long_prompt=$tmp/long-prompt
{ for _ in $(seq 120); do printf 'Line of a long worker prompt with enough text.\n'; done; printf 'END-OF-LONG-PROMPT\n'; } >"$long_prompt"
(( $(wc -c <"$long_prompt") > 4096 )) || { echo 'Long prompt fixture is too short' >&2; exit 1; }
check 0 'long prompt launch' env MOCK_EXISTS=0 "$root/scripts/start-worker.sh" --agent claude \
  --session wk-test --worktree "$tmp/worktree" --prompt-file "$long_prompt" --boss-pane %1
launch=$(cat "$tmp/launch-code")
(( ${#launch} < 512 )) || { echo "Typed launch line is ${#launch} bytes; a canonical tty drops input past 4095" >&2; exit 1; }
check 0 'long prompt reaches the CLI complete' bash -c "$launch"
contains "$tmp/log" 'END-OF-LONG-PROMPT'
contains "$tmp/log" '--session wk-test --boss-pane %1'
check 0 'registered OpenCode pane excludes unrelated OpenCode pane' env MOCK_REGISTERED=%7 MOCK_PANES=$'%8 opencode 101\n%7 opencode 100' "$root/scripts/send-to-worker.sh" wk-test 'Continue.'
absent "$tmp/log" '<send-keys> <-t> <%8>'
contains "$tmp/log" '<show-options> <-qv> <-t> <=wk-test:> <@assign_work_pane>'
check 1 'unregistered multiple agents are ambiguous' env MOCK_PANES=$'%8 claude 101\n%7 opencode 100' "$root/scripts/send-to-worker.sh" wk-test 'Continue.'
absent "$tmp/log" '<send-keys>'
check 1 'stale registration must not redirect' env MOCK_REGISTERED=%9 MOCK_PANES='%7 opencode 100' "$root/scripts/send-to-worker.sh" wk-test 'Continue.'
absent "$tmp/log" '<send-keys>'
check 1 'worker shell is not an agent' env MOCK_PANES='%7 bash 100' "$root/scripts/send-to-worker.sh" wk-test 'Continue.'
check 0 'find OpenCode below a wrapper' env MOCK_PANES='%7 node 100' MOCK_CHILD=/bin/opencode "$root/scripts/send-to-worker.sh" wk-test 'Continue.'
check 1 'do not match command text' env MOCK_PANES='%7 bash 100' MOCK_PROCESS='bash -c opencode' "$root/scripts/send-to-worker.sh" wk-test 'Continue.'
check 1 'missing session' env MOCK_EXISTS=0 "$root/scripts/send-to-worker.sh" wk-test 'Continue.'
check 0 'pin both text and Enter to resolved explicit pane' env MOCK_TARGET=%9 "$root/scripts/send-to-pane.sh" '=wk-test' 'Continue.'
contains "$tmp/log" '<send-keys> <-t> <%9> <-l>'
contains "$tmp/log" '<send-keys> <-t> <%9> <Enter>'
check 1 'explicit missing pane does not submit' env MOCK_NO_BOSS=1 "$root/scripts/send-to-pane.sh" %9 'Continue.'
absent "$tmp/log" '<send-keys>'
check 1 'invalid resolved pane does not submit' env MOCK_TARGET=invalid "$root/scripts/send-to-pane.sh" %9 'Continue.'
absent "$tmp/log" '<send-keys>'
check 0 'report uses explicit identity despite wrong tool environment' env TMUX_PANE=%99 ASSIGN_WORK_BOSS_PANE=%98 MOCK_TARGET=%1 "$root/scripts/report-to-boss.sh" --session wk-test --boss-pane %1 'done: Tests pass.'
contains "$tmp/log" '<send-keys> <-t> <%1> <-l> <From worker wk-test: done: Tests pass.>'
absent "$tmp/log" '%99'
check 0 'report works without tmux environment' env -u TMUX_PANE MOCK_TARGET=%1 "$root/scripts/report-to-boss.sh" --session wk-test --boss-pane %1 'started: Test.'
check 2 'report rejects invalid explicit identity' "$root/scripts/report-to-boss.sh" --session wk-test --boss-pane not-a-pane 'done: Test.'
check 0 'legacy report still works' env TMUX_PANE=%7 MOCK_TARGET=%1 "$root/scripts/report-to-boss.sh" 'done: Test.'
contains "$tmp/log" '<From worker wk-test: done: Test.>'

check 1 'OpenCode running status' env MOCK_BUSY_POLLS=1 "$root/scripts/opencode-idle.sh" ses_worker
check 0 'other running session does not make worker busy' "$root/scripts/opencode-idle.sh" ses_worker
check 2 'OpenCode status API failure' env MOCK_API_FAIL=1 "$root/scripts/opencode-idle.sh" ses_worker
check 2 'OpenCode status malformed response' env MOCK_ACTIVE_RESPONSE='not JSON' "$root/scripts/opencode-idle.sh" ses_worker
check 2 'OpenCode identity mismatch' env MOCK_INFO_RESPONSE='{"data":{"id":"ses_other"}}' "$root/scripts/opencode-idle.sh" ses_worker
check 2 'OpenCode malformed active record' env MOCK_ACTIVE_RESPONSE='{"data":{"ses_worker":{}}}' "$root/scripts/opencode-idle.sh" ses_worker

for program in claude cursor-agent opencode; do
  check 0 "$program idle watcher" env MOCK_PANES="%7 $program 100" MOCK_AGENT="$program" MOCK_SESSION_ID=ses_worker IDLE_SECONDS=1 POLL_SECONDS=0 "$watch" wk-test
  contains "$tmp/out" 'IDLE: wk-test'
done
check 0 'static OpenCode screen stays busy until API is idle' env MOCK_PANES='%7 opencode 100' MOCK_AGENT=opencode MOCK_SESSION_ID=ses_worker MOCK_BUSY_POLLS=3 IDLE_SECONDS=1 POLL_SECONDS=0 "$watch" wk-test
contains "$tmp/out" 'IDLE: wk-test'
[[ $(cat "$tmp/active-count") == 5 ]] || { echo 'OpenCode reported idle too soon' >&2; exit 1; }
check 0 'idle OpenCode API overrides static busy words' env MOCK_PANES='%7 opencode 100' MOCK_AGENT=opencode MOCK_SESSION_ID=ses_worker MOCK_SCREEN='Finished: Thinking about the task is complete. Running tool and Generating are old output.' IDLE_SECONDS=1 POLL_SECONDS=0 "$watch" wk-test
contains "$tmp/out" 'IDLE: wk-test'
check 2 'watcher API failure is unknown, not idle' env MOCK_PANES='%7 opencode 100' MOCK_AGENT=opencode MOCK_SESSION_ID=ses_worker MOCK_API_FAIL=1 "$watch" wk-test
contains "$tmp/out" 'UNKNOWN: wk-test'
absent "$tmp/out" 'IDLE:'
check 2 'legacy wrapped OpenCode without session ID is unknown' env MOCK_PANES='%7 node 100' MOCK_CHILD=opencode "$watch" wk-test
contains "$tmp/out" 'UNKNOWN: wk-test'
check 1 'watcher gone session' env MOCK_EXISTS=0 "$watch" wk-test
contains "$tmp/out" 'GONE: wk-test'
check 2 'watcher stale pane is unknown' env MOCK_REGISTERED=%9 "$watch" wk-test
check 2 'watcher capture failure is unknown' env MOCK_CAPTURE_FAIL=1 "$watch" wk-test
check 93 'Claude elapsed spinner remains busy' env MOCK_SCREEN='… (12s' IDLE_SECONDS=1 POLL_SECONDS=0 "$watch" wk-test
absent "$tmp/out" 'IDLE:'
check 93 'Cursor tool output remains busy' env MOCK_PANES='%7 cursor-agent 100' MOCK_SCREEN='Running tool' IDLE_SECONDS=1 POLL_SECONDS=0 "$watch" wk-test
absent "$tmp/out" 'IDLE:'
echo "PASS: $checks mock worker tests"
