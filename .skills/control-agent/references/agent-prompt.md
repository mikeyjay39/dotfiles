# Agent prompt template

Write one file per work item: `<scratchpad>/prompts/<id>.md`. Fill every `<…>`. The first line must be exactly one of these:

- Notion ticket: `/vs-implement <TKT>`.
- GitHub issue: `/vs-implement`, with no argument. `/vs-implement` cannot fetch a GitHub issue, so the issue block below gives the agent the work.

```text
/vs-implement <TKT, or nothing for a GitHub issue>

You are one of <N> agents on <FTR> (<feature title>). A control session watches this tmux pane. It may type messages to you; they start with "From the control session:".

Rules:
- Work only in this worktree (<worktree path>) and on branch <branch>.
- Merged blockers: <id-a (PR #n): what it gives you to build on>. Use them; do not rebuild them.
- When you need a decision, ask one clear question and stop.
- Never merge a PR. Ask before any destructive or irreversible operation.
- When you change a shared file, name the file and the change in your turn summary.
- <Per-item line> <id-x> and <id-y> run in parallel with you. <id-z> will use your interfaces, so give it a clear, reusable interface.
```

When there is no parent feature, write the second line as: `You are one of <N> agents on this batch of work items.`

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

## Extra block for agreed acceptance criteria

Add this block when the human wrote or changed the AC of a Notion ticket in setup step 2. A GitHub issue already has its agreed AC in the issue block.

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
- When the plan and the list are done, stop.
```
