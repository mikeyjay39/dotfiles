---
description: Replace the open PR body with a Notion-driven review description (objective, ticket, entrypoint, optional flow, AC↔tests).
---

# Rewrite PR Body

Replace the **entire** description of the open Pull Request for the current git branch.
Discard any PR template. Do not preserve checklist sections, shout-outs, or placeholders.

## Guardrails

- The **only** permitted mutating action is updating the PR body via `gh pr edit … --body …` (or `--body-file`).
- Do **not** change the PR title unless the user explicitly asks.
- Do **not** commit, push, checkout, or edit/create/delete any files in the working repo.
- Do **not** invent ticket content, acceptance criteria, or tests. Ground objective and scenarios in Notion; ground entrypoint and test links in the PR diff.
- Work from the **current working directory’s** git repository (detect remote/repo from cwd).
- Be concise. Prefer short links and a high-level diagram over long prose.

## Steps

### 1. Detect the open PR

```bash
gh repo view --json nameWithOwner -q .nameWithOwner
gh pr view --json number,url,title,body,headRefName,baseRefName
```

If there is no open PR for the current branch, stop and tell the user.

### 2. Parse the Notion ticket id from the branch name

From `headRefName`, match case-insensitively: `tkt-(\d+)`.

- Normalize to `TKT-<number>` (e.g. `mjeszenka/tkt-20622-foo` → `TKT-20622`).
- If no match, stop and tell the user the branch name has no `TKT-` / `tkt-` prefix.

### 3. Fetch the Notion ticket

Prefer the working repo’s Notion tooling when present:

1. **Preferred:** Task tool with `subagent_type="notion"` — ask it to fetch `TKT-NNNNN` (properties + page content) and, for deep links, block ids for acceptance-criteria scenario blocks.
2. **Fallback:** If `.agents/skills/notion-api/scripts/get-ticket.sh` exists:

   ```bash
   bash .agents/skills/notion-api/scripts/get-ticket.sh TKT-NNNNN
   ```

**Never** read, open, or grep `.env` for `NOTION_API_TOKEN`. Helper scripts load the token themselves.

**Ticket page URL:** use a canonical URL from Notion if returned; otherwise:

`https://www.notion.so/<page_id_with_dashes_stripped>`

### 4. Analyze the PR changes

```bash
gh pr diff
gh pr view --json files -q '.files[].path'
```

From the diff and file list:

- Pick a single **review entrypoint** — the best starting file for a reviewer (primary command, handler, use-case module, or main changed module). Prefer application/domain code over tests, generated files, config-only, or lockfiles.
- Pick the **specific right-side line** in that file that best starts review (e.g. the new/changed symbol, function, or join definition) — use the line number on the PR head / “new” side of the diff.
- Note tests that validate acceptance scenarios (`it(…)`, `it.each`, BDD/scenario titles, etc.) and their line numbers on the PR head branch.
- Decide whether any **use case** is involved (see step 6).

**Review entrypoint link** must open the PR Files changed tab at that line:

`https://github.com/<owner>/<repo>/pull/<PR_NUMBER>/changes#diff-<sha256(path)>R<line>`

- `<sha256(path)>` = hex SHA-256 of the file path string as used in the PR (e.g. `libs/.../foo.ts`). Compute with: `printf '%s' '<path>' | sha256sum` (or equivalent).
- Use **`R`** (right/new side), not `L`. Example: `…/pull/13857/changes#diff-28d2cf25…dd9eR56`

**Acceptance-criteria test links** still use the PR head branch blob URL:

`https://github.com/<owner>/<repo>/blob/<headRefName>/<path>#L<line>`

### 5. One-sentence objective

Write **exactly one sentence** summarizing the ticket’s objective (from user story, title, and/or AI Summary on the ticket). No bullets, no multi-paragraph summary.

### 6. Flow diagram (conditional)

Include a `## Flow` section with a concise Mermaid **`flowchart`** when the PR **involves any use case** — **new or pre-existing** — so reviewers quickly get context for that behavioral path.

- **GitHub constraint:** use `flowchart TD` (or `LR`) only. Do **not** use `activityDiagram` — GitHub Mermaid does not render it.
- **Include** when the ticket/diff describes or alters a user- or system-facing behavioral path (command, workflow, handler, feature flow). Diagram that use case’s happy path at a high level.
- **Omit** the entire `## Flow` section when **no use case is being changed** (e.g. pure infra, config, docs, dependency bumps, or mechanical refactors with no behavioral path).
- Do **not** gate on Story vs Bug, or on `feat` vs `fix` / `refactor` alone. A bug fix or refactor that still changes a use case path still gets a diagram.
- Keep the diagram short; omit implementation noise (fan-out, error packing, framework wiring).

### 7. Acceptance criteria ↔ tests

From the **ticket page only** (do not pull scenarios from linked Feature pages for this section):

1. Extract scenario names (e.g. `Scenario N: …`, numbered AC blocks under Acceptance criteria).
2. For each scenario, build a Notion **block deep link**. Helper scripts often strip block ids — fetch raw page blocks (notion subagent or Notion blocks API) so you have each block’s `id` + text. Deep-link fragment = `#` + block id with dashes removed, appended to the ticket page URL.
3. Map each scenario to a validating test in the PR when possible. Link the test with a GitHub blob permalink (head branch + `#L…`).
4. If a scenario has no matching test in the PR: still list it and note _no matching test found_.
5. If the ticket has no scenarios: write `_None._`

Example bullet:

```markdown
- [Scenario 1: …](https://www.notion.so/<page>#<block>) → [`it('…')`](https://github.com/<owner>/<repo>/blob/<branch>/<test-file>#L42)
```

### 8. Replace the PR body

Build the body exactly in this shape (omit `## Flow` when step 6 says so):

````markdown
## Objective

<one sentence>

## Ticket

[TKT-NNNNN](<notion page url>)

## Review entrypoint

Start here: [`path/to/entrypoint`](<github pr changes diff url with #diff-…Rline>)

## Flow

```mermaid
flowchart TD
  A[…] --> B[…]
  B --> C[…]
```

## Acceptance criteria

- [Scenario …](<notion deep link>) → [`test title`](<github test permalink>)
````

Apply:

```bash
gh pr edit <PR_NUMBER> --body "$(cat <<'EOF'
…full body…
EOF
)"
```

Then confirm with `gh pr view <PR_NUMBER> --json url,body` (or print the PR URL) so the user can open it.
