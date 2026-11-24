# Global skill changes

Edit canonical files in `.skills`. `.claude/skills` and `.cursor/skills` are symlinks.
Do not edit live global scripts during an isolated worker task.

Worker scripts support Claude, Cursor, and OpenCode V2. Check installed help and V2 docs before changing flags.
Do not change global permissions, providers, or credentials to start workers.
OpenCode uses a shared server. Put explicit worker identity and the boss pane in each report command.
Register the worker pane and OpenCode session ID in tmux session options.
Do not send messages to a session's active window. Reject absent or ambiguous agent targets.
Do not report OpenCode idle from terminal text alone. API failures must return `UNKNOWN`.
Keep the three-active-worker cap and repository-specific stack limits.
Keep feature and stacked PR bases explicit. Do not merge PRs or bypass repository database and destructive-operation rules.

Run `bash .skills/assign-work/tests/workers.test.sh` after worker-script changes.
Run `bash -n` and ShellCheck, when available, on the changed shell files.
Tests must use mocks. Do not start real implementer agents for tests.
