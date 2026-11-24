# Agent state and hints

Claude, Cursor, and OpenCode use the same `@agent-state` and `@agent-name` options.
The shared hook is `.cursor/hooks/agent-tmux.sh`.
Claude and Cursor keep their current hook settings and behavior.
OpenCode uses the existing Cursor app icon. Claude keeps its own icon.

The state colors, jump order, status-line rules, and tree hints do not change:

- `running`: yellow activity icon; no completion notification.
- `needs-input`: red warning icon; critical notification and warning sound.
- `done`: check mark; normal notification and completion sound.
- `off`: no state icon or notification.
- Prefix + `a`: first pane that needs input, then first done pane.
- Show the second status line for an agent in another session or an open session tree.
- Keep the existing tree keys and their hint text.

## OpenCode V2 bridge

The TUI plugin is `.config/opencode/plugins/tmux-agent/`.
V2 discovers plugin directories under the global OpenCode config directory.
The existing dotfiles installation uses Stow for `.config`.
The human must install or link this plugin directory after review.
Do not overwrite an existing plugin directory, `cli.json`, or `opencode.json`.
No provider, permission, or credential changes are needed.
Do not install or reload the live configuration during worker tests.

The plugin runs in the local TUI, not in the shared server.
It captures the TUI pane ID and reads the displayed session from the documented router API.
It writes `@opencode-binding` on that pane as `<session-id>|<generation>|<client-token>`.
Each hook call passes the pane, session, generation, and client token explicitly.
The hook checks the binding before notifications or state writes.
It does not search other panes or use shared-server worker variables.
The client token prevents an old plugin instance from clearing a newer instance's state.
Each client captures its generation from the local monotonic clock before it queues commands.
Under the pane lock, a bind rejects older generations and another client's equal generation.
An old bind cannot replace a newer owner even if the old command gets the lock later.
The hook uses a per-pane `flock` for both binding and state updates.
This prevents a new binding from interrupting an old hook between its identity check and state write.

| V2 event | Existing tmux state |
| --- | --- |
| `session.execution.started` | `running` |
| `permission.asked`, `form.created` | `needs-input` |
| `permission.replied`, `form.replied`, `form.cancelled` | `running` after all pending requests close |
| `session.execution.succeeded`, `session.execution.failed` | `done` |
| `session.execution.interrupted` | `off`, without a completion alert |

Events affect only their exact session. Unknown sessions and unrelated events do not change pane state.
The plugin remembers state for sessions displayed during its lifetime.
On a session switch, it restores that session's state without another notification.
An initial session synchronizes session, permission, and form data through the V2 TUI data APIs.
The TUI status cache uses `"running"` and `"idle"` strings, not the HTTP session-status object shape.
The plugin reads these caches on every relevant effect, including effects for the same displayed session.
It reconciles changed cache state quietly. A known completion keeps its `done` state when the cache becomes idle.
Displayed cache state does not consume lifecycle notifications.
Completion, permission, and form events send their alerts even if cache reconciliation already displayed that state.
The bridge tracks public V2 event IDs separately. Duplicate delivery of an event does not repeat its alert.
An idle session with no observed completion starts as `off`.
Home, plugin cleanup, and an interrupted execution use `off` without a completion alert.
Hook or tmux errors do not stop OpenCode. The plugin logs a fixed error message without event contents.

The hook accepts this explicit form for OpenCode only:

```text
agent-tmux.sh <state> opencode --pane <pane-id> --session <session-id> --client <token> --generation <number> [--quiet]
```

`--quiet` restores hints without repeating desktop or tmux notifications.
The bridge first calls this command with `bind` instead of a lifecycle state.
That call registers identity only. It does not change hints or send notifications.
Do not call this form from a shared-server tool shell with inferred pane identity.
The TUI bridge owns the binding.

## Sources and tests

Read the V2 [plugin overview](https://opencode.ai/docs/build/plugins),
[TUI API](https://opencode.ai/docs/build/plugins/cli),
[server lifecycle and events](https://opencode.ai/docs/build/plugins/server),
and [plugin discovery](https://opencode.ai/docs/cli/plugins) before changing the integration.
Event names and payloads come from the [V2 OpenAPI document](https://opencode.ai/docs/openapi.json).

```bash
node --test .config/tmux/tests/*.test.mjs
bash .config/tmux/tests/hooks.test.sh
bash .skills/assign-work/tests/workers.test.sh
```

Tests use mocks. They do not load tmux config, start agents, or restart sessions.
Run `bash -n` on changed shell files and `node --check` on plugin and test JavaScript.
Run ShellCheck when installed. Keep prior worker-skill tests green.
