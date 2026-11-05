---
name: pr-summary-for-human
description: Builds one local HTML page that helps a human review a PR or branch, and opens it in the browser. The page shows before and after Mermaid UML diagrams of the execution path of each use case, the critical code to review with file:line, the trade-offs of the major decisions in non-functional terms, and the risks and gaps. Use when asked to summarize a PR for review, to diagram the before and after of a branch, or to make a review guide page.
---

# PR Summary For Human

The user's original instructions:

> Build me an html page and launch it in the browser showing me mermaid uml diagrams of the before and after changes of the execution path of the use cases covered in this branch. Also highlight the critical areas of code that I should focus on when I do my review. Summarize the trade offs of the major decisions made in this branch in terms of non-functional requirements. Summarize any potential risks or gaps this PR might introduce.

The target is in `$ARGUMENTS`: a PR number, a PR URL, a branch name, or nothing. Nothing means the current branch.

Write all prose in ASD-STE100 Simplified Technical English. Do not apply STE to code identifiers or quoted text.

## Guardrails

- Only read. Do not commit, push, comment on the PR, or change the code.
- Do not publish the page to a remote service. After you open it, offer in one line to publish it as a private link.
- Every claim on the page must come from code you read. Put a `file:line` on each review hotspot and each risk.
- Say on the page and in your reply what you did not verify (for example, you did not run the tests).

## Steps

### 1. Find the change

- **PR number or URL:** `gh pr view <n> --json number,title,body,baseRefName,headRefName,url`, then `gh pr diff <n>`. If the branch is checked out locally, prefer the local git commands below. They let you read whole files.
- **Branch or nothing:**

  ```bash
  git merge-base HEAD origin/<default branch>
  git log --oneline origin/<default branch>..HEAD
  git diff --stat origin/<default branch>...HEAD
  git diff origin/<default branch>...HEAD -- . ':(exclude)*.spec.*' ':(exclude)*.test.*'
  ```

- Get the default branch with `git symbolic-ref --short refs/remotes/origin/HEAD`.
- Read the commit messages and the PR body. They state the intent. You compare the code against it in step 3.
- Read the nearest `AGENTS.md` or `README.md` of the changed area for the domain words.

### 2. Read the code around the diff

A diff alone hides the execution path. For each changed production file:

- Read the whole changed function and its callers. Trace the path from the entry point (consumer, controller, resolver, CLI) to the store or output.
- Read the sibling paths that the diff did **not** change but that share the new concept. Example: the diff changes the Create handler, so read the Modify and Cancel handlers too. Gaps are often in the paths nobody touched.
- `grep` each new field, method and type. Find every producer and every consumer. A field that is read but never written in production is a gap.
- List the new test names: `git diff <base>...HEAD -- '*.spec.*' '*.test.*' | grep -E '^\+\s*(it|test|describe)\('`. For each important test, check that it runs the production path. A test that builds its input by hand can pass when the real handler never produces that input.

### 3. Decide the content

- **Use cases:** 2 to 5 flows that the branch changes, named for a reader (for example, "Trade Create sent again"). Include an unchanged flow when it shows a gap.
- **Diagrams:** for each use case, a **before** and an **after** diagram of the same type, side by side. Use:
  - `sequenceDiagram` for the end-to-end path across components.
  - `flowchart` for a decision function (guards, branches, outcomes).
  - `classDiagram` for a change to the domain model or state shape.
  - Highlight new or risky nodes with `style <id> stroke:<color>,stroke-width:2px`.
- **Outcome table:** when the change alters results, show each input case with its before and after result.
- **Review focus:** 4 to 8 places, in priority order, each with `file:line`, what to check, and why. Mark the 2 or 3 highest-risk places.
- **Trade-offs:** one row per major decision with the gains and the costs. Name the non-functional attribute for each one: correctness, consistency, performance, availability, storage, compatibility, rollback, operability, maintainability, security.
- **Risks and gaps:** one row per item with severity (High, Medium, Low), what it is, where it is and why. Include migration, deploy, rollback, data-change and test-coverage risks. Include mismatches between the commit or PR text and the code.
- **Questions for the author:** the open points you can not settle from the code.

### 4. Build the page

- Start from [`references/template.html`](references/template.html). Keep its theme tokens, the dark mode rules, the pinned Mermaid import, and the diagram viewer.
- The viewer lets the reader click any `.mermaid` block to open it full screen, with scroll to zoom and drag to pan. Page zoom does not enlarge Mermaid text, because Mermaid fits each SVG to its column. Do not remove the viewer, and put every diagram in a `<pre class="mermaid">`.
- Write one self-contained `.html` file. Put it in the session scratchpad directory when the system prompt lists one. If not, use `${TMPDIR:-/tmp}/pr-summary-<branch>.html`.
- Use the full absolute path when you name the file to the user.
- Escape `<` and `>` in Mermaid labels with `&lt;` and `&gt;`, or use `<br/>` only for line breaks. Keep Mermaid labels short.

### 5. Open the page

Use the first command that exists:

```bash
command -v explorer.exe && explorer.exe "$(wslpath -w "$FILE")"   # WSL
command -v open && open "$FILE"                                     # macOS
command -v xdg-open && xdg-open "$FILE"                             # Linux
```

`explorer.exe` returns exit code 1 when it succeeds. Do not treat that as a failure.

### 6. Report

In the reply, give:

- The absolute path of the page.
- What the page holds, in a short list.
- The two or three findings that matter most, in plain words.
- What you did not verify.
- One line that offers to publish the page as a private link.
