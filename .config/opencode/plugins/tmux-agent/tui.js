import { Plugin } from "@opencode/plugin/tui"
import { createEffect } from "solid-js"
import { setupTmuxAgent } from "./setup.js"

export default Plugin.define({
  id: "dotfiles.tmux-agent",
  setup(context) {
    return setupTmuxAgent(context, createEffect)
  },
})
