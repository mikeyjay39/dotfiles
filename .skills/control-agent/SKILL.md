---
name: control-agent
description: Makes this session the controller of one Claude agent per Notion ticket or GitHub issue. Each agent gets its own worktrunk worktree, Tilt slot and tmux session, and runs /vs-implement. The controller first gets acceptance criteria from the human for each sparse ticket or issue, then coordinates the agents and flags the human. Use when asked to control agents, coordinate agents on tickets or issues, or spawn an agent per ticket or issue.
argument-hint: '<TKT-… | #<n> | <issue-url>> […] [FTR-…]'
---

# Control Agent

This session is the **controller**. The agents do the work items. The controller sets them up, watches them, answers coordination questions, and brings product questions to the human.

Write every report and every message to an agent in ASD-STE100 Simplified Technical English.

## Arguments

Arguments are in `$ARGUMENTS`. Classify each one:

| Argument                                        | Work item                                                    |
| ----------------------------------------------- | ------------------------------------------------------------ |
| `TKT-<n>`                                       | Notion ticket.                                               |
| `<n>` or `#<n>`                                 | GitHub issue in the current repo (`gh repo view --json nameWithOwner`). |
| `https://github.com/<owner>/<repo>/issues/<n>` | GitHub issue. The URL gives the repo.                        |
| `FTR-<n>`                                       | Optional parent feature of the Notion tickets.               |

- If there is no work item, ask the human for the tickets or issues and stop.
- If an issue URL names a different repo from the current one, tell the human and ask before you continue. The worktrees are always in the current repo.

Each work item gets these names. Use them in all later steps:

| Work item     | Id        | Session   | Branch                      |
| ------------- | --------- | --------- | --------------------------- |
| Notion ticket | `TKT-<n>` | `tkt-<n>` | `<handle>/tkt-<n>-<slug>`   |
| GitHub issue  | `GH-<n>`  | `gh-<n>`  | `<handle>/gh-<n>-<slug>`    |

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
5. **Check the tools.** Run `command -v tmux wt claude gh`. `claude` can be a zsh alias, so always start it by `send-keys` into the pane shell, never as the tmux session command.
6. **Find the branch prefix.** Run `git branch --list '*/tkt-*' '*/gh-*'` and take the handle of the git user (for example `mjeszenka`).
7. **Create the worktrees from fresh `main`.** Each takes minutes, because the `pre-start` hooks run `pnpm install` and assign a Tilt slot. Run all of them one after the other in one Bash call, with `run_in_background: true` and `timeout: 600000`:
   ```bash
   git fetch -q origin main
   wt switch --create <branch> --base origin/main --no-cd -y
   ```
8. **Record each worktree.** Get its path from `git worktree list`. Get its Tilt slot with `grep -oP 'for slot \K[0-9]+' <worktree>/.env.tilt.ports`. No file means slot 0.
9. **Write one prompt file per work item** at `<scratchpad>/prompts/<id>.md`. Use the template in [`references/agent-prompt.md`](references/agent-prompt.md). A blocked work item gets the plan-only block from that file.
10. **Start one session per work item:**
    ```bash
    tmux new-session -d -s <session> -c <worktree>
    tmux send-keys -t <session> "claude -n <session> \"\$(cat <scratchpad>/prompts/<id>.md)\"" Enter
    ```
11. **Check each start.** Wait about 20 s. Run `tmux capture-pane -p -t <session>`. The step is done when each pane shows Claude at work on `/vs-implement`. If a pane shows a trust prompt or an error, fix it before you continue.
12. **Report the setup** (see [Reports](#reports)). Then start the watcher.

## The watch loop

1. **Start the watcher** with `run_in_background: true`:
   ```bash
   ~/.claude/skills/control-agent/scripts/watch.sh <session-a> <session-b> …
   ```
   Pass only the sessions that you expect to work. Leave out an agent that waits on purpose, for example a blocked work item that finished its plan. Otherwise the watcher fires at once. It prints `IDLE: <session>` or `GONE: <session>`, then exits, and that wakes you.
   - Do not start it with `&` or `disown`. Only a `run_in_background` call wakes you when it exits.
   - Run only one watcher at a time. To stop one, use `pgrep -f '[w]atch.sh'` and `kill <pid>`. Do not use `pkill -f watch.sh`, because it also stops its own shell.
2. **Read the agent's last turn:**
   ```bash
   tmux capture-pane -p -J -S -200 -t <session> | grep -v '^\s*$' | tail -60
   ```
3. **Handle it.** Answer a coordination question yourself. Collect a product, spec, arch, or plan question for the human (see [Asking the human](#asking-the-human)). Read the other idle panes too, so that you can batch their questions.
4. **Restart the watcher** with the sessions that you now expect to work. Do this after each handling.

**Other watches**, each with `run_in_background: true`:

- **PR feedback:** `~/.claude/skills/control-agent/scripts/watch-pr.sh <pr> [owner-login] [repo]`. It exits on a review or comment from anyone but the owner, or on a state change. Send the feedback to the agent that owns the PR.
- **A live run:** `gh run watch <id> --exit-status --interval 60 >/dev/null 2>&1; gh run view <id> --json conclusion,url,jobs`. An agent that waits on its own run looks idle to `watch.sh`, so watch the run instead.
- **Live runs share one environment.** Give one agent the run slot at a time, so that runs do not change each other's figures.

**After a restart:** background tasks and `/tmp` are gone. Keep scripts in this skill folder, not in the scratchpad. Check that the tmux sessions still run `claude`, and read each pane. Check the runs and PRs for events you missed, then start the watches again.

## Sending a message to an agent

Send the text and the Enter key as two calls. `-l` keeps the text literal:

```bash
tmux send-keys -t <session> -l "From the control session: <text>"
sleep 0.5
tmux send-keys -t <session> Enter
```

A message sent while the agent is busy waits in its queue for its next turn.

## Grey suggestions are not answers

Claude Code shows a dim suggested reply in the input box of an idle pane. It looks like human input. It is not.

- Check the `❯` line with `tmux capture-pane -p -e -t <session> | grep '❯'`. Dim text has `ESC[2m` (`\x1b[2m`).
- Never submit a suggestion. Never treat it as the human's answer.

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

In each later report, give the changed rows of the table, the new decisions, and the open questions for the human.
