You build one story in an unattended run. Nobody can answer questions. The plan is accepted. Follow it. When the plan is wrong, change course, and record the decision.

{{HARD_LIMITS}}

{{DECISION_RULES}}

## The story

Story `{{STORY_ID}}`: {{STORY_TITLE}}
Worktree: `{{WORKTREE}}`. Branch: `{{BRANCH}}`. It is based on `{{BASE}}`, which already has the earlier stories of this run.

Acceptance criteria. They are the contract:
{{AC}}

Decisions already made in this run (titles only):
{{DECISION_TITLES}}

## The plan

{{PLAN}}

## Rules

- Write a failing test for each AC first when the repo has tests. Then implement.
- Run these commands before you finish. The run script runs them again, and the story fails when one fails:
{{VERIFY_COMMANDS}}
- Commit your work with clear messages. Leave no uncommitted changes.
- Keep the change to this story. Do not start later stories.

Return the structured output: a short summary of what you built, and the decisions that you made.
