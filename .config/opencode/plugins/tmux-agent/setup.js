import { execFile } from "node:child_process"
import { randomUUID } from "node:crypto"
import { homedir } from "node:os"
import { join } from "node:path"
import { createLifecycleBridge, lifecycleEvents } from "./lifecycle.js"

export function runCommand(file, args) {
  return new Promise((resolve, reject) => {
    const child = execFile(file, args, { timeout: 3000 }, (error) => error ? reject(error) : resolve())
    child.stdin?.end()
  })
}

// The TUI owns this environment. Never read pane identity from the shared server.
export function setupTmuxAgent(context, effect, options = {}) {
  const pane = options.pane ?? process.env.TMUX_PANE
  if (!/^%[0-9]+$/.test(pane ?? "")) return () => {}
  const onError = options.onError ?? ((message) => console.error(message))
  const bridge = createLifecycleBridge({
    pane,
    client: options.client ?? randomUUID(),
    // A local monotonic clock orders owners before their asynchronous bind commands start.
    generation: options.generation ?? process.hrtime.bigint().toString(),
    run: options.run ?? runCommand,
    hook: options.hook ?? join(homedir(), ".cursor/hooks/agent-tmux.sh"),
    onError,
    snapshot(sessionID) {
      const status = context.data.session.status(sessionID)
      const permissions = context.data.session.permission.list(sessionID) ?? []
      const forms = context.data.session.form.list(sessionID, context.location) ?? []
      return {
        running: status === "running",
        requests: [...permissions.map((request) => `permission:${request.id}`), ...forms.map((form) => `form:${form.id}`)],
      }
    },
  })
  const stops = lifecycleEvents.map((type) => context.data.on(type, (event) => bridge.handle(event)))
  let displayed
  function synchronize(sessionID) {
    void Promise.resolve().then(() => Promise.all([
      context.data.session.sync(sessionID),
      context.data.session.permission.sync(sessionID),
      context.data.session.form.sync(sessionID, context.location),
    ])).then(() => bridge.reconcile(sessionID))
      .catch(() => onError("OpenCode tmux session synchronization failed"))
  }
  const removeSlot = context.ui.slot({
    append: "app",
    render() {
      effect(() => {
        const route = context.ui.router.current()
        const sessionID = route.type === "session" ? route.sessionID : undefined
        bridge.select(sessionID)
        if (sessionID !== displayed) {
          displayed = sessionID
          if (sessionID) synchronize(sessionID)
        }
      })
      return null
    },
  })
  return () => {
    stops.forEach((stop) => stop())
    removeSlot()
    return bridge.dispose()
  }
}
