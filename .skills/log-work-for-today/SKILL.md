---
name: log-work-for-today
description: Adds today's git and GitHub work to the "# Log" section of a markdown note — branches worked on, PRs opened, updated or merged, and PRs reviewed — as linked checkbox bullets. Takes the path to the markdown file. Use when asked to log today's work, or to fill in the Log of a daily note.
---

# Log Work For Today

The user gives the path to a markdown file. In Claude Code it is in `$ARGUMENTS`. In Cursor it is in the user's message.

- If there is no path, ask the user for it.
- If the file does not exist, stop and tell the user.

Write all prose in ASD-STE100 Simplified Technical English. Do not apply STE to PR titles, branch names or other quoted text.

## Guardrails

- Change only the `# Log` section of the file. Keep all other text as it is.
- Do not remove bullets that the user wrote by hand.
- Do not push, comment, review or change a repo or a PR. Only read.

## Steps

### 1. Set the day and the user

```bash
date +%Y-%m-%d                    # today, local time
date -d today +%Y-%m-%dT00:00:00%:z  # start of today, local time
gh api user -q .login
git config --global user.email
```

- "Today" is the local date. GitHub gives times in UTC. Convert each GitHub time to local time before you compare it to today.

### 2. Find local branches with commits today

The repos are under `~/repos/`. Some directories are worktrees of the same repo.

For each directory in `~/repos/*` that is a git repo or worktree:

```bash
git -C <dir> remote get-url origin       # gives <owner>/<repo>
git -C <dir> for-each-ref refs/heads --format='%(refname:short)'
git -C <dir> log <branch> --author=<email> --since=<start of today> --oneline --not origin/<default branch>
```

- Get the default branch with `git -C <dir> symbolic-ref --short refs/remotes/origin/HEAD`.
- Keep each branch that has one or more commits today.
- Remove duplicates by `<owner>/<repo>` and branch name. Worktrees share branches.

### 3. Find my PRs with activity today

Search from yesterday, because GitHub search dates are UTC. Then filter on local time.

```bash
gh search prs --author=@me --updated=">=<yesterday>" --limit 100 \
  --json url,title,state,number,createdAt,closedAt,updatedAt,repository
```

- `state` is `open`, `closed` or `merged`.
- Keep a PR if it was created, merged or updated today.
- Also find the PR for each branch from step 2: `gh pr list -R <owner>/<repo> --head <branch> --state all --json url,title,state,createdAt,mergedAt`.

### 4. Find PRs I reviewed today

```bash
gh search prs --reviewed-by=@me --updated=">=<yesterday>" --limit 100 \
  --json url,title,state,number,author,repository
gh api repos/<owner>/<repo>/pulls/<number>/reviews --paginate \
  -q '.[] | select(.user.login == "<login>") | {state, submitted_at}'
```

- Keep a PR only if I submitted a review on it today.
- Do not include my own PRs here. They are in step 3.

### 5. Make one bullet per task

Use the PR title as is. Link each bullet to the PR URL.

| Task | Bullet |
| --- | --- |
| I reviewed a PR | `- [ ] [PR review <title>](<url>)` |
| My PR, created today, merged today | `- [x] [PR opened and merged <title>](<url>)` |
| My PR, created today, not merged | `- [ ] [PR opened <title>](<url>)` |
| My PR, created before today, merged today | `- [x] [PR merged <title>](<url>)` |
| My PR, created before today, updated today | `- [ ] [PR updated <title>](<url>)` |
| My branch with no PR | `- [ ] [Branch <branch> in <repo>](https://github.com/<owner>/<repo>/tree/<branch>)` |

- If a branch with no PR is not on the remote (`git ls-remote --heads origin <branch>` is empty), write it with no link: `- [ ] Branch <branch> in <repo>`.
- A branch that has a PR gets only the PR bullet.

### 6. Set the checkbox

- `[x]`: the task is complete. A PR is merged, or a branch is merged into the default branch.
- `[x]` for a review: the PR is merged or closed, or my last review today is `APPROVED`.
- `[ ]`: all other tasks. They are in progress.

### 7. Write the Log section

- Find the line that is exactly `# Log`. Only a level 1 header counts. `## Log` does not count.
- If there is no `# Log` line, add a blank line and `# Log` to the end of the file.
- The section ends at the next level 1 header, or at the end of the file.
- A bullet in the section matches a new bullet when it has the same URL. Replace a matching bullet with the new bullet. This updates the checkbox and the verb.
- Add the other new bullets to the end of the section in this order: reviews, then my PRs, then branches with no PR.
- Keep all other lines in the section.

### 8. Report

Tell the user which bullets you added and which bullets you updated. If a command failed (for example `gh` is not logged in), tell the user which data is missing.
