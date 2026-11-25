# After a restart of the controller

Use this when the controller session starts again while workers still run.

1. Check the background tasks and the temporary files. Keep scripts in the skill folder, not in the scratchpad.
2. Run `<skills-dir>/control-agent/scripts/status.sh`. It lists each registered worker, its CLI, its state, and its last report.
3. For each worker that waits, run `<skills-dir>/assign-work/scripts/last-turn.sh <session>`.
4. Keep the recorded OpenCode session IDs.
5. Check the runs and the PRs.
6. Start the watches again.
