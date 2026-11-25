Prove that story `{{STORY_ID}}` works for real. A passing unit test alone is not proof. Nobody can answer questions during this run.

{{HARD_LIMITS}}

Proof type: `{{PROOF}}`. Commands from the plan:
{{PROOF_COMMANDS}}

Acceptance criteria:
{{AC}}

## Steps

1. Start the changed behavior from the worktree. For `tilt`, start an isolated Tilt environment for this worktree only, on a free port (`tilt up --port <port>`), or with the method that the `Tiltfile` or the repo docs give. Wait until the resources are healthy.
2. Use it to show each AC: run the command, call the API, or open the page.
3. For `ui`, take screenshots with a headless browser. Use Playwright when the repo has it. Otherwise find Chrome with `find ~/.cache/puppeteer ~/.cache/ms-playwright -type f \( -name chrome -o -name chrome-headless-shell -o -name headless_shell \) | tail -1` and run `<chrome> --headless --no-sandbox --window-size=1280,800 --screenshot=<file> <url>`. Save each screenshot as a PNG in `{{PROOF_DIR}}`.
4. Stop every server, Tilt session, and process that you started.
5. Do not change or commit code in this step. If the proof shows that an AC is not met, return `status: fail` and say why.

Return the structured output. Keep each output excerpt to 15 lines or fewer. Give screenshot paths relative to `{{PROOF_DIR}}`.
