# Worker prompt template

Write one file per work item: `<scratchpad>/prompts/<id>.md`. Fill every `<…>`. Remove the lines that do not apply.

## First line

Find the mode. The repo is in **SDLC mode** when its root `AGENTS.md` has a `## SDLC` heading:

```bash
grep -q '^## SDLC' "$(git rev-parse --show-toplevel)/AGENTS.md" 2>/dev/null && echo sdlc
```

Then write the first line from this table:

| Mode     | Work item     | Claude worker              | Cursor worker                                                      |
| -------- | ------------- | -------------------------- | ------------------------------------------------------------------ |
| SDLC     | Notion ticket | `/vs-implement <TKT>`      | `Use the vs-implement skill on <TKT>.`                             |
| SDLC     | Issue or text | `/vs-implement`            | `Use the vs-implement skill on the work item below.`               |
| Not SDLC | Any           | `Implement the work item below. Test it. Then open a PR.` | Same as Claude.                       |

For OpenCode, use the Cursor column. Ask it to load the named skill; do not assume Claude slash-command syntax.
Use the selected worker CLI, which can differ from the boss CLI.
`/vs-implement` cannot fetch a GitHub issue or read free text, so the work block below gives the worker the work.

The launcher appends a report command with the explicit worker name and boss pane ID.
OpenCode tool shells use a shared server. They need not inherit tmux or per-worker variables.
For a manual launch, fill the command below with absolute paths and explicit IDs.

## Body

```text
<first line>

You are a worker agent. A control session coordinates you and other workers. It may type messages to you; they start with "From the control session:".

Report to the control session with this shell command. Send one line each time:
  <absolute-skill-dir>/scripts/report-to-boss.sh --session <worker-session> --boss-pane <boss-pane-id> "<kind>: <text>"
Use the exact command appended by the launcher. Do not infer identity from `TMUX_PANE` or worker variables.
Send a report only at these points, because each report interrupts the control session.
Each report is one line. Make it complete, so that the control session can act without reading your screen:
- "started: <your plan in one line>" when you know your plan.
- "question: <the question>. Options: A) <option>; B) <option>. I recommend <A or B>, because <reason>. It touches <AC, AD###, file, or interface>." when you need a decision. Then stop and wait.
- "blocked: <reason>. To unblock: <what you need>." when you cannot continue.
- "pr: <url>" when you open a PR.
- "done: <summary>. CI: <state>." when the work is complete, or when CI passes on your PR.

Rules:
- Work only in this worktree (<worktree path>) and on branch <branch>.
- Merged blockers: <id-a (PR #n): what it gives you to build on>. Use them; do not rebuild them.
- Never merge a PR. Ask before any destructive or irreversible operation.
- When you change a shared file, name the file and the change in your turn summary.
- <Per-item line> <id-x> and <id-y> run in parallel with you. <id-z> will use your interfaces, so give it a clear, reusable interface.
```

When the control session runs a batch on a feature, add this line after the first paragraph: `You are one of <N> workers on <FTR> (<feature title>).`

## Extra block for a GitHub issue

Add this block after the rules:

```text
Your work item is GitHub issue #<n>: <title>
URL: <issue url>

Summary of the issue:
<the body, in short; keep each requirement>

Acceptance criteria. They are the contract. Build against them, not against a paraphrase:
- <AC 1>
- <AC 2>

Put "Closes #<n>" in the PR body.
```

## Extra block for a free-text work item

Add this block after the rules. Copy the description word for word:

```text
Your work item:
<description>

Acceptance criteria:
- <AC 1, when the control session has some>
```

## Extra block for agreed acceptance criteria

Add this block when the human wrote or changed the AC of a Notion ticket. A GitHub issue and a free-text item already have their AC in their own block.

```text
The human agreed these acceptance criteria. They replace the criteria in the ticket:
- <AC 1>
- <AC 2>
```

## Extra block for a work item with unmerged blockers

Add this block after the rules:

```text
Your blockers are not merged: <id-a>, <id-b>.
- Read and plan only.
- List what you need from each blocker: functions, types, files, behavior.
- Write NO production code until the control session tells you the blockers are ready.
- When the plan and the list are done, report "blocked: plan done, waiting for <id-a>, <id-b>" and stop.
```
