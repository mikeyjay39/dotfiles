---
name: efficient-autopilot
description: Starts an unattended, token-efficient run that builds one work item or a feature of many stories, with no human. Opus plans and accepts its own plan, then reviews each PR one time. Sonnet builds, fixes, proves the change with output or screenshots, and posts the PR summary. Each story gets a stacked draft PR with its major decisions and trade-offs in the description. A bash script runs the pipeline in tmux, so no model session stays open between steps. Use when the user says autopilot, run overnight, or work on these issues while I sleep or while I watch.
argument-hint: '<#n | issue-url | "description"> […]'
---

# Efficient Autopilot

This skill only starts the run. The run itself is `scripts/autopilot.sh`, in its own tmux session. Do not plan, read the issues, or watch the run in this session. That costs tokens and the script does it.

Write every report to the human in ASD-STE100 Simplified Technical English.

`<skill-dir>` is the folder of this file.

## Arguments

Arguments are in `$ARGUMENTS`. Each one is a work item:

- `#<n>` or `<n>`: a GitHub issue of the current repo.
- `https://github.com/<owner>/<repo>/issues/<n>`: a GitHub issue. If it names a different repo from the current one, tell the human and stop.
- Any other text: a description of the work. Pass it as one argument.

A feature issue with sub-issues or a task list becomes many stories. If there is no argument, ask the human for the work and stop.

`--base <branch>` before the work items sets the base branch, for example a feature branch. The first story is based on it, and its PR targets it. The branch must be on origin. Without `--base`, the base is the default branch of origin. A resumed run keeps its base branch.

## Steps

1. **Check the preconditions.** Stop and tell the human when one fails.
   - The current directory is the main checkout of a git repo with a GitHub remote.
   - `command -v claude gh jq wt git tmux timeout` finds each tool.
   - `gh auth status` passes.
2. **Start the run.** Quote each work item as one argument:
   ```bash
   <skill-dir>/scripts/start.sh [--base <branch>] '<work item>' […]
   ```
   It prints `run_dir=` and `session=`.
3. **Report** to the human, then end the turn:
   - Watch the run: `tmux attach -t <session>`. Detach with `Ctrl-b d`. Watching uses no tokens.
   - The top pane shows each tool call. The bottom pane shows each story's state and the 5-hour usage.
   - The run state is in `<run_dir>`. The result is in `<run_dir>/summary.md`.
   - To continue after a stop or a reboot: `<skill-dir>/scripts/start.sh --resume <run_dir>`. When the run's tmux session is still open and no pipeline runs, it opens a new window there.

## Rerun a story

When the human asks for more work on a done or parked story of an existing run, do not write a new script or start a new run. Queue a rerun:

```bash
<skill-dir>/scripts/start.sh --rerun <run_dir> <story-id> <fix|proof|fix,proof> '<instructions>'
```

- `fix`: the worker resumes its own session and changes the code as the instructions say. The script verifies (2 fix rounds or fewer, then park), pushes, and replies on the PR.
- `proof`: the worker resumes its session and proves the story again. The screenshots go to a new `<story>-rerun-<n>` folder on the proof branch, and the PR body links the new proof comment. A failed proof is reported, not fixed. The human decides.
- The instructions apply to that step only. Where they allow more than the hard limits (for example, one live call to a paid API), they win. Tell the worker where to find a secret. Never put a secret value in the instructions.
- The rerun reuses the run's tmux session, in a new window. When the pipeline still runs, the request waits in the queue, and the pipeline does it after its stories.
- Each request is in `<run_dir>/reruns/<n>.json`. `summary.md` lists each rerun and its result.

## What the run does

1. **Plan (Opus).** One call reads the work items and the code. It writes stories in dependency order, with testable acceptance criteria (AC), verify commands, a proof type, and a build plan. It records each major decision. The script validates the plan.
2. **For each story (stacked on the story before it; the first story is stacked on the base branch):**
   1. Make a worktree with `wt`.
   2. **Build (Sonnet).** It writes tests first, implements, and commits.
   3. **Verify (script).** It runs the verify commands. Sonnet gets 2 fix rounds or fewer. Then the story is parked.
   4. **Publish (script).** It pushes and opens a draft PR. The description has the AC, the verify results, and each decision with its options, trade-offs, reason, and how to change it.
   5. **Proof (Sonnet).** It runs the change for real and posts the output, and screenshots for UI changes, as a PR comment.
   6. **Review (Opus, one time).** A fresh session reviews the PR diff against the AC. It posts the findings. Sonnet gets one fix round for the `important` findings.
   7. **Summary (Sonnet).** It runs the `pr-summary-for-human` skill on the PR.
3. **Summary (script).** It writes `summary.md` and sends a desktop notification when `notify-send` exists.

A parked story gets a `[PARKED]` draft PR with the reason. Stories that depend on it are skipped. Other stories continue.

## Models and limits

- Set `AUTOPILOT_PLAN_MODEL` (default `opus`) and `AUTOPILOT_BUILD_MODEL` (default `sonnet`) before `start.sh` to change the models.
- When the 5-hour usage reaches 90% (`AUTOPILOT_USAGE_THRESHOLD=0.9`), the run pauses until the window resets. The usage comes from the `rate_limit_event` of each headless call.
- The run never merges, never force-pushes, and pushes only from the script. `settings/deny.json` blocks destructive commands. It is a guard, not a sandbox: the build and proof steps can run other shell commands, and the script runs the verify commands that Opus wrote.

## Files

- `scripts/autopilot.sh`: the pipeline and its state machine.
- `scripts/claude-step.sh`: one `claude -p` call, with logs, usage pauses, and retries.
- `scripts/render.sh`: the PR body and the comments, with no model.
- `scripts/progress.sh`, `scripts/pretty-stream.sh`: the live view.
- `references/*.md`: the step prompts. `schemas/*.json`: the structured output of each step.

Run `bash <skill-dir>/tests/autopilot.test.sh` after a script change. The tests use mocks only.
