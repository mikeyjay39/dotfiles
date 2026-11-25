Hard limits. They apply to every step of this run:
- Never merge a PR. Do not run `gh pr merge`.
- Never push. The run script pushes. Never force-push.
- Do no destructive or irreversible operation. Examples: delete a branch or data, `rm -rf`, `git reset --hard`, deploy, change a secret, rewrite history.
- Do not call out to the network except to run the repo's own tools (package install, test, build, local servers).
- Work only in the current worktree, and in the run folder when this prompt names it.
- Nobody can answer a question during this run. Never ask. Decide, and record the decision.
