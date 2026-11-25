# OpenCode V2 notes for script changes

Verified with OpenCode V2.2.7 `--help`, `api --help`, and `session --help`.
See the [V2 CLI guide](https://opencode.ai/docs/cli) and the [V2 API](https://opencode.ai/docs/api).

- The launcher uses `POST /api/session` with an explicit location. It records the returned session ID in tmux options.
- The launcher starts the TUI with `opencode --session <id> --prompt <text> <worktree>`. The TUI has no `--model` option.
- The watcher uses `GET /api/session/{sessionID}` and `GET /api/session/active`.
- An API error, a missing identity, or an invalid response returns `UNKNOWN`, not `IDLE`.
- These scripts use the default shared service. The launcher does not support a custom `--server` or a private server.
- OpenCode tool shells run on the shared server. They need not inherit tmux or per-worker variables, so pass `--agent opencode` and an explicit `--boss-pane`.

## Launch notes for all CLIs

- The launcher writes the launch command to a private temporary file and types only `bash <file>` into the pane. The file deletes itself when it runs. A new shell can still be in canonical tty mode, which drops typed input past 4095 bytes on one line.
- For Claude and Cursor, the legacy boss-pane environment fallback stays available.

## Tests

Run `bash .skills/assign-work/tests/workers.test.sh` from dotfiles. The tests use mocks; they do not start real workers.
Run `bash -n` and ShellCheck, when installed, on the changed shell files.
