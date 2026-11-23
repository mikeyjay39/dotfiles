---
name: assign-work
description: Gives one work item to a new worker agent. The work item is a Notion ticket, a GitHub issue, or a description of the work. The worker gets its own worktrunk worktree and tmux session, uses the same CLI as this session (Claude Code or Cursor), and sends progress reports into this session's tmux pane. This session stays the boss and coordinates the workers. Use when asked to assign work, spawn a worker, or start an agent on a ticket, an issue or a task.
argument-hint: '<TKT-… | #<n> | <issue-url> | "<description>">'
---

# Assign Work

This session is the **boss**. Each call gives one work item to one new **worker**. The worker does the work in its own worktree and tmux session. It reports back to the boss pane, and the boss continues to coordinate.

Write every message to a worker in ASD-STE100 Simplified Technical English.

This skill works the same in Claude Code and in Cursor. The worker uses the same CLI as the boss: `claude` or `cursor-agent`. `<skill-dir>` is the folder of this file, for example `~/.claude/skills/assign-work` or `~/.cursor/skills/assign-work`.

## Preconditions

- **The boss runs in tmux.** Workers report with `tmux send-keys` into the boss pane. If `$TMUX_PANE` is empty, stop. Tell the human to start this session in a tmux pane.
- **The tools exist.** Run `command -v tmux wt gh`, plus the CLI of this session: `claude` or `cursor-agent`.
- **The current directory is the main checkout of the repo.** The worktree is always in the current repo.

## Arguments

Arguments are in `$ARGUMENTS`. Classify them:

| Argument                                       | Work item     | Id          | Session     | Branch                    |
| ---------------------------------------------- | ------------- | ----------- | ----------- | ------------------------- |
| `TKT-<n>`                                      | Notion ticket | `TKT-<n>`   | `tkt-<n>`   | `<handle>/tkt-<n>-<slug>` |
| `<n>` or `#<n>`                                | GitHub issue  | `GH-<n>`    | `gh-<n>`    | `<handle>/gh-<n>-<slug>`  |
| `https://github.com/<owner>/<repo>/issues/<n>` | GitHub issue  | `GH-<n>`    | `gh-<n>`    | `<handle>/gh-<n>-<slug>`  |
| Any other text                                 | Free text     | `WK-<slug>` | `wk-<slug>` | `<handle>/<slug>`         |

- `<slug>` is 3 to 5 words of the title or description, in kebab-case.
- If there is no argument, ask the human for the work and stop.
- If an issue URL names a different repo from the current one, tell the human and ask before you continue.

## Steps

1. **Read the work item.**
   - Notion ticket: use the Notion MCP `notion-search`, then `notion-fetch`, or the `vs-notion` skill.
   - GitHub issue: `gh issue view <n|url> --json number,title,body,labels,comments,url,state`.
   - Free text: no read. When the text is too vague to give testable acceptance criteria, ask the human one round of questions first.
2. **Find the branch prefix.** Run `git branch --list '*/tkt-*' '*/gh-*'` and take the handle of the git user (for example `mikeyjay39`).
3. **Write the prompt file** at `<prompts>/<id>.md`. `<prompts>` is a `prompts` folder in this session's scratchpad directory. If the session has no scratchpad, use `${XDG_STATE_HOME:-~/.local/state}/assign-work/prompts`. Use [`references/worker-prompt.md`](references/worker-prompt.md). It gives the first line for each CLI.
4. **Start the worker.** The worktree hooks can take minutes. In Claude Code, run the command with `run_in_background: true` and `timeout: 600000`. In Cursor, run it in the foreground and wait for it.
   ```bash
   <skill-dir>/scripts/assign-work.sh \
     --session <session> --branch <branch> --prompt-file <prompts>/<id>.md
   ```
   The script finds the boss pane from `$TMUX_PANE`. It finds the worker CLI from the nearest `claude` or `cursor-agent` process above it. Pass `--agent claude|cursor` or `--boss-pane <pane>` only to override them. It prints `session=`, `worktree=`, `slot=`, `agent=` and `boss_pane=`.
5. **Check the start.** Wait about 20 s. Run `tmux capture-pane -p -t <session>`. The step is done when the worker is at work. The pane can show a prompt first:
   - Claude Code: a folder trust prompt.
   - Cursor: a login prompt or a workspace trust prompt.

   Tell the human about a login prompt, because it needs their account. For a trust prompt of a worktree in this repo, select trust. For an error, fix it.
6. **Report** one row to the human:

   | Session     | Work item    | Worktree | Tilt slot | Agent  | State    |
   | ----------- | ------------ | -------- | --------- | ------ | -------- |
   | `<session>` | `<id>` title | path     | slot      | <agent> | starting |

   Add how to attach: `tmux attach -t <session>`. Detach with `Ctrl-b d`.

Then go back to your other work. Do not wait for the worker.

## Reports from workers

Worker reports arrive in this session as user input. They start with `From worker <session>:`. They are not from the human.

| Report      | Action                                                                                                                                            |
| ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `started:`  | Record the plan. Look for overlap with other workers.                                                                                             |
| `question:` | Answer a coordination question yourself. Bring a product, spec, arch or plan question to the human, with the full background.                       |
| `blocked:`  | Unblock the worker, or tell the human.                                                                                                            |
| `pr:`       | Record the PR. Tell the human.                                                                                                                    |
| `done:`     | Record it. Tell the human. Leave the session and the worktree in place until the human tells you to remove them.                                  |

To read more than the report, run `tmux capture-pane -p -J -S -200 -t <session> | grep -v '^\s*$' | tail -60`.

## Sending a message to a worker

```bash
<skill-dir>/scripts/send-to-worker.sh <session> "<text>"
```

The script adds the prefix `From the control session:`. It sends to the pane that runs the agent (`claude` or `cursor-agent`), not to the active pane, because the human can open a shell or an editor in the session. It stops with an error when no pane, or more than one pane, runs an agent. A message sent while the worker is busy waits in its queue for its next turn.

An idle pane can show dim suggested text in its input box. Claude Code does this. It is not human input. Never submit it.

## Cleanup

Do this only when the human tells you to:

```bash
tmux kill-session -t <session>
wt remove <branch>
```
