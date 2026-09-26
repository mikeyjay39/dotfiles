---
name: move-nondurable-comments
description: Find code comments on the current branch that are not durable. Cut them from the code, and post their content as resolvable review comments on the PR's Files changed tab, in ASD-STE100. Use when asked to clean up branch comments or move comments to the PR.
---

# Move Non-Durable Comments to the PR

A durable comment tells why the code is as it is. It stays true while the code does not change.
A comment that is not durable records history, plans, measurements or notes to a reviewer.
This skill cuts those comments from the code. It keeps their useful content as review comments on the PR.

Write all prose in ASD-STE100 Simplified Technical English. This includes the code comments you rewrite and the PR comments you post.
Do not apply STE to code identifiers, numbers or quoted text.

## Guardrails

- Do not commit or push. The user commits and pushes.
- Change only comment lines in the working tree. Do not change code.
- Post one PR review with the event `COMMENT`. Do not change the PR title or body.
- Get approval from the user before you edit a file. Get approval again before you post.
- Posting publishes the text to GitHub. Do not post text that the user did not approve.
- Use review comments on lines, because a reviewer can resolve them. Use a top-level (issue) comment only when the user asks for one.
- Work in the git repository of the current working directory.

## Steps

### 1. Detect the PR and the base

```bash
gh repo view --json nameWithOwner -q .nameWithOwner
gh pr view --json number,url,headRefName,baseRefName
gh api repos/<owner>/<repo>/pulls/<number> -q .head.sha
git fetch -q origin <headRefName> <baseRefName>
git rev-parse HEAD origin/<headRefName>
git merge-base HEAD origin/<baseRefName>
```

- If there is no open PR for the branch, stop and tell the user.
- The local `HEAD` must be the same commit as the PR head SHA. If they are different, stop and tell the user. Review comments use the line numbers of the PR head.
- Record the merge base. Step 2 uses it.

### 2. List the added comment lines

Run this script from the repository root. It prints `path:line: text` for each added comment line, with the line number on the PR head. Change the pathspecs for the languages in the diff.

```bash
git diff -U0 <merge-base> HEAD -- '*.ts' '*.tsx' '*.js' '*.java' '*.rs' '*.yaml' '*.yml' | awk '
/^\+\+\+ b\//{ file = substr($0, 7); next }
/^@@/{ split($3, a, ","); line = substr(a[1], 2) + 0; next }
/^\+/{
  text = substr($0, 2)
  if (text ~ /^[ \t]*(\/\/|\/\*|\*|#)/ || text ~ /[;,)] *\/\/ /) print file ":" line ": " text
  line++
}' > <scratchpad>/comments.txt
wc -l <scratchpad>/comments.txt
```

- Write the list to the scratchpad directory, not to the repository.
- Read all of the list. If it is large, read it in pages. Do not classify from part of the list.
- The script also matches some lines that are not comments, for example generator methods such as `*load() {`. Ignore them.
- To see the full text of a block, read the file at the given line.

### 3. Classify each comment

Put each comment, or each part of a comment, in one of these classes.

**Durable. Keep it.**

- It tells why the code is as it is.
- It states a constraint, an invariant or a contract.
- It warns about a trap in the code that is there now.
- It states a unit, a format or a range.
- It names a current limit and explains the code that is there now. Example: "An empty FX index, because no FX source exists yet." The code has the empty index, so the comment is correct.

**Not durable. Move the content to a PR note.**

- A design for future work.
- An analysis of why the team cannot do something yet.
- A measurement from one investigation. Example: "~60 KB a cycle, which removes the log history of the pod in two minutes."
- A statement that a later ticket decides something.
- A cost or performance concern that is a plan to measure or optimize.

**Not durable. Cut it with no note.**

- Ticket IDs and PR numbers, for example `(TKT-12345)` or `#14842`. The PR and `git blame` hold them.
- Notes to reviewers that compare the code to other code. Examples: "the same shape as X", "matching Y", "the same call that Z makes".
- History words and phrases. Examples: "originally", "the original point of", "Today", "for now", "reused rather than invented", "the interim".

**The TODO rule.**

- Keep each `TODO:` line in the code. It marks the exact location that must change.
- Move only the design detail under the `TODO:` to a PR note.
- Keep a `TODO:` that tells where on the critical path to optimize, even if a PR note covers the same topic.

When you are not sure, keep the comment and tell the user in step 4.

### 4. Show the plan and get approval

Show one table. Use these columns:

| File:line | Current text | Action | New text |
| --------- | ------------ | ------ | -------- |

- The action is `move`, `cut` or `reword`.
- For `move`, give the topic of the PR note.
- After the table, list the comments that you kept on purpose, and give the reason for each one.
- Wait for the user's approval. Apply the changes that the user asks for.

### 5. Edit the code

- Replace exact strings. Make sure that each old string occurs one time only.
- When you cut a clause, keep the rest of the sentence correct. Rewrite it in STE if necessary.
- Do not leave an empty comment block, or a comment block that ends with an empty ` *` line.

Then check that only comment lines changed. This command must print nothing:

```bash
git diff -U0 | grep -E '^[+-][^+-]' | grep -vE '^[+-][[:space:]]*(\*|//|/\*|#)'
```

- Format only the changed files with the formatter of the repository. Do not format other files.
- Run the typecheck of the repository if it has one.

### 6. Post the review

Anchor each PR note to a line on the PR head that does not change when the user pushes.

- Good anchors are a `TODO:` line that stays, a function signature, or the call that the note is about.
- Do not anchor to a line that you delete or change. If you do, GitHub marks the comment as outdated.
- Use `side: "RIGHT"` and the line number on the PR head.

Write each comment body in this shape:

```markdown
**Moved from a code comment: <topic>**

<the content, in STE>
```

- Keep code identifiers, numbers and quoted text verbatim.
- Keep all of the useful content. Do not make the note shorter if this removes a fact, a trap or a reason.
- Put notes that are not about one line in the review `body`. Example: a list of the small cuts that have no note.

Build `review.json` in the scratchpad directory:

```json
{
  "commit_id": "<PR head SHA>",
  "event": "COMMENT",
  "body": "<summary, and the notes that are not about one line>",
  "comments": [{ "path": "<repo-relative path>", "line": 12, "side": "RIGHT", "body": "<note>" }]
}
```

Post all comments in one call:

```bash
gh api -X POST repos/<owner>/<repo>/pulls/<number>/reviews --input <scratchpad>/review.json -q .html_url
```

If the API refuses a line, that line is not in the PR diff. Select a different anchor line in the same hunk, and try again.

### 7. Report

Tell the user:

- The review URL.
- A table of each note and its file:line.
- A summary of the code changes, by file.
- The results of the checks: the comment-only check, the formatter and the typecheck.
- That nothing is committed. The user must commit and push.
