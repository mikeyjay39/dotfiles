# Agent prompt template

Write one file per ticket: `<scratchpad>/prompts/<TKT>.md`. Fill every `<…>`. Keep the first line exactly `/vs-implement <TKT>`.

```text
/vs-implement <TKT>

You are one of <N> agents on <FTR> (<feature title>). A control session watches this tmux pane. It may type messages to you; they start with "From the control session:".

Rules:
- Work only in this worktree (<worktree path>) and on branch <branch>.
- Merged blockers: <TKT-a (PR #n): what it gives you to build on>. Use them; do not rebuild them.
- When you need a decision, ask one clear question and stop.
- Never merge a PR. Ask before any destructive or irreversible operation.
- When you change a shared file, name the file and the change in your turn summary.
- <Per-ticket line> <TKT-x> and <TKT-y> run in parallel with you. <TKT-z> will use your interfaces, so give it a clear, reusable interface.
```

## Extra block for a ticket with unmerged blockers

Add this block after the rules:

```text
Your blockers are not merged: <TKT-a>, <TKT-b>.
- Read and plan only.
- List what you need from each blocker: functions, types, files, behavior.
- Write NO production code until the control session tells you the blockers are ready.
- When the plan and the list are done, stop.
```
