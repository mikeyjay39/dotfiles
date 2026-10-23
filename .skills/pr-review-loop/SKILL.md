---
name: pr-review-loop
description: Runs a review loop on the current PR. A subagent with a clean context reviews the PR. You fix its findings and push. The subagent reviews again until it finds no issues. Use when asked to review-loop a PR, or to iterate on review findings until the PR is clean.
---

# PR Review Loop

The user's instructions:

> Spawn a sub agent with a clear context to review this PR and have it pass its findings to you. Please address the issues the review agent finds, push the code changes, then ask the sub agent to review again. Continue doing this until the sub agent finds no issues.

Write all prose in ASD-STE100 Simplified Technical English. This includes commit messages and the report.
Do not apply STE to code identifiers or quoted text.

## Guardrails

- Work on the PR of the current branch. If there is no open PR, stop and tell the user.
- Commit and push each round of fixes. The user asked for this.
- Do not merge. Do not force-push. Do not change the PR title.
- Update the PR body only when your fixes make it incorrect or incomplete. Keep its structure and change only the parts that the fixes affect.
- The reviewer does not edit files. Only you change the code.

## Steps

### 1. Detect the PR

```bash
gh pr view --json number,url,headRefName,baseRefName,body
git status --short
```

- Record the PR number, the head branch, the base branch and the body.
- If the working tree has changes that are not committed, stop and ask the user what to do with them.

### 2. Spawn the reviewer

Spawn one subagent with a clean context. Do not give it your conversation or your opinions about the code.

- Claude Code: use the Agent tool with the `general-purpose` type. Keep the agent ID for step 6.
- Cursor: use the Task (subagent) tool.

Give the reviewer this brief. Fill in the values:

```text
Review PR #<number> (<url>). The head branch is <headRefName>. The base branch is <baseRefName>.
Read the diff with `gh pr diff <number>`. Read the surrounding code when you need context.
Find correctness bugs, security issues, and clear quality issues. Do not report style preferences.
Do not edit files. Do not commit. Do not post to GitHub.
Return a numbered list. For each finding, give `file:line`, the issue, and why it is a problem.
If you find no issues, return exactly: NO ISSUES
```

### 3. Address the findings

- Read the code at each finding. Make sure that the finding is correct.
- Fix each correct finding.
- If a finding is not correct, do not change the code. Record the finding and the reason.

### 4. Check, commit and push

- Run the checks of the repository that apply to the change: format, lint, typecheck and tests.
- If a check fails, fix it before you commit.
- Commit with a message that says what the fixes do. Push to the head branch.
- Record the new commit SHA.

### 5. Update the PR body

Compare the PR body with the fixes of this round.

- If a fix changes the behavior, the scope, an interface or the steps to verify, update the related text in the body.
- If the body is still correct, do not change it. Go to step 6.

To update the body:

1. Write the current body to a file in a temporary directory: `gh pr view <number> --json body -q .body > <file>`.
2. Edit that file. Keep the sections and the format. Do not rewrite the parts that the fixes do not affect.
3. Apply it: `gh pr edit <number> --body-file <file>`.
4. Record what you changed in the body.

### 6. Ask for a new review

Ask the same reviewer to review again.

- Claude Code: use SendMessage with the agent ID from step 2.
- If the tool cannot continue the reviewer, spawn a new one with the brief from step 2.

In the message, give:

- The new commit SHA.
- The findings that you fixed.
- The findings that you did not fix, and the reason for each one.
- The same output rules: a numbered list, or exactly `NO ISSUES`.

### 7. Repeat

Do steps 3 to 6 again until the reviewer returns `NO ISSUES`.

Stop and ask the user if one of these occurs:

- The loop completes 5 rounds and the reviewer still finds issues.
- The reviewer reports again a finding that you did not fix for a stated reason.

### 8. Report

Tell the user:

- The number of rounds.
- A table of the findings and the fixes, for each round.
- The findings that you did not fix, and the reason for each one.
- The changes to the PR body in each round, or "no change".
- The results of the checks.
- The final commit SHA and the PR URL.
