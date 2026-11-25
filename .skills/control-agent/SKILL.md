---
name: control-agent
description: Controls Claude, Cursor, or OpenCode V2 workers for Notion tickets or GitHub issues. Each worker gets an isolated worktree and tmux session. The controller checks acceptance criteria, coordinates workers, and reports questions to the human. Use when asked to control agents, coordinate agents on tickets or issues, or spawn an agent per ticket or issue.
argument-hint: '<TKT-… | #<n> | <issue-url>> […] [FTR-…]'
---

# Control Agent

This session is the **controller**. The agents do the work items. The controller sets them up, watches them, answers coordination questions, and brings product questions to the human.

Write every report and every message to an agent in ASD-STE100 Simplified Technical English.

## Arguments

Arguments are in `$ARGUMENTS`. Classify each one, and name its id, session, and branch, as the [`assign-work` Arguments table](../assign-work/SKILL.md#arguments) tells you. `FTR-<n>` is the optional parent feature of the Notion tickets. The controller takes no free-text work items.

- If there is no work item, ask the human for the tickets or issues and stop.
- If an issue URL names a different repo from the current one, tell the human and ask before you continue. The worktrees are always in the current repo.

## Who decides

- **The controller decides coordination.** This is who owns a shared helper, the interface shapes between work items, metric names, and the order of slices. Tell the human each such decision in your next report.
- **The human decides product, spec, arch, and plan approval.** This is acceptance criteria, spec criteria, arch decisions (`AD###`), plan acceptance, and anything destructive.

## Setup

Run these steps from the main repo checkout. `<scratchpad>` is this session's scratchpad directory.

1. **Read the work items.** Record the title, the parent feature (if there is one), the body, and the acceptance criteria (AC) of each.
   - Notion ticket: use the Notion MCP `notion-search`, then `notion-fetch`, or the `vs-notion` skill.
   - GitHub issue:
     ```bash
     gh issue view <n|url> --json number,title,body,labels,comments,url,state
     ```
     The AC can be under a heading such as "Acceptance criteria", in a checklist, or in the comments.
2. **Check the acceptance criteria.** This is a gate. Do not create worktrees or start agents until each work item has AC that the human accepted.
   - A work item is **too sparse** when one of these is true:
     - It has no AC.
     - An AC is not testable, because it has no observable result.
     - The scope is not clear. An example is a body of one line.
     - The AC and the body contradict each other.
   - For each sparse item, draft testable AC from the body, the comments, and the code.
   - Ask the human with `AskUserQuestion`. Use 4 questions or fewer in each call. Use more rounds if necessary. In each question, expand the id, quote the source text, and put your drafted AC first as the recommended option.
   - Record the agreed AC of each item. They go into the agent prompt.
   - Writing the agreed AC back to the Notion ticket or the GitHub issue is outward-facing. Ask the human first. Write them only on a yes, as a Notion comment or with `gh issue comment`.
3. **Build the dependency order.** Order the work items so that blockers come first.
   - Notion tickets: find the parent feature's tickets mirror page, titled `FTR-<n> · Tickets: …`, in the AI-DLC Documents database. Read the `Blocked by` column of its Children table.
   - GitHub issues: read "Blocked by #n" and "Depends on #n" in the body, and the sub-issue and tracked-by links.
   - If the order is not clear, ask the human.
4. **Check blockers outside the list.** A work item is **blocked** when one of its blockers is not merged.
   - Notion ticket blocker: find its PR. It is merged when the PR has `mergedAt`.
     ```bash
     gh pr list --author @me --state all --search "TKT-a OR TKT-b" --json number,title,state,headRefName,mergedAt
     ```
   - GitHub issue blocker: it is merged when a merged PR closed the issue.
     ```bash
     gh issue view <n> --json state,closedByPullRequestsReferences
     ```
5. **Find the branch prefix.** Run `git branch --list '*/tkt-*' '*/gh-*'` and take the handle of the git user (for example `mikeyjay39`).
6. **Write one prompt file per work item** at `<scratchpad>/prompts/<id>.md`. Use the template in [`../assign-work/references/worker-prompt.md`](../assign-work/references/worker-prompt.md). A blocked work item gets the plan-only block from that file.
7. **Start at most three active workers** with the [`assign-work`](../assign-work/SKILL.md) script. Queue later items.
   Its preconditions apply. `<skills-dir>` is the canonical global `.skills` folder.
   Select `claude`, `cursor`, or `opencode`. Use OpenCode when the human requests it.
   Get the boss pane ID explicitly. OpenCode tools need not inherit the controller's tmux environment.
   Each worktree can take minutes. Use the CLI's shell background support where available.
   ```bash
   <skills-dir>/assign-work/scripts/assign-work.sh \
     --session <session> --branch <branch> --prompt-file <scratchpad>/prompts/<id>.md \
     --agent <claude|cursor|opencode> --boss-pane <boss-pane-id> [--model <model>]
   ```
   Add `--model` only when the human names a model for the workers.
   Record the `worktree=` and `slot=` that each run prints.
8. **Check each start.** Wait about 20 s. Run `tmux capture-pane -p -t <session>`. The step is done when each pane shows the worker at work. If a pane shows a trust prompt or an error, fix it before you continue.
9. **Report the setup** (see [Reports](#reports)). Then start the watcher.

## The watch loop

Workers report into this pane with `From worker <session>: <kind>: <text>`. Handle each report as [`assign-work`](../assign-work/SKILL.md#reports-from-workers) tells you. A `question:` report has the options and the worker's recommendation, so you can usually answer without reading the pane. The watcher is a fallback for a worker that stops without a report.

Each wake-up is a turn that reads the full conversation again. Keep turns few and short:

- Handle the event, restart the watcher, and end the turn. Do not narrate between tool calls.
- Do not read a pane only to check on a worker. Run `<skills-dir>/control-agent/scripts/status.sh [<session> …]`. It prints one line per worker: busy, waiting, or gone, and the last report.

1. **Start the watcher** with `run_in_background: true`:
   ```bash
   <skills-dir>/control-agent/scripts/watch.sh <session-a> <session-b> …
   ```
   Pass only the sessions that you expect to work. Leave out an agent that waits on purpose, for example a blocked work item that finished its plan. Otherwise the watcher fires at once. It prints one `IDLE: <session>` line for each idle session, or `GONE: <session>`, then exits, and that wakes you.
   - It waits 30 s after the first idle session, so that workers that stop together wake you one time.
   - It does not fire for a worker that stopped just after a `question:`, `blocked:`, or `done:` report. You already have that report.
   - Do not start it with `&` or `disown`. Only a `run_in_background` call wakes you when it exits.
   - Run only one watcher at a time. To stop one, use `pgrep -f '[w]atch.sh'` and `kill <pid>`. Do not use `pkill -f watch.sh`, because it also stops its own shell.
   - `UNKNOWN` with exit code 2 means identity or API checks failed. Check that error. Do not mark the worker idle.
2. **Read the agent's last message:**
   ```bash
   <skills-dir>/assign-work/scripts/last-turn.sh <session>
   ```
   For Claude, it prints the final message from the transcript, with no TUI text. For Cursor and OpenCode, it prints the end of the pane. Read the full pane only when you need tool output or a prompt on the screen.
3. **Handle it.** Answer a coordination question yourself. Collect a product, spec, arch, or plan question for the human (see [Asking the human](#asking-the-human)). To batch questions, run `status.sh` once to find the other workers that wait. Then read only those.
4. **Restart the watcher** with the sessions that you now expect to work. Do this after each handling.

**Other watches**, each with `run_in_background: true`:

- **PR feedback:** `<skills-dir>/control-agent/scripts/watch-pr.sh <pr> [owner-login] [repo]`. It exits on a review or comment from anyone but the owner, or on a state change. Send the feedback to the agent that owns the PR.
- **A live run:** `gh run watch <id> --exit-status --interval 60 >/dev/null 2>&1; gh run view <id> --json conclusion,url,jobs --jq '{conclusion, url, failed: [.jobs[] | select(.conclusion == "failure") | {name, url}]}'`. An agent that waits on its own run looks idle to `watch.sh`, so watch the run instead.
- **Live runs share one environment.** Give one agent the run slot at a time, so that runs do not change each other's figures.

**After a restart** of this session, follow [`references/restart.md`](references/restart.md).

## Messages and grey suggestions

Send messages and treat grey suggestions as [`assign-work`](../assign-work/SKILL.md#sending-a-message-to-a-worker) tells you. Never submit a grey suggestion. Never treat it as the human's answer.

## Asking the human

- **Batch the questions.** Put the questions from all agents into one `AskUserQuestion` call, with 4 questions or fewer.
- **Give full background in each question.** Expand every id. Cite the AC, the `AD###`, the issue numbers, and the PR numbers. Put the recommended option first.
- **Ask a shared question once.** When several agents ask the same thing (for example, one design rule that applies to every test), ask it one time and send the answer to all of them.
- **Relay partial answers at once.** When the human answers only some questions, send those answers now. Tell those agents to update their plans and to write no code until the plan is approved.
- **Flag the human** when an agent needs a product, spec, arch, or plan decision, when a check fails again and again, when a PR opens, or when a decision changes an arch record.

## Plans and blocked work items

- **Plan review.** When the human asks for plan review, or accepts your offer of it, follow [`references/plan-review.md`](references/plan-review.md). It also tells you how to cross-read the plans for conflicts before approval.
- **Blocked work items** plan only, then wait. When a blocker is on a branch or merged, tell the agent its name, its branch or PR, and what is now ready to build on.

## Reports

After setup, show this table:

| Session     | Work item        | Worktree | Tilt slot | State                                    |
| ----------- | ---------------- | -------- | --------- | ---------------------------------------- |
| `<session>` | `<id>` title     | path     | slot      | planning / blocked: plan only / building |

Under the table, list:

- The work items whose AC the human agreed in setup step 2, each with a one-line summary.
- The coordination decisions that you made, each with its reason.
- How to attach to a session: `tmux attach -t <session>`. Detach with `Ctrl-b d`.

In each later report, give the changed rows of the table, the new decisions, and the open questions for the human. Do not repeat the full table.

## Model choice

The controller mostly routes reports. When the work items have clear AC, tell the human one time, at setup, that a smaller model (`/model`) can run the controller. Keep the larger model for AFK runs, because the controller then makes product decisions.
