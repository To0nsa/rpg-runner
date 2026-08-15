# Runner Core remediation roadmap

Implementation sequencing is now owned by the
[Runner Core Hardening Plan](../../building/runnerCoreHardening/plan.md). That
plan contains Core-only work. This file remains the original audit recommendation
for possible future pipelines and does not authorize editor entity creation,
source-format work, or catalog migration.

The roadmap is ordered by dependency and risk reduction. It deliberately avoids
a single rewrite branch. Each milestone should be independently reviewable,
validated, and compatible with the existing deterministic simulation until its
explicit cutover.

## Priority view

| Priority | Milestone | Why now |
| --- | --- | --- |
| P0 | Close editor hardening baseline | The migration will rely on safe multi-artifact writes |
| P0 | Repair entity identity | Correctness issue independent of authoring; stale references corrupt semantics |
| P1 | Define content contract and replay identity | Shared foundation for every authored entity type |
| P1 | Migrate projectiles | Smallest complete vertical slice and generator proof |
| P1 | Generalize and migrate enemies | Largest blocker to editor-created gameplay entities |
| P2 | Generalize and migrate characters | Depends on traversal policy and backend projections |
| P2 | Tighten Core boundary/orchestration | Reduces future change surface without changing tick order |
| P2 | Migrate result identity and expand replay parity CI | Makes ongoing content growth safe |
| P3 | Abilities/gear authoring | Valuable only after special policies and references are stable |

## Milestone 0A: close the editor safety baseline

**Scope**

- Fix the currently failing reordered-argument source-shape test.
- Run the full editor suite, not only the focused subset.
- Reconcile the untracked editor audit and implementation checklist with the
  current working tree.
- Decide where persistent recovery backups live and stop tracking `.bak` files
  as production source.

**Acceptance gates**

- `dart analyze` and the full `tools/editor` Flutter test suite pass.
- Interleaved comments, reordered named arguments, CRLF/LF, first/middle/last
  replacement failure, final drift, and verification rollback are covered.
- The audit marks findings closed only against committed evidence.

## Milestone 0B: repair entity identity

**Scope**

- Write failing tests for stale projectile/hitbox owners after slot reuse.
- Write tests for zero, negative, never-created, and already-destroyed IDs.
- Select generational references or a benchmark-approved monotonic run ID model.
- Update every persisted owner/source/target reference and liveness check.

**Acceptance gates**

- An old reference never resolves to a new entity.
- Invalid destruction cannot insert an allocatable ID.
- Long-run entity churn has a documented memory/performance bound.
- Package and root Core suites remain green with deterministic outcome fixtures.

## Milestone 1: content contract and generation foundation

**Scope**

- Write a focused TDD for source schema, lifecycle, ownership, stable identity,
  validation, generation, and publication.
- Implement common record identity/lifecycle types and field-addressed
  diagnostics.
- Implement schema, semantic, reference, and set-wide validation.
- Implement canonical ordering and atomic multi-projection generation.
- Add immutable `GameContentBundle` with gameplay hash/revision.
- Inject all catalogs, including abilities, through that bundle.
- Define how ticket/session/replay compatibility binds to the content revision.

**Acceptance gates**

- Same source set produces byte-identical generated artifacts and hash across
  repeated runs and supported development platforms.
- Duplicate IDs/ordinals, unknown keys, invalid numbers, and dangling references
  fail before writes.
- Client and validator reject a deliberately mismatched gameplay hash.
- Store publication and entitlements do not change merely because a record is
  valid or active in Core.

## Milestone 2: projectile vertical slice

**Scope**

- Create projectile source records and migrate all existing projectiles.
- Generate Core definitions, Flame render facts, and UI discovery metadata.
- Convert ability/loadout references to validated stable projectile IDs.
- Remove the migrated hand-authored maps/switches and legacy AST projectile
  write path in the same cutover.

**Acceptance gates**

- A fixture projectile can be added through one source record with no manual
  production-source edit.
- Existing projectiles have snapshot, collision, damage, render-registry, and
  replay parity tests before and after migration.
- Generator drift is a CI failure.
- No parallel legacy and generated projectile authority remains.

## Milestone 3: enemy behavior normalization and migration

**Scope**

- Define closed locomotion, navigation, spawn, and combat policies.
- Refactor `EntityFactory`, navigation bundle/system, world motion, track
  streaming, scoring, and `GameCore` spawn placement to consume policy rather
  than concrete content ID.
- Replace enum-index-only kill results with stable keyed records, or complete the
  explicitly versioned ordinal bridge first.
- Migrate existing enemy definitions and abilities/references to authored
  records and generated projections.

**Acceptance gates**

- A test enemy reusing an existing policy set requires no content-ID branch in
  simulation systems.
- Every active enemy has complete spawn, movement, combat, death, score, render,
  and replay coverage.
- Unsupported combinations are rejected with field-addressed diagnostics.
- Old run-result payloads remain interpretable through an explicit migration or
  compatibility path.

## Milestone 4: character generalization and migration

**Scope**

- Move traversal/motion selection into a closed character policy.
- Remove the unconditional Eloise traversal derivation.
- Define animation, tuning, ability namespace, loadout, render, and cast-origin
  reference validation.
- Generate backend known-character projection while retaining explicit starter
  ownership/store publication control.
- Decide whether `eloiseWip` remains a deliberate skin/alias, becomes independent
  content, or is removed from active selection.

**Acceptance gates**

- A fixture character with an admitted policy set is generated without manual
  Core, Flame, UI, validator, or known-ID edits.
- A character cannot become purchasable, owned, or ranked-active solely through
  the editor export.
- Existing Eloise replay and movement fixtures remain identical unless an
  intentional compatibility bump documents the change.

## Milestone 5: Core boundary and orchestration cleanup

This milestone can start in small pieces after `GameContentBundle` exists. It is
not a prerequisite for the schema UI.

**Scope**

- Make run state read-only outside Core.
- Add explicit lifecycle pause/resume and move unsafe mutation to test harnesses.
- Extract construction from `GameCore`.
- Extract a named simulation pipeline while preserving visible phase order.
- Scale reactive-proc authored cooldowns for `tickHz` and audit other raw
  authored tick fields.
- Correct drifted API and package documentation.

**Acceptance gates**

- A tick-order signature test prevents accidental reordering.
- Production code cannot set position, velocity, facing, tick, score, or terminal
  state directly.
- 30/60/120 Hz duration tests pass for every authored time domain that supports
  variable rates.
- No output or replay fixture changes without an explicit reviewed reason.

## Milestone 6: compatibility and parity hardening

**Scope**

- Run a canonical replay corpus on the client-supported and Linux validator
  targets.
- Compare quantized outcomes, ordered events, score, kill records, and content
  revision.
- Add compatibility fixtures for stable IDs, retired content, and old result
  payloads.
- Document publication order for gameplay content changes.

**Acceptance gates**

- Cross-target results match for the canonical corpus.
- A validator deployment cannot accept a run whose content revision it lacks.
- Retired content remains resolvable for admitted historical runs according to
  an explicit retention policy.

## Milestone 7: abilities and gear authoring

Only begin this after players/enemies can safely reference admitted ability and
gear records.

**Scope**

- Replace hard-coded parry/Hashash ability keys with declared policy references.
- Convert assertion-only constraints into the shared validation framework.
- Migrate ability, weapon, accessory, and spell-book definitions one vertical
  slice at a time.
- Keep price, entitlement, rotation, and product publication backend-owned.

**Acceptance gates**

- Adding a data-expressible ability or gear definition needs no runtime switch.
- Mechanics outside the admitted schema require reviewed Core code rather than
  an arbitrary editor script field.
- Client, validator, UI discovery, and backend existence projections share the
  same stable identity without duplicating gameplay tuning.

## Work that should not be bundled into this program

- A wholesale ECS rewrite.
- A replacement of the terrain compiler/capsule controller without a separate
  measured correctness or performance case.
- Runtime loading of unvalidated loose JSON.
- Automatic deployment, store publication, pricing, or ownership grants from
  the editor.
- A generic visual scripting language for enemy/ability behavior.

Those expansions increase risk without being necessary to make entity content
safe, discoverable, and authorable.
