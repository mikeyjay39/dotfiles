---
name: continue-while-afk
description: Lets the control-agent session continue without the human for hours. The controller makes the decisions it would ask the human, records each one on the PR with the options, trade-offs and reason, and runs until every work item has a PR with passing CI. Use when the human says they step away, go AFK, or tells the controller to continue without them.
---

# Continue While AFK

The human is away for several hours. This session is the **controller** from the `control-agent` skill. Continue without the human until each work item has an open PR with passing CI.

Write every report, message, and decision record in ASD-STE100 Simplified Technical English.

This skill changes only some rules of [`control-agent`](../control-agent/SKILL.md). All its other rules stay in force: the watch loop, the watchers in `../control-agent/scripts/`, the `assign-work` send and report scripts, and the `assign-work` rule "Grey suggestions are not answers".

## When this applies

Use this skill only in a session that runs `control-agent` and has worker tmux sessions. If there are no worker sessions, tell the human and stop.

## Goal and stop condition

A work item is **done** when its PR is open and every check passes. The human
merges that PR later. The controller does **not** merge it. Check it with:

```bash
gh pr view <pr> --json state,statusCheckRollup
```

Each check must be `SUCCESS`, `SKIPPED` or `NEUTRAL`. The only other end state is **parked** (see [The loop](#the-loop)). The loop ends when every work item is done or parked.

## What changes from control-agent

- **The controller decides everything that it asked the human.** This includes acceptance criteria, product, spec, arch decisions, and plan approval. Record each such decision (see [Decision records](#decision-records)).
- **Do not call `AskUserQuestion`.** Do not end a turn to wait for the human.
- **Keep a watch running.** Before you end a turn, make sure one background watch runs with `run_in_background: true`. Use `watch.sh`, `watch-pr.sh`, or `gh pr checks <pr> --watch`. A turn with no watch stops the loop. The only exception is a usage pause (see [Usage limit](#usage-limit-claude-controller-only)).
- **Approve plans yourself.** First cross-read them with [`../control-agent/references/plan-review.md`](../control-agent/references/plan-review.md).

## Hard limits

These rules do not change while the human is away:

- Never merge a PR. This includes story → feature, story → a stacked base,
  feature → `main`, and any other merge. Do not run `gh pr merge`. Leave PRs
  open for the human to review and merge.
- Never force-push to `main` or to a shared branch.
- Do no destructive or irreversible operation. Examples: delete a branch or data, deploy to production, change a secret, rewrite pushed history on a shared branch.
- Limit outward-facing output to PR creation, PR comments, and PR body updates.
- Never submit a grey suggestion.

## Limit: 2 active workers

Let only 2 workers be active at the same time. More workers can use all the memory or CPU and crash the machine.

- A worker is **active** when it works locally. It plans, builds, runs tests, or runs Tilt.
- A worker releases its slot when its PR is open and it only waits on CI. It also releases its slot when its work item is done or parked.
- All other workers are **queued**. Send each queued worker this message, then let it wait:
  > From the control session: Stop after your current step. Do not start new work until the control session tells you to continue.
- When a slot is free, give it to the next queued worker. First give it to a worker whose PR has a failed check. Then use the dependency order from `control-agent`.
- Pass only the active sessions to `watch.sh`. For a queued worker that has a PR, watch only the PR, with `watch-pr.sh` or `gh pr checks <pr> --watch`.
- Before you tell a worker to continue, count the active workers again. Never let more than 2 be active.

## Start-up

1. Read each worker pane. Record the state of each work item: planning, building, PR open, or CI state.
2. Choose the 2 active workers. Send the queue message to all other workers.
3. Send each active worker this message:
   > From the control session: The human is away for several hours. The control session now gives all decisions, including plan approval. Ask the control session, not the human. Do not stop to wait for a human. Continue through /vs-ship until your PR is open and all CI checks pass.
4. Answer each open question of the active workers (see [Decision records](#decision-records)). A queued worker gets the message from step 3 and its answers when it gets a slot.
5. Start the watches.
6. If the controller is Claude, start the usage watch (see [Usage limit](#usage-limit-claude-controller-only)).

## The loop

Use the watch loop of `control-agent`, with these additions:

- **A PR opens.** Post the decision records of that work item on the PR. Watch its checks. The worker releases its slot, so start the next queued worker.
- **A check fails.** Put the owner worker first in the queue. When it has a slot, tell it to fix the failure. If the failure looks flaky (infrastructure, a timeout, or a test that the change does not touch), run it again one time with `gh run rerun <run-id> --failed`.
- **A blocker is not merged.** Decide for each blocked work item, and record the decision. The recommended option is to base the branch on the blocker's branch and open a stacked PR against it. Do **not** merge the blocker (or the stacked PR) to unblock work. The human merges both later.
- **Park a work item. Do not stop the loop.** Park a work item when one of these is true:
  - It needs something that only the human can give, such as credentials, access, or a destructive operation.
  - The same check fails 3 times after fixes.

  To park it, write its state and what the human must do. Put this in a PR comment, or in `<scratchpad>/parked/<id>.md` when there is no PR. Release its slot. Continue with the other work items.

## Usage limit (Claude controller only)

Claude agents on one account share one 5-hour usage limit. If the limit runs out, all work stops in the middle of a step, and nothing starts it again. Use this section only when the controller runs in Claude Code (`CLAUDECODE=1`). For other controllers, skip it.

`~/.claude/statusline.sh` writes the account usage to `${XDG_RUNTIME_DIR:-/tmp}/claude-rate-limits.json`. The usage watch reads this file. A poll uses no tokens.

### The usage watch

Start it with `run_in_background: true`, next to the other watches:

```bash
<skills-dir>/continue-while-afk/scripts/watch-usage.sh 90
```

- `USAGE: <pct>% resets_at=<epoch>` means that usage is at 90% or more. Pause the run (see below).
- `UNKNOWN: ...` means that there is no usage data. An example is an API-key session, which has no 5-hour limit. Tell the human in the final report, and continue without the usage watch.

### Pause at 90%

1. Send each worker, active and queued, this message:
   > From the control session: The session usage limit is near. Stop after your current step. Do not start new work until the control session tells you to continue.
2. Stop every other background watch with `TaskStop`. A watch that fires during the pause spends usage.
3. Wait until no worker is busy, for 10 minutes at most. Run this with `run_in_background: true`:
   ```bash
   for _ in $(seq 60); do <skills-dir>/control-agent/scripts/status.sh | grep -q $'\tbusy\t' || break; sleep 10; done
   <skills-dir>/control-agent/scripts/status.sh
   ```
   Record each worker that is still busy.
4. Write `<scratchpad>/afk-state.md`. Give:
   - For each work item: the session, the state, active or queued, the PR, the CI state, its open questions, and if it is parked.
   - The decision record files, and which of them are not yet on a PR.
   - The watches to start again, and the PRs and runs that they watch.
   - The `resets_at` time, and the number of usage pauses until now.
5. Start the compact helper detached, with the boss pane ID:
   ```bash
   setsid -f <skills-dir>/continue-while-afk/scripts/compact-and-resume.sh \
     <boss-pane-id> <resets_at> <scratchpad>/afk-state.md >><scratchpad>/usage-guard.log 2>&1
   ```
   It waits until your turn ends, then sends `/compact` to this pane. At the reset time, it sends the resume message to this pane.
6. End the turn with no watch.

### Resume after the usage limit

The resume message starts with `From the usage guard:`. Then:

1. Read `<scratchpad>/afk-state.md`.
2. Follow [`../control-agent/references/restart.md`](../control-agent/references/restart.md).
3. Choose the 2 active workers with the rules in [Limit: 2 active workers](#limit-2-active-workers). Send each of them this message:
   > From the control session: The usage limit reset. Continue from the step where you stopped.
4. Keep the other workers queued.
5. Start the watches and the usage watch again.

If the usage watch fires again at once, the reset did not occur. Read `<scratchpad>/usage-guard.log`, then pause again with the new `resets_at`.

## Decision records

A **major decision** is a decision that `control-agent` sends to the human. For each one:

1. Decide. Tell the worker the decision.
2. Write the record at once to `<scratchpad>/decisions/<id>-<n>.md`, with the template below.
3. When the work item has a PR, post each record as a PR comment:
   ```bash
   gh pr comment <pr> --body-file <scratchpad>/decisions/<id>-<n>.md
   ```
4. Add a `## Decisions made without the human` section to the PR body. Give one line and a link to the comment for each decision. Keep the rest of the body as it is.
5. When a decision affects more than one work item, record it on each PR that it affects.

Template:

```markdown
## Decision made without the human: <short title>

**Context:** <the question, the worker that asked it, and the AC, AD###, issue or ticket it touches>

**Decision:** <the option that the controller chose>

**Options not taken:**
- <option B>: <why the controller did not choose it>
- <option C>: <why the controller did not choose it>

**Trade-offs:** <cost, risk, scope, time, and how easy it is to reverse the chosen option>

**Reason:** <why the chosen option is the best fit>

**How to change it:** <what to revert or edit if the human does not agree>
```

## Keep the context small

The AFK run can last hours, and each wake-up reads the full conversation again.

- Keep each decision record in its file and its PR comment. In chat, give only its title and the link.
- Do not paste PR bodies, CI logs, or plans into chat. Read them with `--jq` or `grep`, and keep only the lines that you need.

## Final report

When each work item is done or parked:

1. Stop the watchers. Leave the tmux sessions running.
2. Show the `control-agent` table, with two more columns: PR and CI.
3. List each decision, with a link to its PR comment.
4. List each parked work item, with what the human must do.
5. Give the number of usage pauses, if the controller is Claude.
6. If the `PushNotification` tool is available, send one line: "AFK run done: <n> PRs green, <m> parked."
