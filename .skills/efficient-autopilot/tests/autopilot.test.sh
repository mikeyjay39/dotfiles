#!/usr/bin/env bash
# Mock-only tests. No model, GitHub call, or worktrunk command runs here. Git is real, with a local
# bare repo as origin, so that pushes and worktrees behave as in a real run.
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
scripts="$root/scripts"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/autopilot-tests.XXXXXX")
[[ -n "${AUTOPILOT_TEST_KEEP:-}" ]] || trap 'rm -rf -- "$tmp"' EXIT
passed=0

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  grep -qF -- "$2" "$1" || fail "$3: '$2' is not in $1"
}

assert_not_contains() {
  ! grep -qF -- "$2" "$1" || fail "$3: '$2' is in $1"
}

ok() {
  passed=$((passed + 1))
  echo "ok - $*"
}

write_mocks() {
  mkdir -p "$tmp/bin"
  cat >"$tmp/bin/claude" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf 'claude' >>"$MOCK_DIR/log"; printf ' <%s>' "$@" >>"$MOCK_DIR/log"; printf '\n' >>"$MOCK_DIR/log"
schema='' resume='' add_dir=''
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json-schema) schema=$2; shift ;;
    --resume) resume=$2; shift ;;
    --add-dir) add_dir=$2; shift ;;
  esac
  shift
done
cat >/dev/null
kind=summary
[[ -z "$schema" ]] || kind=$(jq -r 'if .properties.feature_title then "plan" elif .properties.fixed then "fix"
  elif .properties.evidence then "proof" elif .properties.verdict then "review" else "build" end' <<<"$schema")
count=$(( $(cat "$MOCK_DIR/count.$kind" 2>/dev/null || echo 0) + 1 ))
echo "$count" >"$MOCK_DIR/count.$kind"
session="sess-$kind-$count"
echo "{\"type\":\"system\",\"subtype\":\"init\",\"model\":\"mock\",\"session_id\":\"$session\"}"
if [[ -f "$MOCK_DIR/limit-once" ]]; then
  rm "$MOCK_DIR/limit-once"
  echo '{"type":"rate_limit_event","rate_limit_info":{"status":"rejected","unifiedWindows":{"five_hour":{"utilization":1.0,"resetsAt":0}}}}'
  echo "{\"type\":\"result\",\"subtype\":\"success\",\"is_error\":true,\"result\":\"You've hit your usage limit\",\"session_id\":\"$session\"}"
  exit 1
fi
case "$kind" in
  build | fix)
    if [[ ! -f "$MOCK_DIR/no-commit" ]]; then
      echo "$kind $count" >>"work-$kind.txt"
      touch built
      git add -A && git commit -qm "mock $kind $count"
    fi ;;
  proof)
    [[ -z "$add_dir" ]] || printf 'PNG' >"$add_dir/shot.png" ;;
esac
out="$MOCK_DIR/out/$kind.$count.json"
[[ -f "$out" ]] || out="$MOCK_DIR/out/$kind.json"
structured=null
[[ ! -f "$out" ]] || structured=$(jq -c . "$out")
echo '{"type":"rate_limit_event","rate_limit_info":{"status":"allowed","unifiedWindows":{"five_hour":{"utilization":0.1,"resetsAt":0}}}}'
jq -nc --arg s "$session" --argjson o "$structured" \
  '{type: "result", subtype: "success", is_error: false, result: "ok", session_id: $s, structured_output: $o, total_cost_usd: 0.01, num_turns: 1}'
MOCK
  cat >"$tmp/bin/gh" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf 'gh' >>"$MOCK_DIR/log"; printf ' <%s>' "$@" >>"$MOCK_DIR/log"; printf '\n' >>"$MOCK_DIR/log"
mkdir -p "$MOCK_DIR/prs"
case "$1 $2" in
  "auth status") exit 0 ;;
  "api user") echo tester ;;
  "repo view") echo owner/repo ;;
  "pr view")
    key=${3//\//_}
    [[ -f "$MOCK_DIR/prs/$key" ]] || exit 1
    cat "$MOCK_DIR/prs/$key" ;;
  "pr create")
    head='' base='' body=''
    shift 2
    while [[ $# -gt 0 ]]; do
      case "$1" in --head) head=$2 ;; --base) base=$2 ;; --body-file) body=$2 ;; esac
      shift
    done
    n=$(( $(find "$MOCK_DIR/prs" -type f | wc -l) + 1 ))
    echo "https://github.com/owner/repo/pull/$n" >"$MOCK_DIR/prs/${head//\//_}"
    echo "$base" >"$MOCK_DIR/base.${head//\//_}"
    cp "$body" "$MOCK_DIR/body.$n.md"
    echo "https://github.com/owner/repo/pull/$n" ;;
  "pr edit")
    shift 3
    if [[ "${1:-}" == --body-file ]]; then cp "$2" "$MOCK_DIR/body.edit.$(date +%s%N).md"; fi ;;
  "pr comment")
    shift 3
    n=$(( $(find "$MOCK_DIR" -maxdepth 1 -name 'comment.*.md' | wc -l) + 1 ))
    cp "$2" "$MOCK_DIR/comment.$n.md"
    echo "https://github.com/owner/repo/pull/1#issuecomment-$n" ;;
  *) echo "gh mock: unknown $*" >&2; exit 1 ;;
esac
MOCK
  cat >"$tmp/bin/wt" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf 'wt' >>"$MOCK_DIR/log"; printf ' <%s>' "$@" >>"$MOCK_DIR/log"; printf '\n' >>"$MOCK_DIR/log"
[[ "$1" == switch ]] || exit 1
shift
create=false base='' branch=''
while [[ $# -gt 0 ]]; do
  case "$1" in --create) create=true ;; --base) base=$2; shift ;; --no-cd | -y) ;; *) branch=$1 ;; esac
  shift
done
path="$MOCK_DIR/wt/${branch//\//-}"
if [[ "$create" == true ]]; then git worktree add -q -b "$branch" "$path" "$base"
elif [[ ! -d "$path" ]]; then git worktree add -q "$path" "$branch"; fi
MOCK
  cat >"$tmp/bin/sleep" <<'MOCK'
#!/usr/bin/env bash
echo "sleep $*" >>"$MOCK_DIR/log"
MOCK
  chmod +x "$tmp/bin/"*
}

# Makes a fresh repo with a bare origin, mocks, and a run dir. Sets $MOCK_DIR and $run_dir.
setup_case() {
  local name=$1
  export MOCK_DIR="$tmp/$name"
  mkdir -p "$MOCK_DIR/out" "$MOCK_DIR/wt"
  git init -q --bare -b main "$MOCK_DIR/origin.git"
  git init -q -b main "$MOCK_DIR/repo"
  git -C "$MOCK_DIR/repo" commit -q --allow-empty -m init
  git -C "$MOCK_DIR/repo" remote add origin "$MOCK_DIR/origin.git"
  git -C "$MOCK_DIR/repo" push -q -u origin main
  git -C "$MOCK_DIR/repo" remote set-head origin main
  run_dir="$MOCK_DIR/run"
  mkdir -p "$run_dir"
  echo "$MOCK_DIR/repo" >"$run_dir/repo"
  echo '- #1' >"$run_dir/input.md"
}

decision() {
  jq -nc --arg t "$1" '{title: $t, context: "ctx", decision: "chose A", options_not_taken: [{option: "B", reason: "slower"}],
    trade_offs: "simple, less flexible", reason: "fits", how_to_change: "revert the commit"}'
}

# Writes a plan with stories a and b. b depends on a. Args: verify command of a, proof type of b.
write_plan() {
  jq -n --arg verify_a "$1" --arg proof_b "$2" --argjson d "$(decision 'Split the work in two')" '{
    feature_title: "Mock feature",
    stories: [
      {id: "gh-1", title: "Story A", issue: 1, summary: "Do A", acceptance_criteria: ["A works"], depends_on: [],
       verify_commands: [$verify_a], proof: "none", proof_commands: [], branch: "tester/gh-1-story-a", plan_markdown: "Plan A"},
      {id: "gh-2", title: "Story B", issue: 2, summary: "Do B", acceptance_criteria: ["B works"], depends_on: ["gh-1"],
       verify_commands: ["test -f built"], proof: $proof_b, proof_commands: ["open page"], branch: "tester/gh-2-story-b", plan_markdown: "Plan B"}
    ],
    decisions: [{applies_to: ["gh-1", "gh-2"], record: $d}]}' >"$MOCK_DIR/out/plan.json"
}

write_step_outputs() {
  jq -n --argjson d "$(decision 'Use a cache')" '{summary: "Built it", decisions: [$d]}' >"$MOCK_DIR/out/build.json"
  jq -n '{summary: "Fixed it", fixed: [{problem: "bug", how: "guard"}], decisions: []}' >"$MOCK_DIR/out/fix.json"
  jq -n '{status: "pass", summary: "Page works", evidence: [{acceptance_criterion: "B works", command: "open page", output_excerpt: "200 OK"}],
    screenshots: [{path: "shot.png", caption: "The page"}], not_verified: []}' >"$MOCK_DIR/out/proof.json"
  jq -n '{verdict: "pass", summary: "Good", findings: []}' >"$MOCK_DIR/out/review.json"
}

run_autopilot() {
  (cd "$MOCK_DIR/repo" && bash ${AUTOPILOT_TRACE:+-x} "$scripts/autopilot.sh" "$run_dir") >"$MOCK_DIR/stdout" 2>"$MOCK_DIR/stderr"
}

state_of() {
  jq -r --arg id "$1" ".stories[\$id].$2 // empty" "$run_dir/state.json"
}

write_mocks
export PATH="$tmp/bin:$PATH"
export GIT_CONFIG_GLOBAL="$tmp/gitconfig" GIT_CONFIG_NOSYSTEM=1
git config --global user.name Tester
git config --global user.email tester@example.invalid
git config --global init.defaultBranch main

# ---- 1. Happy path: two stacked stories, UI proof, review fix round, summary last.
setup_case happy
write_plan 'test -f built' ui
write_step_outputs
jq -n '{verdict: "fix", summary: "One bug", findings: [{file: "a.ts", line: 3, severity: "important", summary: "Null crash", failure_scenario: "empty input"}]}' \
  >"$MOCK_DIR/out/review.2.json"
run_autopilot || { cat "$MOCK_DIR/stderr"; fail "happy path exited non-zero"; }
[[ "$(state_of gh-1 status)" == done && "$(state_of gh-2 status)" == done ]] || fail 'both stories are not done'
[[ "$(<"$MOCK_DIR/base.tester_gh-2-story-b")" == tester/gh-1-story-a ]] || fail 'story B is not stacked on story A'
[[ "$(<"$MOCK_DIR/base.tester_gh-1-story-a")" == main ]] || fail 'story A is not based on main'
ok 'two stories build, and the second PR is stacked on the first'

assert_contains "$MOCK_DIR/body.1.md" '## Decisions made without the human' 'PR body'
assert_contains "$MOCK_DIR/body.1.md" 'Decision: Split the work in two' 'PR body'
assert_contains "$MOCK_DIR/body.1.md" 'Decision: Use a cache' 'PR body'
assert_contains "$MOCK_DIR/body.1.md" '- B: slower' 'PR body'
assert_contains "$MOCK_DIR/body.1.md" 'Closes #1' 'PR body'
ok 'the PR body has the full decision records from the plan and the build'

[[ ! -f "$MOCK_DIR/count.proof" || "$(<"$MOCK_DIR/count.proof")" == 1 ]] || fail 'proof ran for a story with proof: none'
git -C "$MOCK_DIR/origin.git" show-ref --verify --quiet "refs/heads/autopilot-proof/run" || fail 'no proof branch on origin'
grep -l 'Proof that the change works' "$MOCK_DIR"/comment.*.md | xargs grep -qF 'gh-2/shot.png?raw=true' || fail 'proof comment has no image link'
ok 'proof: none skips the proof step, and a ui proof pushes the proof branch and links the image'

[[ "$(<"$MOCK_DIR/count.review")" == 2 ]] || fail 'review did not run one time per story'
[[ "$(<"$MOCK_DIR/count.fix")" == 1 ]] || fail 'the review fix verdict did not give exactly one fix round'
grep -l 'Fixes for the automated review' "$MOCK_DIR"/comment.*.md >/dev/null || fail 'no fix reply comment'
grep -l 'Null crash' "$MOCK_DIR"/comment.*.md >/dev/null || fail 'no review findings comment'
ok 'a review fix verdict gets one fix round and a reply comment, with no second review'

summary_line=$(grep -n '^claude' "$MOCK_DIR/log" | tail -1)
[[ "$summary_line" != *--json-schema* && "$summary_line" != *--disable-slash-commands* ]] || fail 'summary step is not last, or skills are off'
grep '^claude' "$MOCK_DIR/log" | grep -v -- '--json-schema' | while read -r line; do
  [[ "$line" != *--disable-slash-commands* ]] || fail 'the summary step disables skills'
done
grep '^claude' "$MOCK_DIR/log" | grep -- '--json-schema' | grep -qv -- '--disable-slash-commands' && fail 'a non-summary step keeps skills on'
grep -q '/pr-summary-for-human https://github.com/owner/repo/pull/2' "$run_dir/prompts/summary-gh-2.md" || fail 'summary prompt has no PR'
ok 'the summary step runs last, with skills on'

grep '^claude' "$MOCK_DIR/log" | grep -- '<--resume> <sess-build' >/dev/null || fail 'fix or proof did not resume the build session'
grep '^claude' "$MOCK_DIR/log" | grep -- '"verdict"' | grep -q -- '--resume' && fail 'review resumed a session'
ok 'fix and proof steps resume the build session, and the review starts fresh'

assert_contains "$run_dir/summary.md" '| `gh-1` | done |' 'summary.md'
"$scripts/progress.sh" "$run_dir" >"$MOCK_DIR/progress"
assert_contains "$MOCK_DIR/progress" 'gh-2' 'progress'
assert_contains "$MOCK_DIR/progress" 'phase: done' 'progress'
ok 'summary.md and progress.sh show each story'

calls_before=$(grep -c '^claude' "$MOCK_DIR/log")
run_autopilot || fail 'second start exited non-zero'
[[ "$(grep -c '^claude' "$MOCK_DIR/log")" == "$calls_before" ]] || fail 'a second start called the model again'
ok 'a second start continues from state.json and repeats no step'

# ---- 2. An invalid plan gets one retry, then a loud stop.
setup_case bad-plan
write_plan 'test -f built' none
jq '.stories[0].depends_on = ["nope"]' "$MOCK_DIR/out/plan.json" >"$MOCK_DIR/out/plan.tmp" && mv "$MOCK_DIR/out/plan.tmp" "$MOCK_DIR/out/plan.json"
if run_autopilot; then fail 'an invalid plan did not stop the run'; fi
[[ "$(<"$MOCK_DIR/count.plan")" == 2 ]] || fail 'an invalid plan did not get exactly one retry'
assert_contains "$run_dir/state.json" 'failed: the plan is still not valid' 'state'
[[ ! -f "$run_dir/plan.json" ]] || fail 'an invalid plan was saved'
ok 'an invalid plan gets one retry, then a loud stop'

# ---- 3. A verify failure gets two fix rounds, then parks the story. Its dependent is skipped.
setup_case park
write_plan 'test -f never' none
write_step_outputs
run_autopilot || { cat "$MOCK_DIR/stderr"; fail 'park case exited non-zero'; }
[[ "$(state_of gh-1 status)" == parked ]] || fail 'story A is not parked'
[[ "$(state_of gh-2 status)" == skipped ]] || fail 'story B is not skipped'
[[ "$(<"$MOCK_DIR/count.fix")" == 2 ]] || fail 'verify failure did not give two fix rounds'
grep -q '<create>.*<\[PARKED\] Story A>' "$MOCK_DIR/log" || fail 'parked story has no [PARKED] PR'
[[ ! -f "$MOCK_DIR/count.review" ]] || fail 'a parked story was reviewed'
ok 'a verify failure gets two fix rounds, then parks the story and skips its dependent'

# ---- 4. A usage-limit result pauses, then resumes the same step.
setup_case limit
write_plan 'test -f built' none
write_step_outputs
jq '.stories |= .[0:1] | .decisions[0].applies_to = ["gh-1"]' "$MOCK_DIR/out/plan.json" >"$MOCK_DIR/out/p.tmp" && mv "$MOCK_DIR/out/p.tmp" "$MOCK_DIR/out/plan.json"
touch "$MOCK_DIR/limit-once"
AUTOPILOT_LIMIT_WAIT_SECONDS=5 run_autopilot || { cat "$MOCK_DIR/stderr"; fail 'limit case exited non-zero'; }
grep -q '^sleep ' "$MOCK_DIR/log" || fail 'no pause after the usage limit'
grep '^claude' "$MOCK_DIR/log" | sed -n 2p | grep -q -- '<--resume> <sess-plan-1>' || fail 'the retry did not resume the stopped session'
[[ -s "$run_dir/usage-pauses.log" ]] || fail 'the pause was not recorded'
[[ "$(state_of gh-1 status)" == done ]] || fail 'the run did not finish after the pause'
ok 'a usage-limit result pauses, then resumes the same session'

# ---- 5. Safety: no path merges or force-pushes.
for log in "$tmp"/*/log; do
  ! grep -E '<merge>|<--force>|<-f>|<--force-with-lease>' "$log" >/dev/null || fail "unsafe command in $log"
done
! grep -nE 'gh pr merge|push[^#]*(--force|-f )' "$scripts"/*.sh || fail 'a script can merge or force-push'
ok 'no path runs gh pr merge or a force push'

# ---- 6. pretty-stream formats events.
printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"npm test"}}]}}' |
  "$scripts/pretty-stream.sh" build-x | grep -qF '[build-x] Bash npm test' || fail 'pretty-stream output'
ok 'pretty-stream prints one short line per tool call'

echo "all $passed tests passed"
