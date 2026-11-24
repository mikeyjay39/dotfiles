import assert from "node:assert/strict"
import { readFile } from "node:fs/promises"
import test from "node:test"
import { createLifecycleBridge, lifecycleEvents } from "../../opencode/plugins/tmux-agent/lifecycle.js"
import { runCommand, setupTmuxAgent } from "../../opencode/plugins/tmux-agent/setup.js"

function fixture(options = {}) {
  const calls = []
  const errors = []
  const bridge = createLifecycleBridge({
    pane: "%7", client: "client-a", generation: "100", hook: "/mock/agent-tmux.sh",
    run: async (file, args) => { calls.push({ file, args }) },
    snapshot: () => ({ running: false, requests: [] }),
    onError: (message) => errors.push(message),
    ...options,
  })
  return { bridge, calls, errors, states: () => calls.filter(({ args }) => args[0] !== "bind").map(({ args }) => args[0]) }
}

let eventNumber = 0
const event = (type, sessionID = "ses_a", extra = {}) => ({ id: `evt_${++eventNumber}`, type, data: { sessionID, ...extra } })

test("bind the displayed session and pass explicit identity despite server variables", async () => {
  const { bridge, calls } = fixture()
  bridge.select("ses_a")
  bridge.handle(event("session.execution.started"))
  await bridge.flush()
  assert.deepEqual(calls[0], { file: "/mock/agent-tmux.sh", args: ["bind", "opencode", "--pane", "%7", "--session", "ses_a", "--client", "client-a", "--generation", "100"] })
  assert.deepEqual(calls[2].args, ["running", "opencode", "--pane", "%7", "--session", "ses_a", "--client", "client-a", "--generation", "100", "--quiet"])
  assert.equal(calls[1].args.at(-1), "--quiet")
})

test("two concurrent sessions update only their own panes", async () => {
  const a = fixture()
  const b = fixture({ pane: "%8", client: "client-b" })
  a.bridge.select("ses_a")
  b.bridge.select("ses_b")
  const events = [event("session.execution.started"), event("permission.asked", "ses_b", { id: "p1" })]
  for (const item of events) { a.bridge.handle(item); b.bridge.handle(item) }
  await Promise.all([a.bridge.flush(), b.bridge.flush()])
  assert.deepEqual(a.states(), ["off", "running"])
  assert.deepEqual(b.states(), ["off", "needs-input"])
  assert.ok(a.calls.every(({ args }) => !args.includes("%8")))
  assert.ok(b.calls.every(({ args }) => !args.includes("%7")))
})

for (const [type, state] of [
  ["session.execution.succeeded", "done"],
  ["session.execution.failed", "done"],
  ["session.execution.interrupted", "off"],
]) {
  test(`${type} uses the existing ${state} state`, async () => {
    const f = fixture()
    f.bridge.select("ses_a")
    f.bridge.handle(event("session.execution.started"))
    f.bridge.handle(event(type))
    await f.bridge.flush()
    assert.deepEqual(f.states(), ["off", "running", state])
  })
}

test("permissions and forms keep needs-input until every request closes", async () => {
  const f = fixture()
  f.bridge.select("ses_a")
  f.bridge.handle(event("session.execution.started"))
  f.bridge.handle(event("permission.asked", "ses_a", { id: "p1" }))
  f.bridge.handle(event("form.created", "ses_a", { form: { id: "f1", sessionID: "ses_a" } }))
  f.bridge.handle(event("permission.replied", "ses_a", { requestID: "p1" }))
  await f.bridge.flush()
  assert.deepEqual(f.states(), ["off", "running", "needs-input", "needs-input"])
  f.bridge.handle(event("form.replied", "ses_a", { id: "f1" }))
  await f.bridge.flush()
  assert.equal(f.states().at(-1), "running")
})

test("cancelled form resumes only its own request", async () => {
  const f = fixture()
  f.bridge.select("ses_a")
  f.bridge.handle(event("form.created", "ses_a", { form: { id: "f1", sessionID: "ses_a" } }))
  f.bridge.handle(event("form.cancelled", "ses_a", { id: "unrelated" }))
  f.bridge.handle(event("form.cancelled", "ses_a", { id: "f1" }))
  await f.bridge.flush()
  assert.deepEqual(f.states(), ["off", "needs-input", "running"])
})

test("ignore malformed events, unrelated sessions, and duplicate state events", async () => {
  const f = fixture()
  f.bridge.select("ses_a")
  for (const item of [null, {}, { type: "permission.asked" }, event("unknown"), event("session.execution.started", "ses_b"), event("permission.asked")]) f.bridge.handle(item)
  f.bridge.handle(event("session.execution.started"))
  f.bridge.handle(event("session.execution.started"))
  await f.bridge.flush()
  assert.deepEqual(f.states(), ["off", "running"])
})

test("route changes discard queued writes for the old session", async () => {
  const f = fixture()
  f.bridge.select("ses_a")
  f.bridge.handle(event("session.execution.started"))
  f.bridge.select("ses_b")
  await f.bridge.flush()
  assert.equal(f.calls.length, 2)
  assert.equal(f.calls[0].args[0], "bind")
  assert.ok(f.calls[0].args.includes("ses_b"))
  assert.ok(f.calls.every(({ args }) => !args.includes("ses_a")))
})

test("background tracked sessions restore their latest state without another alert", async () => {
  const f = fixture()
  f.bridge.select("ses_a")
  await f.bridge.flush()
  f.bridge.select("ses_b")
  f.bridge.handle(event("session.execution.succeeded", "ses_a"))
  await f.bridge.flush()
  f.bridge.select("ses_a")
  await f.bridge.flush()
  assert.equal(f.states().at(-1), "done")
  assert.equal(f.calls.at(-1).args.at(-1), "--quiet")
})

test("a route change during binding cannot send an old-session notification", async () => {
  const calls = []
  let release
  const gate = new Promise((resolve) => { release = resolve })
  const f = fixture({
    run: async (file, args) => {
      calls.push({ file, args })
      if (args[0] === "bind" && args.includes("ses_a")) await gate
    },
  })
  f.bridge.select("ses_a")
  f.bridge.handle(event("session.execution.succeeded"))
  await new Promise(setImmediate)
  f.bridge.select("ses_b")
  release()
  await f.bridge.flush()
  const hooks = calls.filter(({ args }) => args[0] !== "bind")
  assert.equal(hooks.length, 1)
  assert.ok(hooks[0].args.includes("ses_b"))
})

test("home and cleanup clear hints quietly and stop later writes", async () => {
  const f = fixture()
  f.bridge.select("ses_a")
  await f.bridge.flush()
  f.bridge.select(undefined)
  await f.bridge.flush()
  assert.equal(f.states().at(-1), "off")
  assert.equal(f.calls.at(-1).args.at(-1), "--quiet")
  f.bridge.select("ses_b")
  await f.bridge.flush()
  await f.bridge.dispose()
  const count = f.calls.length
  f.bridge.handle(event("session.execution.started", "ses_b"))
  f.bridge.select("ses_a")
  await f.bridge.dispose()
  assert.equal(f.calls.length, count)
  assert.ok(f.calls.at(-1).args.includes("ses_b"))
})

for (const options of [{ pane: "%7;bad" }, { pane: "" }, { client: "bad|token" }, { generation: "01" }]) {
  test(`invalid local identity makes no calls: ${JSON.stringify(options)}`, async () => {
    const f = fixture(options)
    f.bridge.select("ses_a")
    f.bridge.handle(event("session.execution.started"))
    await f.bridge.dispose()
    assert.deepEqual(f.calls, [])
  })
}

test("invalid session ID cannot bind a pane", async () => {
  const f = fixture()
  f.bridge.select("ses_a;bad")
  await f.bridge.flush()
  assert.deepEqual(f.calls, [])
})

test("cached running and pending states restore quietly", async () => {
  for (const [snapshot, expected] of [
    [{ running: true, requests: [] }, "running"],
    [{ running: true, requests: ["permission:p1", "form:f1"] }, "needs-input"],
  ]) {
    const f = fixture({ snapshot: () => snapshot })
    f.bridge.select("ses_a")
    await f.bridge.flush()
    assert.deepEqual(f.states(), [expected])
    assert.equal(f.calls.at(-1).args.at(-1), "--quiet")
  }
})

test("same-session effects reconcile a cache that populates after attachment", async () => {
  let cache = { running: false, requests: [] }
  const f = fixture({ snapshot: () => cache })
  f.bridge.select("ses_a")
  await f.bridge.flush()
  assert.deepEqual(f.states(), ["off"])
  cache = { running: true, requests: [] }
  f.bridge.select("ses_a")
  await f.bridge.flush()
  assert.equal(f.states().at(-1), "running")
  cache = { running: true, requests: ["permission:p1"] }
  f.bridge.select("ses_a")
  await f.bridge.flush()
  assert.equal(f.states().at(-1), "needs-input")
  assert.equal(f.calls.filter(({ args }) => args[0] === "bind").length, 1)
  assert.equal(f.calls.at(-1).args.at(-1), "--quiet")
})

test("cache reconciliation preserves a known completion without another alert", async () => {
  let cache = { running: true, requests: [] }
  const f = fixture({ snapshot: () => cache })
  f.bridge.select("ses_a")
  f.bridge.handle(event("session.execution.succeeded"))
  await f.bridge.flush()
  cache = { running: false, requests: [] }
  f.bridge.select("ses_a")
  await f.bridge.flush()
  assert.deepEqual(f.states(), ["running", "done"])
})

for (const order of ["cache-first", "event-first"]) {
  for (const [type, request, target] of [
    ["session.execution.succeeded", undefined, "done"],
    ["session.execution.failed", undefined, "done"],
    ["permission.asked", "permission:p1", "needs-input"],
    ["form.created", "form:f1", "needs-input"],
  ]) {
    test(`${type} sends one alert with ${order} callback order and duplicate delivery`, async () => {
      let cache = { running: true, requests: [] }
      const f = fixture({ snapshot: () => cache })
      f.bridge.select("ses_a")
      await f.bridge.flush()
      const item = event(type, "ses_a", type === "form.created"
        ? { form: { id: "f1", sessionID: "ses_a" } } : request ? { id: "p1" } : {})
      const alerts = () => f.calls.filter(({ args }) => args[0] === target && !args.includes("--quiet"))
      const populateCache = () => {
        cache = { running: Boolean(request), requests: request ? [request] : [] }
        f.bridge.select("ses_a")
      }
      if (order === "cache-first") {
        populateCache()
        await f.bridge.flush()
        assert.equal(f.states().at(-1), target)
        assert.equal(alerts().length, 0, "quiet reconciliation must not send an alert")
      }
      f.bridge.handle(item)
      f.bridge.handle(item)
      if (order === "event-first") populateCache()
      await f.bridge.flush()
      assert.equal(alerts().length, 1)
      f.bridge.select("ses_a")
      f.bridge.handle(item)
      await f.bridge.flush()
      assert.equal(alerts().length, 1, "the same event ID must not send another alert")
    })
  }
}

test("separate lifecycle event IDs each send one alert even with unchanged displayed state", async () => {
  const f = fixture()
  f.bridge.select("ses_a")
  const first = event("permission.asked", "ses_a", { id: "p1" })
  const second = event("permission.asked", "ses_a", { id: "p2" })
  for (const item of [first, first, second, second]) f.bridge.handle(item)
  await f.bridge.flush()
  const alerts = f.calls.filter(({ args }) => args[0] === "needs-input" && !args.includes("--quiet"))
  assert.equal(alerts.length, 2)
})

test("snapshot and command errors are contained without event contents", async () => {
  const f = fixture({ snapshot: () => { throw new Error("private data") } })
  f.bridge.select("ses_a")
  await f.bridge.flush()
  assert.deepEqual(f.errors, ["OpenCode tmux session snapshot failed"])
  const broken = fixture({ run: async () => { throw new Error("private data") } })
  broken.bridge.select("ses_a")
  await broken.bridge.flush()
  broken.bridge.handle(event("session.execution.started"))
  await broken.bridge.flush()
  assert.deepEqual(broken.errors, ["OpenCode tmux lifecycle update failed", "OpenCode tmux lifecycle update failed"])
})

test("runCommand closes hook stdin and contains process failures", async () => {
  await runCommand(process.execPath, ["-e", "process.stdin.resume(); process.stdin.on('end', () => process.exit(0))"])
  await assert.rejects(runCommand(process.execPath, ["-e", "process.exit(1)"]))
  await assert.rejects(runCommand("/missing/tmux-agent-command", []))
})

test("TUI setup uses documented routes and event payloads, then unsubscribes", async () => {
  const listeners = new Map()
  const calls = []
  let route = { type: "session", sessionID: "ses_a" }
  let updateRoute
  let removed = false
  const context = {
    location: { directory: "/worktree" },
    data: {
      on(type, listener) { listeners.set(type, listener); return () => listeners.delete(type) },
      session: { sync: async () => {}, status: () => "running", permission: { sync: async () => {}, list: () => [] }, form: { sync: async () => {}, list: () => [] } },
    },
    ui: {
      router: { current: () => route },
      slot({ append, render }) { assert.equal(append, "app"); render(); return () => { removed = true } },
    },
  }
  const cleanup = setupTmuxAgent(context, (effect) => { updateRoute = effect; effect() }, {
    pane: "%7", client: "test-client", hook: "/mock/hook", run: async (file, args) => calls.push({ file, args }),
  })
  assert.deepEqual([...listeners.keys()], lifecycleEvents)
  await new Promise(setImmediate)
  assert.equal(calls.at(-1).args[0], "running")
  listeners.get("permission.asked")(event("permission.asked", "ses_a", { id: "p1" }))
  await new Promise(setImmediate)
  assert.equal(calls.at(-1).args[0], "needs-input")
  route = { type: "session", sessionID: "ses_b" }
  updateRoute()
  await new Promise(setImmediate)
  assert.ok(calls.at(-1).args.includes("ses_b"))
  await cleanup()
  assert.equal(listeners.size, 0)
  assert.equal(removed, true)
})

test("initial data synchronization reconciles delayed cache without a route change", async () => {
  let ready = false
  let finishSync
  const syncGate = new Promise((resolve) => { finishSync = resolve })
  const calls = []
  const synced = []
  const context = {
    location: { directory: "/worktree" },
    data: {
      on: () => () => {},
      session: {
        async sync(id) { synced.push(`session:${id}`); await syncGate; ready = true },
        status: () => ready ? "running" : "idle",
        permission: { async sync(id) { synced.push(`permission:${id}`); await syncGate }, list: () => ready ? [{ id: "p1" }] : [] },
        form: { async sync(id) { synced.push(`form:${id}`); await syncGate }, list: () => [] },
      },
    },
    ui: {
      router: { current: () => ({ type: "session", sessionID: "ses_a" }) },
      slot({ render }) { render(); return () => {} },
    },
  }
  const cleanup = setupTmuxAgent(context, (effect) => effect(), {
    pane: "%7", client: "test-client", run: async (file, args) => calls.push(args),
  })
  await new Promise(setImmediate)
  assert.deepEqual(synced, ["session:ses_a", "permission:ses_a", "form:ses_a"])
  assert.equal(calls.at(-1)[0], "off")
  finishSync()
  await new Promise(setImmediate)
  assert.equal(calls.at(-1)[0], "needs-input")
  await cleanup()
})

test("TUI string status changes update the running hint without a lifecycle event", async () => {
  let status = "idle"
  let update
  const calls = []
  const context = {
    data: {
      on: () => () => {},
      session: {
        sync: async () => {}, status: () => status,
        permission: { sync: async () => {}, list: () => [] },
        form: { sync: async () => {}, list: () => [] },
      },
    },
    ui: {
      router: { current: () => ({ type: "session", sessionID: "ses_a" }) },
      slot({ render }) { render(); return () => {} },
    },
  }
  const cleanup = setupTmuxAgent(context, (effect) => { update = effect; effect() }, {
    pane: "%7", client: "test-client", run: async (file, args) => calls.push(args),
  })
  await new Promise(setImmediate)
  assert.equal(calls.at(-1)[0], "off")
  status = "running"
  update()
  await new Promise(setImmediate)
  assert.equal(calls.at(-1)[0], "running")
  assert.equal(calls.at(-1).at(-1), "--quiet")
  await cleanup()
})

test("initial synchronization errors remain contained", async () => {
  const errors = []
  const context = {
    data: {
      on: () => () => {},
      session: {
        sync: async () => { throw new Error("private data") }, status: () => undefined,
        permission: { sync: async () => {}, list: () => [] }, form: { sync: async () => {}, list: () => [] },
      },
    },
    ui: { router: { current: () => ({ type: "session", sessionID: "ses_a" }) }, slot({ render }) { render(); return () => {} } },
  }
  const cleanup = setupTmuxAgent(context, (effect) => effect(), {
    pane: "%7", client: "test-client", run: async () => {}, onError: (message) => errors.push(message),
  })
  await new Promise(setImmediate)
  assert.deepEqual(errors, ["OpenCode tmux session synchronization failed"])
  await cleanup()
})

test("TUI setup outside tmux does not register effects or listeners", () => {
  const cleanup = setupTmuxAgent({}, () => assert.fail("unexpected effect"), { pane: "" })
  cleanup()
})

test("the discoverable package exports only the V2 TUI entry point", async () => {
  const pkg = JSON.parse(await readFile(new URL("../../opencode/plugins/tmux-agent/package.json", import.meta.url)))
  assert.deepEqual(pkg.exports, { "./tui": "./tui.js" })
  const entry = await readFile(new URL("../../opencode/plugins/tmux-agent/tui.js", import.meta.url), "utf8")
  assert.match(entry, /import \{ Plugin \} from "@opencode\/plugin\/tui"/)
  assert.match(entry, /Plugin\.define/)
})
