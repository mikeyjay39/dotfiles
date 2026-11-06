---
name: clean-code
description: Detailed clean-code and SOLID guidance with good/bad examples and a self-review checklist. Use when writing or refactoring non-trivial code, or when asked about clean code, design principles, code smells, or SOLID (SRP, OCP, LSP, ISP, DIP).
---

# Clean Code & SOLID

Guidance for writing code that is easy to read, change, and test. Language-agnostic —
examples use pseudocode-ish JS/TS but the principles apply everywhere.

**Golden rule:** match the conventions of the code you're editing. These principles serve
readability and changeability; they are guidance, not dogma. When a principle and local
convention conflict, prefer local convention and note the trade-off. Use American English
spelling in code, comments, and docs (`color`, `initialize`, `behavior`).

---

## Part 1 — Clean code

### Names reveal intent

A reader should understand a name without hunting for its definition.

```js
// bad
function calc(d, r) { return d * (1 + r); }

// good
function applyInterest(principal, rate) { return principal * (1 + rate); }
```

Avoid noise words (`data`, `info`, `manager`, `helper`, `util`, `tmp`), single letters
outside tight loops, and encodings (`strName`, `arrItems`).

### Small functions, one level of abstraction

A function should do one thing. If its body mixes high-level policy with low-level
detail, extract the detail.

```js
// bad — mixes orchestration with parsing detail
function report(orders) {
  let total = 0;
  for (const o of orders) {
    const cents = Number(o.amount.replace('$', '')) * 100;
    total += cents;
  }
  send(`Total: ${total / 100}`);
}

// good — each function reads at one altitude
function report(orders) {
  const total = sumAmounts(orders);
  send(`Total: ${formatDollars(total)}`);
}
function sumAmounts(orders) { return orders.reduce((sum, o) => sum + parseCents(o.amount), 0); }
```

If you're adding a comment to label a "section" of a function, that section wants to be
its own function.

This rule is about functions. It does not justify more classes, files, or components —
for those, see SRP and the cohesion guardrail below.

### Guard clauses over nesting

Return/throw early so the happy path stays flat.

```js
// bad
function save(user) {
  if (user) {
    if (user.isValid) {
      if (!user.exists) {
        db.insert(user);
      }
    }
  }
}

// good
function save(user) {
  if (!user) return;
  if (!user.isValid) return;
  if (user.exists) return;
  db.insert(user);
}
```

### DRY — but beware the wrong abstraction

Remove genuine duplication (the same knowledge expressed twice). Do **not** merge code
that merely looks similar today but changes for different reasons — a premature
abstraction is harder to unwind than duplication. Rule of thumb: duplicate until the
shape and the *reason to change* are clearly the same, then extract.

### Handle errors explicitly

No empty catches, no swallowed results. Catch where you can actually do something; let it
propagate otherwise.

```js
// bad
try { risky(); } catch (e) { /* ignore */ }

// good
try {
  risky();
} catch (e) {
  logger.error('risky() failed while syncing orders', e);
  throw new SyncError('order sync failed', { cause: e });
}
```

Prefer returning/raising typed errors over booleans or magic values.

### Comments explain *why*, not *what*

Code already says *what*. Use comments for rationale, trade-offs, links, and warnings.

```js
// bad
i += 1; // increment i

// good
// Stripe rounds half-up; mirror that here so our totals reconcile with their dashboard.
amount = roundHalfUp(amount);
```

Delete commented-out code — that's what version control is for.

### Prefer immutability and pure functions

Functions that don't mutate shared state and depend only on their inputs are easiest to
test and reason about. Isolate side effects (I/O, mutation) at the edges.

### No dead code / YAGNI

Delete unused functions, parameters, flags, and speculative extension points. Build for
today's requirement, not an imagined future one.

---

## Part 2 — SOLID

### S — Single Responsibility

*A module is responsible to one, and only one, actor.* An actor is a person or group of
stakeholders who ask for changes. "Reason to change" means *actor* — not "concern",
"task", or "technical layer".

SRP is **not** "do one thing". That rule is for functions. A class with many methods that
all serve one actor obeys SRP.

```js
// bad — three actors share one class
class Employee {
  calculatePay() {}  // CFO / accounting
  reportHours() {}   // COO / HR
  save() {}          // CTO / DBAs
}

// good — split by actor
class PayCalculator { calculatePay(employee) {} }
class HourReporter  { reportHours(employee) {} }
class EmployeeRepository { save(employee) {} }
```

```js
// bad — over-split: accounting owns all of these rules and changes them together
class PayCalculator      { calculate(e) {} }
class OvertimeCalculator { calculate(e) {} }
class TaxCalculator      { calculate(e) {} }

// good — one actor, one module
class PayCalculator {
  calculatePay(employee) {}
  overtime(employee) {}
  tax(employee) {}
}
```

**Test:** ask "who asks for this to change?" If two parts have the same answer and change
together, keep them together.

**Why:** a change requested by one actor cannot break code that another actor depends on.

### O — Open/Closed

*Open to extension, closed to modification.* Add new behavior without editing the
existing switch or if-chain.

```js
// bad — every new shape edits this function
function area(shape) {
  if (shape.type === 'circle') return Math.PI * shape.r ** 2;
  if (shape.type === 'square') return shape.side ** 2;
}

// good — new shapes add a class, don't touch existing ones
class Circle { area() { return Math.PI * this.r ** 2; } }
class Square { area() { return this.side ** 2; } }
function area(shape) { return shape.area(); }
```

**Why:** extension isolates change and lowers the risk of regressions.

### L — Liskov Substitution

*Subtypes must be substitutable for their base type without surprising callers.* Don't
override a method to weaken guarantees or throw where the base didn't.

```js
// bad — Ostrich breaks code that expects Bird.fly()
class Bird { fly() {} }
class Ostrich extends Bird { fly() { throw new Error("can't fly"); } }

// good — model the real capability
class Bird {}
class FlyingBird extends Bird { fly() {} }
class Ostrich extends Bird {}
```

**Why:** callers can rely on the abstraction without type-checking for special cases.

### I — Interface Segregation

*Don't force clients to depend on methods they don't use.* Prefer several focused
interfaces over one fat one.

```ts
// bad
interface Worker { work(): void; eat(): void; }
class Robot implements Worker { work() {} eat() { /* n/a */ } }

// good
interface Workable { work(): void; }
interface Feedable { eat(): void; }
class Robot implements Workable { work() {} }
```

**Why:** clients aren't coupled to behavior they don't need, so changes ripple less.

### D — Dependency Inversion

*Depend on abstractions, not concretions; inject dependencies.* High-level policy
shouldn't hard-wire low-level detail.

```js
// bad — service is welded to a concrete DB
class OrderService {
  constructor() { this.db = new PostgresClient(); }
}

// good — depend on an abstraction, pass it in
class OrderService {
  constructor(store) { this.store = store; } // any OrderStore
}
```

**Why:** you can swap implementations and test with fakes without touching the policy.

---

## Pragmatism guardrails

- **YAGNI / KISS:** the simplest thing that satisfies the requirement wins. Don't add
  layers, interfaces, or config for hypothetical needs.
- **Cohesion (Common Closure):** keep together what changes together, for the same
  actor, at the same time. A new class, file, or component needs a different actor or a
  real second caller. Indirection with one caller is a cost, not a benefit.
- **Rule of three:** tolerate duplication until you've seen the same thing three times
  and understand why it varies — then abstract.
- **Fit the codebase:** a "cleaner" pattern that clashes with established conventions is
  usually a net loss. Consistency beats local optimization.
- **These are trade-offs, not laws.** State the trade-off when you deviate.

---

## Self-review checklist

Before finishing a change, skim it and ask:

- [ ] Do names read clearly without needing their definition?
- [ ] Does each function do one thing at one level of abstraction?
- [ ] Is the happy path flat (guard clauses, not deep nesting)?
- [ ] Is any duplication *genuine* — or would abstracting it couple unrelated things?
- [ ] Are errors handled or propagated deliberately (nothing swallowed)?
- [ ] Do comments explain *why*, and is there no commented-out/dead code left?
- [ ] Is each module responsible to one actor (SRP)?
- [ ] Did I split anything that the same actor changes together (cohesion)?
- [ ] Can new cases be added without editing existing logic (OCP)?
- [ ] Do subtypes honor their base type's contract (LSP)?
- [ ] Are interfaces focused, and dependencies injected against abstractions (ISP/DIP)?
- [ ] Is this the simplest solution that fits the existing design (YAGNI/KISS)?
