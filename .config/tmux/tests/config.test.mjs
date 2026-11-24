import assert from "node:assert/strict"
import { readFile } from "node:fs/promises"
import test from "node:test"

const config = await readFile(new URL("../tmux.conf", import.meta.url), "utf8")
const appIcon = config.match(/^set -g @app_icon "(.*)"$/m)?.[1]
assert.ok(appIcon)

// Evaluate only the documented format operators used by @app_icon. Do not start tmux.
function splitArguments(text) {
  const result = []
  let depth = 0
  let start = 0
  for (let index = 0; index < text.length; index += 1) {
    if (text.startsWith("#{", index)) { depth += 1; index += 1 }
    else if (text[index] === "}") { depth -= 1 }
    else if (text[index] === "," && depth === 0) { result.push(text.slice(start, index)); start = index + 1 }
  }
  assert.equal(depth, 0, "balanced tmux format arguments")
  result.push(text.slice(start))
  return result
}

function expand(text) {
  let result = ""
  for (let index = 0; index < text.length; index += 1) {
    if (!text.startsWith("#{", index)) { result += text[index]; continue }
    const start = index + 2
    let depth = 1
    index = start
    for (; index < text.length && depth; index += 1) {
      if (text.startsWith("#{", index)) { depth += 1; index += 1 }
      else if (text[index] === "}") depth -= 1
    }
    assert.equal(depth, 0, "balanced tmux format expression")
    result += evaluate(text.slice(start, index - 1))
    index -= 1
  }
  return result
}

function evaluate(expression) {
  if (expression.startsWith("?")) {
    const [condition, yes, no] = splitArguments(expression.slice(1))
    return expand(condition) === "1" ? expand(yes) : expand(no)
  }
  const separator = expression.indexOf(":")
  const operator = expression.slice(0, separator)
  const args = splitArguments(expression.slice(separator + 1)).map(expand)
  if (operator === "||") return args.some((arg) => arg === "1") ? "1" : "0"
  if (operator === "==") return args[0] === args[1] ? "1" : "0"
  if (operator === "m") {
    const pattern = args[0].split("*").map((part) => part.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")).join(".*")
    return new RegExp(`^${pattern}$`).test(args[1]) ? "1" : "0"
  }
  assert.fail(`unsupported tmux test operator: ${operator}`)
}

for (const [program, icon] of [
  ["opencode", "󰚩 "], ["cursor-agent", "󰚩 "], ["claude", " "],
  ["nvim", " "], ["bash", " "], ["docker", " "], ["unknown", ""],
]) {
  test(`${program} retains its app icon rule`, () => {
    assert.equal(expand(appIcon.replaceAll("__APP__", program)), icon)
  })
}

test("pane and window icons share the same app detection", () => {
  assert.match(config, /@icon_for_window .*window_name.*@app_icon/)
  assert.match(config, /@icon_for_pane .*pane_current_command.*@app_icon/)
})

test("state colors and session-tree hints remain agent-independent", () => {
  const state = config.match(/^set -g @agent_state_icon "(.*)"$/m)?.[1]
  assert.match(state, /running.*fg=yellow bold.*needs-input.*fg=red bold.*done.*fg=bold/s)
  assert.doesNotMatch(state, /claude|cursor|opencode/)
  const hints = config.match(/^set -g @tree_hints "(.*)"$/m)?.[1]
  for (const hint of ["switch", "kill", "tag", "kill tagged", "swap", "sort", "search", "filter", "preview", "help", "quit"]) assert.ok(hints.includes(hint))
  assert.match(config, /bind s choose-tree -Zs -F "#\{E:@agent_tree_format\}"/)
  assert.match(config, /bind a run-shell "~\/.config\/tmux\/agent-jump.sh/)
})
