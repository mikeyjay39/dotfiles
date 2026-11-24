---
name: assign-work
description: Gives one work item to a new worker agent. Supports Claude Code, Cursor, and OpenCode V2. The worker gets its own worktrunk worktree and tmux session. It sends reports to the explicit boss pane. Use when asked to assign work, spawn a worker, or start an agent on a ticket, an issue or a task.
argument-hint: '<TKT-… | #<n> | <issue-url> | "<description>">'
---

# Assign Work

This session is the **boss**. Each call gives one work item to one new **worker**. The worker does the work in its own worktree and tmux session. It reports back to the boss pane, and the boss continues to coordinate.

Write every message to a worker in ASD-STE100 Simplified Technical English.

This skill supports Claude Code, Cursor, and OpenCode V2. Select `claude`, `cursor`, or `opencode` with `--agent`.
The default detection uses the nearest agent ancestor. OpenCode tools run on a shared server, so pass `--agent opencode` explicitly.
`<skill-dir>` is the canonical `.skills/assign-work` folder in dotfiles. Claude and Cursor skill paths can be symlinks to it.

## Preconditions

- **The boss runs in tmux.** Get its explicit pane ID, such as `%1`, from the controller. Pass `--boss-pane`.
  Do not infer the boss target from OpenCode tool variables. They can belong to the shared server.
- **The tools exist.** Run `command -v tmux wt gh`, plus `claude`, `cursor-agent`, or `opencode` as selected.
  OpenCode also needs `python3` for JSON. Message delivery needs `flock`.
- **The current directory is the main checkout of the repo.** The worktree is always in the current repo.
- **At most three workers are active.** Queue further work until a worker stops. Keep any smaller host stack cap.

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
4. **Start the worker.** The worktree hooks can take minutes. Use the current CLI's shell tool and background support.
   ```bash
   <skill-dir>/scripts/assign-work.sh \
     --session <session> --branch <branch> --prompt-file <prompts>/<id>.md \
     --agent <claude|cursor|opencode> --boss-pane <boss-pane-id>
   ```
   For Claude and Cursor, the legacy boss-pane environment fallback remains available.
   It prints `session=`, `pane=`, `worktree=`, `slot=`, `agent=`, `boss_pane=`, and `opencode_session=`.
   It appends an explicit report command to the worker prompt. No worker variable inheritance is required.
   It writes the launch command to a private temporary file and types only `bash <file>` into the pane. The file deletes itself when it runs.
   A new shell can still be in canonical tty mode, which drops typed input past 4095 bytes on one line.
   It creates OpenCode sessions at the explicit worktree location, then uses `opencode --session <id> --prompt <text> <worktree>`.
   It does not change permissions, providers, credentials, or global configuration.
   This script bases new worktrees on `origin/main`. For a feature or stacked base, create the correct worktree first.
   Then call `scripts/start-worker.sh --worktree <path>` with the same session, prompt, agent, and boss-pane arguments.
5. **Check the start.** Wait about 20 s. Run `tmux capture-pane -p -t <session>`. The step is done when the worker is at work. The pane can show a prompt first:
   - Claude Code: a folder trust prompt.
   - Cursor: a login prompt or a workspace trust prompt.
   - OpenCode: a login error, a permission request, or a session error.

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

The script adds `From the control session:`. It uses the launcher's registered worker pane, not the active window.
It checks that this pane still runs Claude, Cursor, or OpenCode. It does not redirect a stale target to another pane.
For older sessions without registration, it requires exactly one agent pane. Otherwise, it stops with an error.
Use `scripts/send-to-pane.sh <pane-id> '<text>'` for an explicit target.
Both the text and Enter use the resolved pane ID. A busy worker handles the message when its CLI accepts it.

## V2 checks and tests

Verified with OpenCode V2.2.7 `--help`, `api --help`, and `session --help`.
See the [V2 CLI guide](https://opencode.ai/docs/cli) and [V2 API](https://opencode.ai/docs/api).
The launcher uses `POST /api/session` with an explicit location. It records the returned session ID in tmux options.
The watcher uses `GET /api/session/{sessionID}` and `GET /api/session/active`.
An API error, missing identity, or invalid response returns `UNKNOWN`, not `IDLE`.
These scripts use the default shared service. Custom `--server` and private servers are not supported by this launcher.

Run `bash .skills/assign-work/tests/workers.test.sh` from dotfiles. Tests use mocks; they do not start real workers.
Run `bash -n` and ShellCheck, when installed, on the changed shell files.

An idle pane can show dim suggested text in its input box. Claude Code does this. It is not human input. Never submit it.

## Cleanup

Do this only when the human tells you to:

```bash
tmux kill-session -t <session>
wt remove <branch>
```
