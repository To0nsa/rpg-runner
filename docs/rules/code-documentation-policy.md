# Code Documentation Policy

## Purpose

Set the repository standard for high-signal code documentation and comments.
It applies to every contributor, including AI agents, and aims to prevent noise
while reducing future bugs and review time.

**Delete comments that only:**

* restate the symbol name (`/// ClassName.`)
* narrate the code (`// set value`, `// increment i`)
* describe the obvious type/shape without constraints
* explain history instead of current behavior

**Write docs/comments only to encode:** intent, constraints, rationale, non-obvious behavior.

---

## Core Rule

A comment/doc is allowed only if it answers at least one of:

1. **Intent** — what problem this solves / what outcome it guarantees
2. **Constraints** — invariants, determinism, ordering, units, safety bounds
3. **Rationale** — why this design over an obvious alternative
4. **Non-obvious behavior** — edge cases, tie-breaks, side effects, failure modes

If it does none of these: **do not add it** (or remove it).

---

## Scope

Apply this policy when creating or modifying:

* Source code comments and API docs
* Architecture/contract docs **when cross-module behavior or boundaries change**

It does not require a retroactive documentation pass over untouched code. When
working in an existing slice, improve or remove nearby documentation only when
it is relevant to the change or is demonstrably stale.

### Comment formats

* Public API docs: language-standard doc syntax (Dart `///`, JSDoc, etc.)
* Internal reasoning: line comments adjacent to the logic they justify

---

## Repository Standards

### R1 — No name-only docs

Bad:

```
/// UserService.
```

Good:

```
/// Coordinates user profile reads/writes and enforces schema/version migration.
```

### R2 — No narration

Bad:

```
// increment i
// set value
// call foo()
```

Allowed only when encoding reasoning:

```
// Clamp to avoid negative retries after clock skew.
```

### R3 — Changed public APIs must be self-usable

Every new or materially changed public type, function, or method must document:

* **what it does**
* **key constraints/invariants**
* any **non-obvious side effects**
* **units** if relevant (ticks vs seconds, fixed-point scale, etc.)

If a caller must read the implementation to avoid misuse, docs are insufficient.

### R4 — Internal comments only for “reasoning hotspots”

Only comment implementation when there’s risk of misinterpretation:

* state machines / transitions
* tie-break rules (determinism)
* numeric scaling / unit conversions
* ordering dependencies between systems
* subtle safety logic (clamps, overflow/underflow prevention)
* cross-module contract assumptions

### R5 — Stale comments are bugs

If you touch code in a scope:

* update nearby docs/comments to match behavior, or
* delete them

No “we’ll fix docs later”.

### R6 — Behavior-critical constants must be documented in-place

If a default/constant materially affects gameplay/behavior:

* document it next to the value
* include **meaning + unit + tuning rationale (1 line)**

Bad:

```
/// Default request timeout.
const REQUEST_TIMEOUT_MS = 5000;
```

Good:

```
/// Default request timeout: 5000ms.
/// Prevents UI hangs while allowing slow mobile networks.
const REQUEST_TIMEOUT_MS = 5000;
```

### R7 — No TODO comments without an ID or trigger

Bad:

```
// TODO improve this
```

Allowed:

```
// TODO(#123): Replace linear scan with spatial hash once enemy count > 200.
```

Or:

```
// Acceptable for now: max entities <= 50 in current design; revisit if this changes.
```

---

## Public API Doc Standard (Template)

Use only the sections that matter; keep it tight.

1. **One-line summary** (what it does)
2. **Guarantees / invariants** (determinism, ordering, bounds, ownership)
3. **Side effects** (mutation, events, I/O, caching)
4. **Units** (ticks/seconds, scaling factors)
5. **Non-obvious params/returns** (only if needed)

Example:

```
/// Resolves engagement state for melee enemies.
///
/// Guarantees deterministic state transitions for identical inputs.
/// Uses enter/exit hysteresis to prevent range-threshold flapping.
/// Side effect: updates `enemy.intent` (no allocation).
```

---

## Internal Comment Standard (Allowed Patterns)

### Determinism / tie-break

```
// Tie-break by stable id so selection is deterministic across replays.
```

### Ordering dependency

```
// Must run after DamageSystem: relies on final hp to emit death exactly once.
```

### Invariant / safety proof

```
// Invariant: remainingTicks never negative. Clamp after subtract to prevent underflow.
```

### Units / scaling

```
// fixed-point: 100 = 1.0. Multiply before divide to keep precision.
```

### Hot path constraint

```
// Hot path: avoid per-tick allocations (called for every entity every tick).
```

**Hard ban:** comments that just translate the code into English.

---

## Architecture/Contract Docs (When Required)

Write/update an architecture/contract doc when any of these happen:

* a module boundary changes (ownership, responsibilities, data flow)
* a new invariant is introduced (determinism, ordering, units)
* a system’s update order becomes significant
* a tuning rule becomes “locked” (must not drift)

**Rule of thumb:** if reviewing the change requires reconstructing mental models, you need a contract doc update.

---

## Documentation Review Checklist

For the changed slice:

1. **Review public APIs** — ensure callers can use new or changed APIs correctly.
2. **Review reasoning hotspots** — add only the minimal comments needed to
   explain constraints, rationale, or non-obvious behavior.
3. **Remove noise and staleness** — delete name-only, narrative, redundant, or
   outdated comments relevant to the change.
4. **Review contracts** — update relevant architecture or contract docs when
   cross-module behavior, ownership, or invariants change.
5. **Validate** — run the smallest relevant lint, analyzer, and test checks.

---

## Completion Criteria

A change is documentation-complete if:

* Every new or materially changed public API has meaningful docs (purpose +
  constraints)
* No new narration/name-only comments remain in the touched scope
* Comments explain **why/constraints**, not “what”
* Units are stated where ambiguity exists
* Documented constants match code values
* Relevant repository validation checks pass

---

## Policy Maintenance

Update this policy when repository conventions or supported languages change,
including:

* language doc syntax examples
* module/layer naming
* validation commands
* project-specific invariants, such as tick rate or determinism rules
