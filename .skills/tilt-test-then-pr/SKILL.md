---
name: tilt-test-then-pr
description: Tests the current branch in its own Tilt environment, posts proof to the ticket that the changes work, then opens a PR if all is OK. Use when asked to Tilt-test a branch and open a PR, or to prove a change on Tilt before you ship it.
---

# Tilt Test Then PR

The user's instructions:

> Please test this in its own Tilt environment and post proof to the ticket that the changes work. If everything is OK then open a PR for this branch

Write all prose in ASD-STE100 Simplified Technical English. This includes the ticket comment, the PR text and the report.
Do not apply STE to code identifiers or quoted text.

## Guardrails

- Use a Tilt environment only for this branch. Do not use or stop a Tilt session of a different branch or worktree.
- If a test fails, do not open the PR. Stop and tell the user.
- Do not merge.

## Steps

### 1. Find the branch and the ticket

```bash
git branch --show-current
git log --oneline <base>..HEAD
```

- Find the ticket ID (for example `TKT-123`) in the branch name or the commit messages.
- If you cannot find a ticket, ask the user.
- Read the ticket. Record what the change must do.

### 2. Start an isolated Tilt environment

- Read the `Tiltfile` and the repo docs. If they define a method for an isolated environment, use it.
- If not, start Tilt from the branch worktree on a free port: `tilt up --port <free port>`.
- Wait until all resources are healthy. Use `tilt get uiresources --port <port>` and `tilt logs --port <port>`.
- If a resource does not become healthy, stop and tell the user.

### 3. Test the change

- Use the running system to show that the change does what the ticket requires. Use `/vs-verify` if it is available.
- Collect proof: commands and their output, logs, API responses and screenshots.
- A passing unit test alone is not proof.

### 4. Post the proof to the ticket

- Post the proof as a comment on the ticket. For Valstro Notion tickets, use `/vs-notion`.
- Include the branch, the commit SHA, the steps, and the results.
- Record the comment link.

### 5. Open the PR

Do this step only if all tests pass.

- Use `/vs-ship` if it is available. If not, use `gh pr create`.
- Link the ticket in the PR body.

### 6. Stop Tilt

- Run `tilt down --port <port>` for the environment that you started.

### 7. Report

Tell the user:

- The test results.
- The ticket comment link.
- The PR URL, or the reason that you did not open a PR.
