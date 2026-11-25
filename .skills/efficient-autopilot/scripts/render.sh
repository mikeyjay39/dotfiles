#!/usr/bin/env bash
# Usage: render.sh pr-body <run-dir> <story-id>
#        render.sh review-comment <review.json>
#        render.sh fix-reply <fix.json> <commit-range>
#        render.sh proof-comment <proof.json> <image-base-url>
# Builds PR text from the run files. It calls no model, so the same input always gives the same text.
set -euo pipefail

usage() {
  sed -n '2,5p' "$0" | sed 's/^# //' >&2
  exit 2
}

# The jq definition that turns one decision record into Markdown.
decision_markdown='
  def decision_markdown:
    "### Decision: \(.title)\n\n"
    + "**Context:** \(.context)\n\n"
    + "**Decision:** \(.decision)\n\n"
    + "**Options not taken:**\n"
    + (if (.options_not_taken | length) == 0 then "- None.\n"
       else (.options_not_taken | map("- \(.option): \(.reason)") | join("\n")) + "\n" end)
    + "\n**Trade-offs:** \(.trade_offs)\n\n"
    + "**Reason:** \(.reason)\n\n"
    + "**How to change it:** \(.how_to_change)\n";'

pr_body() {
  local run_dir=$1 id=$2 decisions="$1/decisions/$2.json"
  [[ -r "$decisions" ]] || decisions=/dev/null
  jq -r -n --arg id "$id" --arg run "$(basename "$run_dir")" \
    --slurpfile plan "$run_dir/plan.json" --slurpfile state "$run_dir/state.json" \
    --slurpfile decisions <(jq -s 'add // []' "$decisions") "$decision_markdown"'
    $plan[0] as $p
    | ($p.stories | map(.id) | index($id)) as $index
    | $p.stories[$index] as $story
    | ($state[0].stories[$id] // {}) as $s
    | $decisions[0] as $records
    | [
        (if $s.status == "parked" then "> [!WARNING]\n> Parked: \($s.note // "see the comments"). A human must finish this story.\n" else empty end),
        "## Summary\n",
        $story.summary,
        (if $s.build_summary then "\n\($s.build_summary)" else empty end),
        "\nStory \($index + 1) of \($p.stories | length) in **\($p.feature_title)**. Base: `\($s.base_branch // "?")`.",
        (if $story.issue then "\nCloses #\($story.issue)" else empty end),
        "\n## Acceptance criteria\n",
        ($story.acceptance_criteria | map("- [ ] \(.)") | join("\n")),
        "\n## Verification\n",
        (if ($s.verify // []) | length == 0 then "Not run yet."
         else "| Command | Result |\n| --- | --- |\n"
           + ($s.verify | map("| `\(.command)` | \(if .exit == 0 then "✅ pass" else "❌ exit \(.exit)" end) |") | join("\n"))
         end),
        "\n## Proof\n",
        (if $story.proof == "none" then "No runnable surface (`proof: none`)."
         elif $s.proof_url then "See the [proof comment](\($s.proof_url))."
         else "Not done yet." end),
        "\n## Decisions made without the human\n",
        (if ($records | length) == 0 then "None."
         else "\($records | length) decisions. Each one gives the options, the trade-offs, and how to change it.\n\n"
           + ($records | map(decision_markdown) | join("\n"))
         end),
        "\n---\n",
        "Built by the `efficient-autopilot` skill, run `\($run)`. Opus planned and reviewed. Sonnet built. Nobody merges this PR except a human.\n",
        "🤖 Generated with [Claude Code](https://claude.com/claude-code)"
      ] | join("\n")'
}

review_comment() {
  jq -r '
    "## Automated review (Opus)\n\n"
    + "**Verdict:** \(.verdict)\n\n\(.summary)\n"
    + (if (.findings | length) == 0 then "\nNo findings.\n"
       else "\n| Severity | Location | Finding | Failure scenario |\n| --- | --- | --- | --- |\n"
         + (.findings | map("| \(.severity) | `\(.file):\(.line)` | \(.summary | gsub("\\|"; "\\|")) | \(.failure_scenario | gsub("\\|"; "\\|")) |") | join("\n")) + "\n"
       end)
    + (if .verdict == "fix" then "\nThe builder gets one fix round for the `important` findings.\n" else "" end)' "$1"
}

fix_reply() {
  jq -r --arg range "$2" '
    "## Fixes for the automated review\n\n\(.summary)\n\n"
    + (.fixed | map("- **\(.problem)**: \(.how)") | join("\n"))
    + "\n\nCommits: `\($range)`.\n"' "$1"
}

proof_comment() {
  jq -r --arg base "$2" '
    "## Proof that the change works\n\n"
    + "**Result:** \(.status)\n\n\(.summary)\n\n"
    + (.evidence | map("### \(.acceptance_criterion)\n\n```console\n$ \(.command)\n\(.output_excerpt)\n```\n") | join("\n"))
    + (if (.screenshots | length) == 0 then ""
       else "\n### Screenshots\n\n" + (.screenshots | map("**\(.caption)**\n\n![\(.caption)](\($base)/\(.path)?raw=true)\n") | join("\n")) end)
    + (if (.not_verified | length) == 0 then ""
       else "\n### Not verified\n\n" + (.not_verified | map("- \(.)") | join("\n")) + "\n" end)' "$1"
}

[[ $# -ge 1 ]] || usage
case "$1" in
  pr-body) [[ $# -eq 3 ]] || usage; pr_body "$2" "$3" ;;
  review-comment) [[ $# -eq 2 ]] || usage; review_comment "$2" ;;
  fix-reply) [[ $# -eq 3 ]] || usage; fix_reply "$2" "$3" ;;
  proof-comment) [[ $# -eq 3 ]] || usage; proof_comment "$2" "$3" ;;
  *) usage ;;
esac
