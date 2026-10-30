# Plan review with plannotator

Use this when the human asks for plan review, or accepts your offer of it.

1. Send each planning agent this message:
   `From the control session: write your full plan as Markdown to <scratchpad>/plans/<TKT>-plan.md. Include slices, the files per slice (mark shared files), interfaces for other tickets, tests, decisions, and open questions. Then stop.`
2. Wait until every plan file exists and every pane is idle.
3. Cross-read the plans before the human sees them. Grep them for shared files, interfaces, README edits, and open questions:
   ```bash
   grep -nEi 'shared|interface|readme|open question|TKT-[0-9]+' <scratchpad>/plans/*-plan.md
   ```
   Surface each link in your report. Examples: one ticket's helper that another ticket needs; a dependent that needs an extra argument on a sibling's interface. Add that argument now, because it is cheapest now.
4. Open one review per plan, so that each plan gets its own decision. Run this as one command with `run_in_background: true`:
   ```bash
   cd <scratchpad>/plans && for f in TKT-*-plan.md; do
     plannotator annotate "$f" --gate --json --result-file "$f-review.json" &
   done; wait
   ```
5. Read each `<TKT>-plan.md-review.json`:
   - `{"decision":"approved"}` — tell the agent its plan is approved and it can start the first slice.
   - `{"decision":"annotated","feedback":"…"}` — relay the feedback word for word. Tell the agent to update the plan file and write no code.
6. If feedback contradicts itself (for example, "do this one" on two options), ask the human. Do not guess.
7. After the agents update their plans, repeat from step 3 for the plans that changed.
