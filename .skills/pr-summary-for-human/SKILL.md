---
name: pr-summary-for-human
description: Posts a review summary of a PR as a general comment, and opens the comment in the browser. The summary has before and after Mermaid UML diagrams of each use case's execution path, the critical code to review, the trade-offs of the major decisions in non-functional terms, and the risks and gaps. Each review item, and each after sequence or activity diagram, links to its lines in the PR's Files changed tab. It does not approve or request changes. Use when asked to summarize a PR for review, or to diagram the before and after of a PR.
---

# PR Summary For Human

The user's original instructions:

> Build me an html page and launch it in the browser showing me mermaid uml diagrams of the before and after changes of the execution path of the use cases covered in this branch. Also highlight the critical areas of code that I should focus on when I do my review. Summarize the trade offs of the major decisions made in this branch in terms of non-functional requirements. Summarize any potential risks or gaps this PR might introduce.

And the later change:

> Instead of making an html page let's just post the summary as a general comment on the PR without approving or blocking. Add links to the items under critical areas to review that jump to referenced area of code in the files changed section. Similarly for the UML diagrams, if they are activity or sequence diagrams then please add a link to line under files changes where I can find the new behavior.

The target is in `$ARGUMENTS`: a PR number, a PR URL, a branch name, or nothing. Nothing means the PR of the current branch.

Write all prose in ASD-STE100 Simplified Technical English. Do not apply STE to code identifiers or quoted text.

## Guardrails

- Make one write only: a single general comment, with `gh pr comment`. Do not approve, request changes, add line comments, commit, push or change the code.
- Post as soon as the comment is written. The user does not want to see a draft first.
- The target must have an open PR. If it has none, stop and tell the user.
- Every claim must come from code you read. Give a link for each review item, each risk, and each after sequence or activity diagram.
- Say in the comment what you did not verify (for example, you did not run the tests).

## Steps

### 1. Find the change

```bash
gh pr view <target> --json number,url,title,body,state,baseRefName,headRefName,baseRefOid,headRefOid
gh repo view --json nameWithOwner -q .nameWithOwner
```

- If the branch is checked out locally, read the diff and the files with git. Git lets you read whole files.

  ```bash
  git merge-base <headRefOid> origin/<baseRefName>
  git log --oneline origin/<baseRefName>..<headRefOid>
  git diff --stat origin/<baseRefName>...<headRefOid>
  git diff origin/<baseRefName>...<headRefOid> -- . ':(exclude)*.spec.*' ':(exclude)*.test.*'
  ```

- If it is not checked out, use `gh pr diff <n>`, and read whole files with `gh api repos/<owner>/<repo>/contents/<path>?ref=<headRefOid> -q .content | base64 -d`.
- Read the commit messages and the PR body. They state the intent. You compare the code against it in step 3.
- Read the nearest `AGENTS.md` or `README.md` of the changed area for the domain words.

### 2. Read the code around the diff

A diff alone hides the execution path. For each changed production file:

- Read the whole changed function and its callers. Trace the path from the entry point (consumer, controller, resolver, CLI) to the store or output.
- Read the sibling paths that the diff did **not** change but that share the new concept. Example: the diff changes the Create handler, so read the Modify and Cancel handlers too. Gaps are often in the paths nobody touched.
- `grep` each new field, method and type. Find every producer and every consumer. A field that is read but never written in production is a gap.
- List the new test names: `git diff <base>...<head> -- '*.spec.*' '*.test.*' | grep -E '^\+\s*(it|test|describe)\('`. For each important test, check that it runs the production path. A test that builds its input by hand can pass when the real handler never produces that input.

### 3. Decide the content

- **Use cases:** 2 to 5 flows that the PR changes, named for a reader (for example, "Trade Create sent again"). Include an unchanged flow when it shows a gap.
- **Diagrams:** for each use case, a **before** and an **after** diagram of the same type. Use:
  - `sequenceDiagram` for the end-to-end path across components.
  - `flowchart` (activity) for a decision function (guards, branches, outcomes).
  - `classDiagram` for a change to the domain model or state shape.
  - Highlight new or risky nodes with `style <id> stroke:<color>,stroke-width:2px`.
- **New-behavior locations:** for each **after** `sequenceDiagram` and `flowchart`, record the `path:line` (or line range) on the new side where the new behavior is. Use one location per new step or branch that matters, usually 1 to 3.
- **Outcome table:** when the change alters results, show each input case with its before and after result.
- **Review focus:** 4 to 8 places, in priority order, each with `path:line` or a line range, what to check, and why. Mark the 2 or 3 highest-risk places.
- **Trade-offs:** one row per major decision with the gains and the costs. Name the non-functional attribute for each one: correctness, consistency, performance, availability, storage, compatibility, rollback, operability, maintainability, security.
- **Risks and gaps:** one row per item with severity (High, Medium, Low), what it is, where it is and why. Include migration, deploy, rollback, data-change and test-coverage risks. Include mismatches between the commit or PR text and the code.
- **Questions for the author:** the open points you can not settle from the code.

### 4. Build the links

Each `path` is relative to the repo root.

- **Files changed link:** `https://github.com/<owner>/<repo>/pull/<n>/files#diff-<hash>R<line>`, where `<hash>` is the SHA-256 of the path:

  ```bash
  printf '%s' "<path>" | sha256sum | cut -d' ' -f1
  ```

  For a range, end with `R<start>-R<end>`. `R` is the new side of the diff. Use `L<line>` only for a line that the PR deleted.

- **Check the line is in the diff.** Files changed can only scroll to a line inside a hunk. Read the hunk headers:

  ```bash
  git diff <base>...<headRefOid> -- "<path>" | grep -E '^@@'
  ```

  A header `@@ -a,b +c,d @@` covers new lines `c` to `c+d-1`. When `,d` is absent, `d` is 1.

- **Line not in the diff:** link to the file at the reviewed commit, and write "(not in the diff)" after the link:

  `https://github.com/<owner>/<repo>/blob/<headRefOid>/<path>#L<line>` (for a range, `#L<start>-L<end>`).

- **Link text:** `path:line`. When the path is long, drop the leading folders up to the project folder (for example, `src/domain/position/position.ts:149`).

### 5. Write the comment

Write the comment to `<scratchpad>/pr-<n>-summary.md`, or to `${TMPDIR:-/tmp}/pr-<n>-summary.md` when the system prompt lists no scratchpad. Follow these rules:

- Start with `## Review summary for <ticket or PR title>`, then the line `Reviewed at <short headRefOid> · <files> files, +<added> / −<removed>`. Do not say whether you approve, and do not say whether the findings block the PR.
- Next, write a short list of what the PR does.
- Put each diagram in a ` ```mermaid ` fence. GitHub renders Mermaid.
- Put each diagram in its own `<details open><summary><strong>Before</strong></summary>` … `</details>` block. Put an empty line after `<summary>` and before `</details>`. GitHub does not support side-by-side columns.
- In each **after** `sequenceDiagram` or `flowchart` block, below the fence and before `</details>`, add one line per location:

  `**New behavior:** [path:line](link): <what the code does there>`

- Write each review-focus item as a numbered item whose heading is the link, then a line with what to check and why:

  ```markdown
  1. 🔴 **[path:line](link): `symbolName`**
     What to check, and why.
  ```

- In the risks table, make each `path:line` in the "Where / why" cell a link.
- Make each table a Markdown pipe table. Escape a literal `|` in a cell as `\|`.
- Show severity with emoji: 🔴 High, 🟠 Medium, ⚪ Low. Mark the highest-risk review items with 🔴.
- Do not add a contents list with anchor links. Heading anchors in comments are not stable.
- End with a `### Not verified` list.
- Check the length with `wc -c`. GitHub rejects a comment longer than 65,536 characters. If it is longer than 65,000, ask the user which sections to remove.

### 6. Post and open

```bash
gh pr comment <n> --body-file <file>    # prints the comment URL
```

Open the comment URL with the first command that exists:

```bash
command -v explorer.exe && explorer.exe "<url>"   # WSL
command -v open && open "<url>"                   # macOS
command -v xdg-open && xdg-open "<url>"           # Linux
```

`explorer.exe` returns exit code 1 when it succeeds. Do not treat that as a failure.

### 7. Report

In the reply, give:

- The comment URL.
- What the comment holds, in a short list.
- The two or three findings that matter most, in plain words.
- What you did not verify.
