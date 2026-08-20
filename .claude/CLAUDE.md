# Coding standards

Write clean, maintainable code. Match the conventions already in the file/repo you're editing.

- **Names:** clear and intention-revealing. A name should say what a thing is or does; avoid abbreviations and filler (`data`, `manager`, `helper`).
- **Small, focused functions:** one job, one level of abstraction. If you need a comment to separate "sections" of a function, split it.
- **Guard clauses over nesting:** return early; keep the happy path un-indented.
- **DRY, with judgement:** remove real duplication, but don't abstract two things that merely look alike today. Prefer duplication over the wrong abstraction.
- **Handle errors explicitly:** no silent catches, no swallowed failures. Fail loudly at the boundary you can act on.
- **Prefer composition over inheritance**, and pure functions / immutability where practical.
- **No dead code:** delete unused code, commented-out blocks, and speculative "might need it later" hooks (YAGNI).
- **Comments explain _why_,** not _what_. Code says what; comments justify non-obvious decisions.
- **Don't over-engineer:** the simplest solution that fits the existing design wins.
- **American English:** use American spelling in code, comments, docs, and identifiers (`color`, `initialize`, `behavior`, `canceled` — not `colour`, `initialise`, `behaviour`, `cancelled`). Follow the existing codebase if it already standardizes on another variant.

## SOLID

- **S — Single Responsibility:** a module/class/function has one reason to change.
- **O — Open/Closed:** open to extension, closed to modification — add behavior without editing existing code.
- **L — Liskov Substitution:** subtypes must be usable anywhere their base type is, without surprises.
- **I — Interface Segregation:** many small, focused interfaces beat one fat one; don't force clients to depend on methods they don't use.
- **D — Dependency Inversion:** depend on abstractions, not concretions; inject dependencies rather than hard-wiring them.

For detailed guidance, examples, and a self-review checklist when writing or refactoring
non-trivial code, use the **`clean-code`** skill.
