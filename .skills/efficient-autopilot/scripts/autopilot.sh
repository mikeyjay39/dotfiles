#!/usr/bin/env bash
# Usage: autopilot.sh <run-dir>
# Runs an efficient-autopilot run with no human. Opus plans the stories and reviews each PR.
# Sonnet builds, fixes, proves, and summarizes. This script runs the checks, keeps the state, pushes,
# and writes the PR text, so no model session stays open between steps. Start it again with the same
# run dir to continue after a stop: each story continues after its last completed step.
set -euo pipefail
shopt -s inherit_errexit

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
skill_dir=$(dirname "$script_dir")
run_dir=$(cd "${1:?usage: autopilot.sh <run-dir>}" && pwd)
repo=$(<"$run_dir/repo")
plan="$run_dir/plan.json"
state="$run_dir/state.json"
plan_model=${AUTOPILOT_PLAN_MODEL:-opus}
build_model=${AUTOPILOT_BUILD_MODEL:-sonnet}
verify_timeout=${AUTOPILOT_VERIFY_TIMEOUT:-1800}
max_fix_rounds=2
max_proof_attempts=2
steps=(worktree build verify publish proof review summary)
read_only_git='Bash(git diff:*),Bash(git log:*),Bash(git show:*),Bash(git status:*),Bash(git branch:*)'

log() {
  echo "[autopilot $(date +%H:%M)] $*" >&2
}

fail() {
  log "ERROR: $*"
  [[ ! -r "$state" ]] || state_top phase "\"failed: $*\""
  exit 1
}

# ---------------------------------------------------------------- state

state_top() {
  local key=$1 value=$2
  jq --arg k "$key" --argjson v "$value" '.[$k] = $v' "$state" >"$state.tmp"
  mv "$state.tmp" "$state"
}

state_set() {
  local id=$1 key=$2 value=$3
  jq --arg id "$id" --arg k "$key" --argjson v "$value" '.stories[$id][$k] = $v' "$state" >"$state.tmp"
  mv "$state.tmp" "$state"
}

json_string() {
  jq -Rn --arg s "$1" '$s'
}

state_get() {
  jq -r --arg id "$1" --arg k "$2" '.stories[$id][$k] // empty' "$state"
}

story_field() {
  jq -r --arg id "$1" ".stories[] | select(.id == \$id) | $2" "$plan"
}

story_ids() {
  jq -r '.stories[].id' "$plan"
}

step_index() {
  local name=$1 i
  for i in "${!steps[@]}"; do
    [[ "${steps[$i]}" != "$name" ]] || { echo "$i"; return; }
  done
  echo -1
}

# ---------------------------------------------------------------- prompts and model calls

# Writes a prompt from a template. Each KEY=value argument replaces {{KEY}}.
render_prompt() {
  local template=$1 out=$2 text pair key
  shift 2
  text=$(<"$skill_dir/references/$template.md")
  text=${text//'{{HARD_LIMITS}}'/$(<"$skill_dir/references/hard-limits.md")}
  text=${text//'{{DECISION_RULES}}'/$(<"$skill_dir/references/decisions.md")}
  for pair in "$@"; do
    key=${pair%%=*}
    text=${text//"{{$key}}"/${pair#*=}}
  done
  printf '%s\n' "$text" >"$out"
}

# Puts the shared decision schema into a step schema, because `--json-schema` takes one document.
schema_file() {
  local name=$1 out="$run_dir/schemas/$1.json"
  if [[ ! -r "$out" ]]; then
    mkdir -p "$run_dir/schemas"
    jq --slurpfile decision "$skill_dir/schemas/decision.json" \
      'walk(if . == "$decision" then $decision[0] else . end)' "$skill_dir/schemas/$name.json" >"$out"
  fi
  echo "$out"
}

# Runs one model step. The result event goes to <run-dir>/results/<label>.json.
call_step() {
  local label=$1
  shift
  mkdir -p "$run_dir/results"
  "$script_dir/claude-step.sh" --run-dir "$run_dir" --label "$label" "$@" >"$run_dir/results/$label.json"
}

result_of() {
  jq -c '.structured_output' "$run_dir/results/$1.json"
}

bullets() {
  story_field "$1" "$2 | map(\"- \" + .) | join(\"\\n\")"
}

decision_titles() {
  local titles
  titles=$(cat "$run_dir"/decisions/*.json 2>/dev/null | jq -rs 'add // [] | unique_by(.title) | map("- " + .title) | join("\n")')
  echo "${titles:-None.}"
}

add_decisions() {
  local id=$1 records=$2 file="$run_dir/decisions/$1.json"
  mkdir -p "$run_dir/decisions"
  [[ -r "$file" ]] || echo '[]' >"$file"
  jq --argjson new "$records" '. + $new' "$file" >"$file.tmp"
  mv "$file.tmp" "$file"
}

# ---------------------------------------------------------------- git and GitHub

default_branch() {
  local ref
  ref=$(git -C "$repo" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null) || ref=origin/main
  echo "${ref#origin/}"
}

branch_handle() {
  local handle
  handle=$(git -C "$repo" branch --list '*/tkt-*' '*/gh-*' --format='%(refname:short)' | head -1 | cut -d/ -f1)
  [[ -n "$handle" ]] || handle=$(gh api user -q .login)
  echo "$handle"
}

# The stack is linear: a story is based on the last story before it that is done.
base_branch_for() {
  local id=$1 other base
  base=$(default_branch)
  for other in $(story_ids); do
    [[ "$other" != "$id" ]] || break
    [[ "$(state_get "$other" status)" != done ]] || base=$(story_field "$other" .branch)
  done
  echo "$base"
}

base_ref_for() {
  local base
  base=$(state_get "$1" base_branch)
  if [[ "$base" == "$(default_branch)" ]]; then echo "origin/$base"; else echo "$base"; fi
}

worktree_of() {
  state_get "$1" worktree
}

push_story() {
  git -C "$(worktree_of "$1")" push -q -u origin "$(story_field "$1" .branch)" || fail "git push failed for $1"
}

# A builder can leave work uncommitted. Commit it, so that verify, review, and the PR see it.
commit_leftovers() {
  local worktree
  worktree=$(worktree_of "$1")
  [[ -n "$(git -C "$worktree" status --porcelain)" ]] || return 0
  log "$1: commit the changes that the builder left uncommitted"
  git -C "$worktree" add -A
  git -C "$worktree" commit -q -m "Commit changes that the autopilot builder left uncommitted"
}

update_pr_body() {
  local id=$1 body="$run_dir/results/pr-body-$1.md"
  "$script_dir/render.sh" pr-body "$run_dir" "$id" >"$body"
  gh pr edit "$(state_get "$id" pr_url)" --body-file "$body" >/dev/null
}

pr_comment() {
  local id=$1 file=$2
  gh pr comment "$(state_get "$id" pr_url)" --body-file "$file" | tail -1
}

# Stores screenshots on an orphan branch, because `gh` cannot attach images to a comment.
# Prints the base URL of the story's folder on that branch.
publish_screenshots() {
  local id=$1 proof_dir=$2 proof_json=$3 ref="refs/heads/autopilot-proof/$(basename "$run_dir")"
  local entries='' path sha story_tree top_tree parent commit nwo
  while IFS= read -r path; do
    [[ -f "$proof_dir/$path" ]] || { log "$id: no screenshot file $path"; continue; }
    sha=$(git -C "$repo" hash-object -w "$proof_dir/$path")
    entries+=$(printf '100644 blob %s\t%s' "$sha" "$path")$'\n'
  done < <(jq -r '.screenshots[].path' "$proof_json")
  [[ -n "$entries" ]] || return 1
  story_tree=$(printf '%s' "$entries" | git -C "$repo" mktree)
  parent=$(git -C "$repo" rev-parse -q --verify "$ref" || true)
  top_tree=$({
    [[ -z "$parent" ]] || git -C "$repo" ls-tree "$parent" | awk -F'\t' -v id="$id" '$2 != id'
    printf '040000 tree %s\t%s\n' "$story_tree" "$id"
  } | git -C "$repo" mktree)
  commit=$(git -C "$repo" commit-tree "$top_tree" ${parent:+-p "$parent"} -m "Proof screenshots for $id")
  git -C "$repo" update-ref "$ref" "$commit"
  git -C "$repo" push -q origin "$ref:$ref" || fail "cannot push the proof screenshots of $id"
  nwo=$(gh repo view --json nameWithOwner -q .nameWithOwner)
  echo "https://github.com/$nwo/blob/$commit/$id"
}

# ---------------------------------------------------------------- park

park() {
  local id=$1 reason=$2 title url note_file="$run_dir/results/park-$1.md"
  log "$id: PARKED: $reason"
  state_set "$id" status '"parked"'
  state_set "$id" note "$(json_string "$reason")"
  title="[PARKED] $(story_field "$id" .title)"
  if [[ -z "$(state_get "$id" pr_url)" ]]; then
    # GitHub refuses a PR with no commits. The note in summary.md is then the only record.
    [[ "$(git -C "$(worktree_of "$id")" rev-list --count "$(base_ref_for "$id")..HEAD")" != 0 ]] || return 0
    push_story "$id"
    "$script_dir/render.sh" pr-body "$run_dir" "$id" >"$note_file"
    url=$(gh pr create --draft --base "$(state_get "$id" base_branch)" \
      --head "$(story_field "$id" .branch)" --title "$title" --body-file "$note_file" | tail -1)
    state_set "$id" pr_url "$(json_string "$url")"
    return
  fi
  gh pr edit "$(state_get "$id" pr_url)" --title "$title" >/dev/null
  update_pr_body "$id"
  {
    echo "## Parked by the autopilot"
    echo
    echo "$reason"
    if [[ -r "$run_dir/verify/$id.log" ]]; then
      printf '\nLast verify output:\n\n```console\n%s\n```\n' "$(tail -n 60 "$run_dir/verify/$id.log")"
    fi
  } >"$note_file"
  pr_comment "$id" "$note_file" >/dev/null
}

is_parked() {
  [[ "$(state_get "$1" status)" == parked ]]
}

# ---------------------------------------------------------------- verify and fix

# Runs the verify commands. Records each exit code. Returns 1 when a command fails.
run_verify() {
  local id=$1 worktree out="$run_dir/verify/$1.log" results='[]' command code failed=0
  worktree=$(worktree_of "$id")
  mkdir -p "$run_dir/verify"
  : >"$out"
  while IFS= read -r command; do
    log "$id: verify: $command"
    echo "\$ $command" >>"$out"
    if (cd "$worktree" && timeout "$verify_timeout" bash -c "$command") >>"$out" 2>&1 </dev/null; then
      code=0
    else
      code=$?
      failed=1
    fi
    results=$(jq -c --arg c "$command" --argjson e "$code" '. + [{command: $c, exit: $e}]' <<<"$results")
  done < <(story_field "$id" '.verify_commands[]')
  state_set "$id" verify "$results"
  return "$failed"
}

fix_round() {
  local id=$1 problems=$2 round label prompt
  round=$(state_get "$id" fix_rounds)
  round=$((${round:-0} + 1))
  state_set "$id" fix_rounds "$round"
  label="fix-$id-$round"
  prompt="$run_dir/prompts/$label.md"
  render_prompt fix "$prompt" "STORY_ID=$id" "PROBLEMS=$problems"
  call_step "$label" --model "$build_model" --cwd "$(worktree_of "$id")" --prompt-file "$prompt" \
    --tools 'Read,Edit,Write,Glob,Grep,Bash' --allow 'Read,Glob,Grep,Bash' \
    --schema "$(schema_file fix)" --resume "$(state_get "$id" session_id)"
  state_set "$id" session_id "$(jq -c '.session_id' "$run_dir/results/$label.json")"
  state_set "$id" last_fix "\"$label\""
  add_decisions "$id" "$(result_of "$label" | jq -c '.decisions')"
  commit_leftovers "$id"
}

# Verifies, and gives the builder up to two fix rounds. Parks the story when it still fails.
verify_with_fixes() {
  local id=$1 round
  for ((round = 0; ; round++)); do
    run_verify "$id" && return 0
    ((round < max_fix_rounds)) || break
    fix_round "$id" "The verify commands failed. The last lines of their output:
\`\`\`
$(tail -n 80 "$run_dir/verify/$id.log")
\`\`\`"
  done
  park "$id" "The verify commands still fail after $max_fix_rounds fix rounds."
}

# ---------------------------------------------------------------- story steps

step_worktree() {
  local id=$1 branch base worktree
  branch=$(story_field "$id" .branch)
  base=$(state_get "$id" base_branch)
  [[ -n "$base" ]] || { base=$(base_branch_for "$id"); state_set "$id" base_branch "\"$base\""; }
  git -C "$repo" fetch -q origin
  if git -C "$repo" show-ref --verify --quiet "refs/heads/$branch"; then
    (cd "$repo" && wt switch "$branch" --no-cd -y) >&2
  else
    (cd "$repo" && wt switch --create "$branch" --base "$(base_ref_for "$id")" --no-cd -y) >&2
  fi
  worktree=$(git -C "$repo" worktree list --porcelain |
    awk -v ref="refs/heads/$branch" '/^worktree /{path=substr($0, 10)} $0 == "branch " ref {print path}')
  [[ -n "$worktree" ]] || fail "no worktree for branch $branch"
  state_set "$id" worktree "$(json_string "$worktree")"
}

step_build() {
  local id=$1 prompt="$run_dir/prompts/build-$1.md" worktree
  worktree=$(worktree_of "$id")
  render_prompt build "$prompt" "STORY_ID=$id" "STORY_TITLE=$(story_field "$id" .title)" \
    "WORKTREE=$worktree" "BRANCH=$(story_field "$id" .branch)" "BASE=$(state_get "$id" base_branch)" \
    "AC=$(bullets "$id" .acceptance_criteria)" "DECISION_TITLES=$(decision_titles)" \
    "PLAN=$(story_field "$id" .plan_markdown)" "VERIFY_COMMANDS=$(bullets "$id" .verify_commands)"
  call_step "build-$id" --model "$build_model" --cwd "$worktree" --prompt-file "$prompt" \
    --tools 'Read,Edit,Write,Glob,Grep,Bash' --allow 'Read,Glob,Grep,Bash' --schema "$(schema_file build)"
  state_set "$id" session_id "$(jq -c '.session_id' "$run_dir/results/build-$id.json")"
  state_set "$id" build_summary "$(result_of "build-$id" | jq -c '.summary')"
  add_decisions "$id" "$(result_of "build-$id" | jq -c '.decisions')"
  commit_leftovers "$id"
  if [[ "$(git -C "$worktree" rev-list --count "$(base_ref_for "$id")..HEAD")" == 0 ]]; then
    park "$id" "The builder made no commits."
  fi
}

step_verify() {
  verify_with_fixes "$1"
}

step_publish() {
  local id=$1 url body="$run_dir/results/pr-body-$1.md"
  push_story "$id"
  url=$(gh pr view "$(story_field "$id" .branch)" --json url -q .url 2>/dev/null || true)
  if [[ -z "$url" ]]; then
    "$script_dir/render.sh" pr-body "$run_dir" "$id" >"$body"
    url=$(gh pr create --draft --base "$(state_get "$id" base_branch)" --head "$(story_field "$id" .branch)" \
      --title "$(story_field "$id" .title)" --body-file "$body" | tail -1)
  fi
  state_set "$id" pr_url "$(json_string "$url")"
  log "$id: PR $url"
}

step_proof() {
  local id=$1 attempt label prompt proof_dir="$run_dir/proof/$1" worktree proof_json comment url base_url=''
  [[ "$(story_field "$id" .proof)" != none ]] || return 0
  worktree=$(worktree_of "$id")
  mkdir -p "$proof_dir"
  for ((attempt = 1; attempt <= max_proof_attempts; attempt++)); do
    label="proof-$id-$attempt"
    prompt="$run_dir/prompts/$label.md"
    render_prompt proof "$prompt" "STORY_ID=$id" "PROOF=$(story_field "$id" .proof)" \
      "PROOF_COMMANDS=$(bullets "$id" .proof_commands)" "AC=$(bullets "$id" .acceptance_criteria)" \
      "PROOF_DIR=$proof_dir"
    call_step "$label" --model "$build_model" --cwd "$worktree" --prompt-file "$prompt" \
      --tools 'Read,Write,Glob,Grep,Bash' --allow 'Read,Glob,Grep,Bash' --schema "$(schema_file proof)" \
      --resume "$(state_get "$id" session_id)" --add-dir "$proof_dir"
    # The proof step must not change code. Keep any change in a stash, where a human can still see it.
    if [[ -n "$(git -C "$worktree" status --porcelain)" ]]; then
      git -C "$worktree" stash push -q -u -m "autopilot: changes made during the proof of $id"
    fi
    proof_json="$run_dir/results/$label.proof.json"
    result_of "$label" | jq '.screenshots |= map(.path |= split("/")[-1])' >"$proof_json"
    [[ "$(jq -r .status "$proof_json")" == fail ]] || break
    ((attempt < max_proof_attempts)) || { park "$id" "The proof shows that an acceptance criterion is not met: $(jq -r .summary "$proof_json")"; return; }
    fix_round "$id" "The proof run shows that the change does not work:
$(jq -r '.summary, (.evidence[] | "- \(.acceptance_criterion): \(.output_excerpt)")' "$proof_json")"
    verify_with_fixes "$id"
    is_parked "$id" && return
    push_story "$id"
  done
  if [[ "$(jq '.screenshots | length' "$proof_json")" -gt 0 ]]; then
    base_url=$(publish_screenshots "$id" "$proof_dir" "$proof_json" || true)
  fi
  comment="$run_dir/results/proof-$id.md"
  "$script_dir/render.sh" proof-comment "$proof_json" "$base_url" >"$comment"
  url=$(pr_comment "$id" "$comment")
  state_set "$id" proof_url "$(json_string "$url")"
  update_pr_body "$id"
}

step_review() {
  local id=$1 worktree diff_file="$run_dir/diffs/$1.diff" prompt="$run_dir/prompts/review-$1.md"
  local review_json comment url before problems
  worktree=$(worktree_of "$id")
  mkdir -p "$run_dir/diffs"
  git -C "$worktree" diff "$(base_ref_for "$id")...HEAD" >"$diff_file"
  render_prompt review "$prompt" "STORY_ID=$id" "STORY_TITLE=$(story_field "$id" .title)" \
    "PR_URL=$(state_get "$id" pr_url)" "DIFF_FILE=$diff_file" "AC=$(bullets "$id" .acceptance_criteria)" \
    "DECISION_TITLES=$(decision_titles)" "PLAN=$(story_field "$id" .plan_markdown)"
  call_step "review-$id" --model "$plan_model" --cwd "$worktree" --prompt-file "$prompt" \
    --tools 'Read,Glob,Grep,Bash' --allow "Read,Glob,Grep,$read_only_git,Bash(gh pr view:*),Bash(gh pr diff:*)" \
    --schema "$(schema_file review)" --add-dir "$run_dir/diffs"
  review_json="$run_dir/results/review-$id.review.json"
  result_of "review-$id" >"$review_json"
  comment="$run_dir/results/review-$id.md"
  "$script_dir/render.sh" review-comment "$review_json" >"$comment"
  url=$(pr_comment "$id" "$comment")
  state_set "$id" review_url "$(json_string "$url")"
  problems=$(jq -r '.findings | map(select(.severity == "important")) | to_entries
    | map("\(.key + 1). `\(.value.file):\(.value.line)`: \(.value.summary) Failure scenario: \(.value.failure_scenario)")
    | join("\n")' "$review_json")
  [[ "$(jq -r .verdict "$review_json")" == fix && -n "$problems" ]] || return 0
  before=$(git -C "$worktree" rev-parse --short HEAD)
  fix_round "$id" "A reviewer found these problems in the PR. Fix each one:
$problems"
  verify_with_fixes "$id"
  is_parked "$id" && return
  push_story "$id"
  comment="$run_dir/results/review-fix-$id.md"
  result_of "$(state_get "$id" last_fix)" >"$comment.json"
  "$script_dir/render.sh" fix-reply "$comment.json" "$before..$(git -C "$worktree" rev-parse --short HEAD)" >"$comment"
  pr_comment "$id" "$comment" >/dev/null
  update_pr_body "$id"
}

# The summary is for the human reviewer. A failure here does not park the story.
step_summary() {
  local id=$1 prompt="$run_dir/prompts/summary-$1.md" scratch="$run_dir/scratch/$1"
  mkdir -p "$scratch"
  render_prompt summary "$prompt" "PR_URL=$(state_get "$id" pr_url)" "SCRATCH_DIR=$scratch"
  call_step "summary-$id" --model "$build_model" --cwd "$(worktree_of "$id")" --prompt-file "$prompt" \
    --tools 'Read,Write,Glob,Grep,Bash,Skill' --allow 'Read,Glob,Grep,Bash,Skill' --skills --add-dir "$scratch" ||
    log "$id: WARNING: the PR summary step failed. See $run_dir/logs/summary-$id.*.jsonl"
}

# ---------------------------------------------------------------- run

process_story() {
  local id=$1 status dependency done_index step
  status=$(state_get "$id" status)
  case "$status" in done | parked | skipped) return ;; esac
  for dependency in $(story_field "$id" '.depends_on[]'); do
    [[ "$(state_get "$dependency" status)" == done ]] && continue
    log "$id: skipped, because $dependency is not done"
    state_set "$id" status '"skipped"'
    state_set "$id" note "\"dependency $dependency is not done\""
    return
  done
  state_set "$id" status '"running"'
  state_top phase "\"story $id\""
  done_index=$(step_index "$(state_get "$id" step)")
  for step in "${steps[@]}"; do
    (($(step_index "$step") > done_index)) || continue
    log "$id: $step"
    "step_$step" "$id"
    is_parked "$id" && return
    state_set "$id" step "\"$step\""
  done
  state_set "$id" status '"done"'
}

# Prints the errors in a candidate plan, one per line. No output means the plan is valid.
plan_errors() {
  local candidate=$1 branch
  jq -r '
    .stories as $s
    | ($s | map(.id) | group_by(.) | map(select(length > 1) | "duplicate id \(.[0])")[]),
      ($s | map(.branch) | group_by(.) | map(select(length > 1) | "duplicate branch \(.[0])")[]),
      ($s | to_entries[] | .key as $i | .value as $story | $story.depends_on[]
        | select(. as $d | ($s[0:$i] | map(.id) | index($d)) == null)
        | "story \($story.id) depends on \(.), which is not an earlier story")' <<<"$candidate"
  while IFS= read -r branch; do
    git check-ref-format --branch "$branch" >/dev/null 2>&1 || echo "branch name $branch is not valid"
    ! git -C "$repo" show-ref --verify --quiet "refs/heads/$branch" || echo "branch $branch already exists"
  done < <(jq -r '.stories[].branch' <<<"$candidate")
}

decompose() {
  local prompt="$run_dir/prompts/decompose.md" candidate errors retry_prompt="$run_dir/prompts/decompose-retry.md"
  state_top phase '"planning"'
  render_prompt decompose "$prompt" "RUN_INPUT=$(<"$run_dir/input.md")" "HANDLE=$(branch_handle)" \
    "DEFAULT_BRANCH=$(default_branch)"
  local -a common=(--model "$plan_model" --cwd "$repo" --tools 'Read,Glob,Grep,Bash'
    --allow "Read,Glob,Grep,$read_only_git,Bash(gh issue view:*),Bash(gh issue list:*),Bash(gh pr list:*),Bash(gh pr view:*),Bash(ls:*)"
    --schema "$(schema_file plan)")
  call_step decompose "${common[@]}" --prompt-file "$prompt"
  candidate=$(result_of decompose)
  errors=$(plan_errors "$candidate")
  if [[ -n "$errors" ]]; then
    log "the plan has errors. One retry: $errors"
    printf 'The run script rejected your plan:\n%s\nFix these errors. Return the full plan again.\n' "$errors" >"$retry_prompt"
    call_step decompose-retry "${common[@]}" --prompt-file "$retry_prompt" \
      --resume "$(jq -r '.session_id' "$run_dir/results/decompose.json")"
    candidate=$(result_of decompose-retry)
    errors=$(plan_errors "$candidate")
    [[ -z "$errors" ]] || fail "the plan is still not valid: $errors"
  fi
  jq '{feature_title, stories}' <<<"$candidate" >"$plan"
  while IFS= read -r line; do
    add_decisions "$(jq -r '.id' <<<"$line")" "$(jq -c '[.record]' <<<"$line")"
  done < <(jq -c '.decisions[] | .record as $r | .applies_to[] | {id: ., record: $r}' <<<"$candidate")
  log "plan: $(jq -r '.stories | map(.id) | join(", ")' "$plan")"
}

write_summary() {
  local out="$run_dir/summary.md" cost pauses
  cost=$(cat "$run_dir"/results/*.json 2>/dev/null | jq -s 'map(.total_cost_usd? // 0) | add // 0 | . * 100 | round / 100')
  pauses=$(wc -l <"$run_dir/usage-pauses.log" 2>/dev/null || echo 0)
  {
    echo "# efficient-autopilot run $(basename "$run_dir")"
    echo
    jq -r '"Feature: \(.feature_title)\n"' "$plan"
    echo "| Story | State | PR | Decisions | Note |"
    echo "| --- | --- | --- | --- | --- |"
    for id in $(story_ids); do
      printf '| `%s` | %s | %s | %s | %s |\n' "$id" "$(state_get "$id" status)" "$(state_get "$id" pr_url)" \
        "$(jq 'length' "$run_dir/decisions/$id.json" 2>/dev/null || echo 0)" "$(state_get "$id" note)"
    done
    echo
    echo "Usage pauses: $pauses. Cost at API prices: \$$cost (a subscription pays from its usage limit)."
  } >"$out"
  cat "$out" >&2
}

notify_done() {
  command -v notify-send >/dev/null || return 0
  notify-send "efficient-autopilot" "Run $(basename "$run_dir") is done. See $run_dir/summary.md" || true
}

main() {
  local tool id
  for tool in claude gh jq wt git timeout; do
    command -v "$tool" >/dev/null || fail "missing tool: $tool"
  done
  gh auth status >/dev/null 2>&1 || fail 'gh is not logged in'
  mkdir -p "$run_dir/prompts" "$run_dir/logs"
  [[ -r "$state" ]] || echo '{"phase": "starting", "stories": {}}' >"$state"
  [[ -r "$plan" ]] || decompose
  for id in $(story_ids); do
    process_story "$id"
  done
  state_top phase '"done"'
  write_summary
  notify_done
}

main
