export const lifecycleEvents = [
  "session.execution.started",
  "session.execution.succeeded",
  "session.execution.failed",
  "session.execution.interrupted",
  "permission.asked",
  "permission.replied",
  "form.created",
  "form.replied",
  "form.cancelled",
]

const validSession = (id) => typeof id === "string" && /^ses[a-zA-Z0-9_-]+$/.test(id)

// TUI route -> explicit session/pane binding -> existing hook -> existing tmux hints.
// Server events -> exact session match -> serialized hook calls -> same pane only.
export function createLifecycleBridge({ pane, client, generation, run, hook, snapshot, onError }) {
  const sessions = new Map()
  let selected = ""
  let revision = 0
  let pending = Promise.resolve()
  let disposed = false
  const validIdentity = /^%[0-9]+$/.test(pane ?? "") && /^[a-zA-Z0-9_-]+$/.test(client ?? "")
    && typeof generation === "string" && /^[1-9][0-9]*$/.test(generation)

  function enqueue(sessionID, state, quiet, bind = false) {
    const expectedRevision = revision
    pending = pending.then(async () => {
      if (revision !== expectedRevision) return
      const args = [state, "opencode", "--pane", pane, "--session", sessionID, "--client", client, "--generation", generation]
      if (bind) await run(hook, ["bind", ...args.slice(1)])
      if (revision !== expectedRevision) return
      if (quiet) args.push("--quiet")
      await run(hook, args)
    }).catch(() => onError("OpenCode tmux lifecycle update failed"))
  }

  function reconcile(sessionID, emit = true) {
    if (disposed || !sessions.has(sessionID)) return
    try {
      const current = snapshot(sessionID)
      const requests = new Set(current.requests)
      const key = JSON.stringify([current.running, [...requests].sort()])
      const session = sessions.get(sessionID)
      if (key === session.snapshotKey) return
      const before = session.state
      session.snapshotKey = key
      session.requests = requests
      session.state = requests.size ? "needs-input" : current.running ? "running"
        : before === "done" || before === "running" ? "done" : "off"
      if (emit && sessionID === selected && before !== session.state) enqueue(sessionID, session.state, true)
    } catch {
      onError("OpenCode tmux session snapshot failed")
    }
  }

  function select(sessionID) {
    if (!validIdentity || disposed) return
    const next = validSession(sessionID) ? sessionID : ""
    if (next === selected) {
      if (next) reconcile(next)
      return
    }
    const previous = selected
    selected = next
    revision += 1
    if (!next) {
      if (previous) enqueue(previous, "off", true)
      return
    }
    if (!sessions.has(next)) {
      sessions.set(next, { state: "off", requests: new Set(), observedEvents: new Set() })
    }
    reconcile(next, false)
    enqueue(next, sessions.get(next).state, true, true)
  }

  function handle(event) {
    if (disposed || !validIdentity || !lifecycleEvents.includes(event?.type)) return
    if (typeof event.id !== "string" || !event.id) return
    const data = event.data
    const sessionID = event.type === "form.created" ? data?.form?.sessionID : data?.sessionID
    const session = sessions.get(sessionID)
    if (!session || session.observedEvents.has(event.id)) return
    const before = session.state
    switch (event.type) {
      case "session.execution.started":
        session.state = "running"
        session.requests.clear()
        break
      case "session.execution.succeeded":
      case "session.execution.failed":
        session.state = "done"
        session.requests.clear()
        break
      case "session.execution.interrupted":
        session.state = "off"
        session.requests.clear()
        break
      case "permission.asked":
      case "form.created": {
        const id = event.type === "form.created" ? data.form?.id : data.id
        if (typeof id !== "string" || !id) return
        session.requests.add(`${event.type === "form.created" ? "form" : "permission"}:${id}`)
        session.state = "needs-input"
        break
      }
      default: {
        const id = event.type === "permission.replied" ? data?.requestID : data?.id
        const kind = event.type === "permission.replied" ? "permission" : "form"
        if (!session.requests.delete(`${kind}:${id}`)) return
        session.state = session.requests.size ? "needs-input" : "running"
      }
    }
    session.observedEvents.add(event.id)
    const alert = event.type === "session.execution.succeeded" || event.type === "session.execution.failed"
      || event.type === "permission.asked" || event.type === "form.created"
    // Cache updates can precede callbacks. Only event IDs consume lifecycle alerts.
    if (sessionID === selected && (alert || before !== session.state)) enqueue(sessionID, session.state, !alert)
  }

  function dispose() {
    if (disposed) return pending
    const previous = selected
    disposed = true
    selected = ""
    revision += 1
    if (previous) enqueue(previous, "off", true)
    return pending
  }

  return { select, handle, reconcile, dispose, flush: () => pending }
}
