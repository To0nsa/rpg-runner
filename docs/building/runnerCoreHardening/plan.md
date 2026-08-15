# Runner Core Hardening Plan

- Date: August 16, 2026
- Status: Proposed; implementation has not started

Related documents:

- [Implementation checklist](implementation-checklist.md)
- [Runner Core audit](../../audit/runner_core/README.md)
- [Audit findings register](../../audit/runner_core/findings.md)
- [Core authored-content workflow](../../../.agent/workflows/change-core-authored-content.md)

## Purpose

Stabilize `packages/runner_core` by fixing demonstrated correctness problems,
making implicit runtime contracts explicit, and reducing the risk of future
extensions. Existing typed Dart catalogs remain authoritative throughout this
program.

## Separation from future content and editor work

This plan does not own entity creation, editor workflows, catalog migration,
source-format evaluation, schemas, generators, or publication. Those belong to
a separate future work pipeline with its own plan, acceptance criteria, and
authorization.

The only handoff from this program is a documented set of stable Core seams:
entity identity, simulation influence, time semantics, runtime validation,
behavior policies, result identity, and replay compatibility. This plan neither
starts nor schedules the pipeline that may later consume those seams.

## Locked constraints

These constraints are accepted for the hardening program:

1. `runner_core` remains pure Dart and authoritative for deterministic gameplay.
2. The explicit tick order remains visible and parity-protected; this is not a
   generic ECS scheduler or wholesale ECS rewrite.
3. Runtime content remains typed and immutable.
4. Algorithms and new behavior policies remain reviewed Core code. Authoring
   data may select admitted policies but may not contain arbitrary executable
   scripts.
5. Backend pricing, entitlement, ownership, and publication remain backend
   authority.
6. Terrain, level, chunk, prefab, and material JSON pipelines remain unchanged
   unless a separate measured problem justifies reopening them.
7. Client and replay validator must execute the same admitted gameplay facts for
   a run.
8. No phase leaves two active authorities for the same runtime fact.

## Open Core decisions

| Decision | Earliest phase | Valid outcomes |
| --- | --- | --- |
| Entity reference model | Phase 1 | Generational references; benchmark-approved monotonic run IDs; another proven model |
| Supported simulation tick rates | Phase 2 | Strict 60 Hz; correctly scaled configured rates |
| Pause/resume authority | Phase 2 | Explicit out-of-band lifecycle; replayed control contract |
| Runtime content aggregation | Phase 3 | One bundle; a small number of explicitly versioned bundles |
| Enemy result identity | Phase 4 | Stable keyed records; versioned immutable ordinal bridge |

Entity source formats and editor architecture are deliberately absent from this
table. The separate future pipeline owns those decisions.

## Goals

- Eliminate stale entity-reference aliasing and invalid ID recycling.
- Make all production simulation influence explicit and testable.
- Resolve inconsistent tick-rate semantics.
- Establish cross-platform replay evidence before broad content changes.
- Replace assertion-only content admission with explicit diagnostics.
- Make the complete runtime content set injectable and compatibility-aware while
  existing Dart definitions remain authoritative.
- Remove concrete content-ID branching from reusable enemy/player behavior.
- Replace enum-index-only result semantics with a compatibility-safe contract.
- Reduce `GameCore` responsibilities without changing tick behavior.

## Non-goals

- Choosing or prototyping an entity source format.
- Migrating or generating an entity catalog.
- Building or modifying editor entity-creation workflows.
- Reworking terrain, level, chunk, prefab, or material authoring.
- Adding an editor Create button for runtime entities.
- Replacing the terrain compiler, capsule controller, navigation algorithms, or
  ECS storage model without evidence tied to a finding.
- Designing a generic scripting language.
- Changing balance, player-facing mechanics, or content as incidental cleanup.
- Deploying backend, validator, or client artifacts.

## Finding tracker

| Finding | Phase | Required closure evidence |
| --- | --- | --- |
| RC-H01 entity identity aliasing | 1 | Stale and invalid references rejected; churn benchmark recorded |
| RC-H02 concrete enemy-ID behavior | 4 | Reusable policy fixture works without a content-ID system branch |
| RC-H03 unversioned content unit | 3 | Explicit runtime content boundary and run compatibility contract |
| RC-M01 public Core mutation | 2 | Production API is read-only except explicit influence channels |
| RC-M02 assertion-only validation | 3 | Release-active validators with stable diagnostics |
| RC-M03 raw reactive cooldown ticks | 2 | Accepted tick-rate policy and duration tests |
| RC-M04 enum-index kill results | 4 | Versioned keyed/ordinal protocol with compatibility tests |
| RC-M05 `GameCore` concentration | 5 | Construction/pipeline/state seams extracted with parity evidence |
| RC-M06 Eloise-specific player derivation | 4 | Character-selected traversal policy |
| RC-M07 duplicated entity facts | 3 | Consumer inventory and explicit runtime ownership boundaries |
| RC-M08 inconsistent ability injection | 3 and 4 | Ability resolver injected; special keys declared as policy data/code |
| RC-L01 tracked source backups | 0 | Recovery ownership decided; stale backups no longer authoritative |
| RC-L02 documentation drift | Every phase | Touched contracts and active plans agree with implementation |
| RC-R01 cross-platform replay evidence | 2 | Canonical corpus compared on client/validator targets |

## Delivery order

```text
Phase 0: baseline and contract freeze
    -> Phase 1: entity identity
    -> Phase 2: input, time, and replay determinism
    -> Phase 3: runtime content boundary and validation
    -> Phase 4: behavior and identity decoupling
    -> Phase 5: GameCore responsibility extraction
    -> Phase 6: Core closure and extension-contract handoff
```

Phases 1 and the investigation portion of Phase 2 may be prepared in parallel,
but their code changes should land as independently validated milestones.

## Phase 0: baseline and contract freeze

### Objective

Create a trustworthy before-state and prevent incidental redesign from entering
the hardening work.

### Work

- Record the exact source revision and classify overlapping working-tree changes.
- Freeze a canonical replay corpus containing movement, terrain transitions,
  melee, projectiles, abilities, each enemy behavior, death, scoring, and run
  completion.
- Record snapshot/event/result signatures and the existing tick-order signature.
- Record long-run entity allocation/churn and memory behavior.
- Inventory every direct production mutation of `GameCore`.
- Inventory all owner/source/target entity references and their lifetime rules.
- Confirm the tracked `.bak` files under Core are not authoritative, preserve any
  required recovery copy, and remove them from the production-source inventory.
  Changes to editor backup behavior belong to editor maintenance, not this plan.

### Exit gate

- Baseline Core analysis and both Core test suites pass.
- Replay fixtures and benchmark commands are documented and repeatable.
- Every touched worktree path has an owner; unrelated changes remain untouched.
- No gameplay output is intentionally changed in Phase 0.

## Phase 1: entity identity and lifetime safety

### Objective

Close RC-H01 before refactoring systems or content catalogs.

### Investigation

- Reproduce stale projectile, hitbox, damage-source, and target references after
  entity slot reuse.
- Test zero, negative, never-created, already-destroyed, and double-destroy IDs.
- Measure the cost of monotonic IDs under a deliberately long run.
- Compare that evidence with a slot-plus-generation reference model.

### Implementation rules

- Select the smallest model that proves stale references cannot resolve to a new
  entity and has an acceptable long-run memory bound.
- Give `EcsWorld` an explicit live-identity contract.
- Migrate every stored owner/source/target reference; do not fix only projectile
  ownership.
- Keep entity iteration and system ordering unchanged.
- Do not mix behavior-policy or catalog migration into this phase.

### Exit gate

- An old reference cannot name a newly created entity.
- Invalid destruction cannot place an unallocated value in the allocator.
- Every reference-bearing store has liveness tests.
- Long-run memory/performance remains within an accepted, documented budget.
- Replay corpus and Core suites pass without unreviewed outcome changes.

## Phase 2: input, time, and replay determinism

### Objective

Make simulation influence and time semantics explicit before content records can
change them.

### Workstream A: Core influence boundary

- Classify commands, lifecycle controls, test controls, and read-only output.
- Make tick, terminal state, score/distance counters, position, velocity, and
  facing private outside their owning simulation paths.
- Replace direct app mutation of `paused` with the accepted lifecycle/replay
  contract.
- Move unsafe position/velocity controls into a dedicated test harness.
- Add API tests or static consumer checks for forbidden production mutation.

### Workstream B: tick-rate contract

- Decide whether supported runs are fixed at 60 Hz or configurable.
- If configurable, define time units and deterministic rounding once.
- Fix reactive-proc cooldowns and audit every authored `*Ticks` field for its
  time domain.
- Add 30/60/120 Hz duration tests when configurable rates remain supported.
- Align run-ticket, validator, public API, and documentation validation.

### Workstream C: replay parity

- Run the canonical corpus on the client development target and Linux validator
  target.
- Compare quantized state, ordered events, result statistics, and score.
- Investigate float-sensitive projectile/target/ability paths only when the
  corpus produces evidence; do not pre-emptively rewrite math.

### Exit gate

- Production consumers cannot mutate simulation state through undocumented APIs.
- Every authored time value has a named unit and one conversion owner.
- Supported tick rates have identical intended durations with deterministic
  rounding.
- Cross-target corpus outcomes match or an accepted compatibility design records
  the bounded difference.

## Phase 3: runtime content boundary and admission

### Objective

Make existing Dart-authored content a coherent, validated runtime input before
considering how future authors write it.

### Work

- Inventory every gameplay and presentation field and every Core, Flame, UI,
  protocol, validator, and backend consumer for characters, enemies,
  projectiles, abilities, and gear.
- Define a typed immutable runtime content boundary (`GameContentBundle` or an
  equivalently explicit small set).
- Inject abilities through the same boundary as other catalogs.
- Separate gameplay content identity from visual-only identity.
- Define an explicit compatibility manifest/revision for the current Dart
  content; do not pretend it is a generated source hash.
- Define how run tickets/sessions/replays select or validate the admitted
  gameplay revision.
- Convert assertion-only catalog checks into explicit, release-active validators
  with stable codes and field paths.
- Validate cross-catalog references as a complete set.
- Keep existing Dart constants/catalogs authoritative throughout this phase.

### Exit gate

- Client and validator construct Core from the same explicit content boundary.
- A deliberately mismatched revision is rejected before replay.
- Malformed and dangling-reference fixtures produce stable diagnostics with
  assertions disabled.
- Existing Dart catalogs remain the only production content authority.

## Phase 4: behavior, character policy, and result identity

### Objective

Remove content-ID assumptions that would make a future generated record
incomplete or dishonest.

### Enemy behavior

- Define closed locomotion, navigation, spawn-placement, combat-controller, and
  score policies from existing behavior—not hypothetical future features.
- Make entity construction, terrain graph publication, motion, navigation,
  track streaming, spawn placement, and scoring consume those policies.
- Retain explicit bespoke policy implementations where behavior is genuinely
  unique, but register them by reviewed policy identity rather than scattered
  content-ID branches.

### Player and ability policy

- Move traversal selection out of the Eloise-specific derived path.
- Define whether `eloiseWip` is a skin/alias, independent character, or inactive
  WIP as a Core/runtime contract.
- Inject ability resolution and replace hard-coded parry/Hashash ability keys
  with declared reviewed policy references.

### Result and backend identity

- Replace `EnemyId.index` kill-result semantics with stable keyed records, or
  implement a versioned immutable ordinal bridge with a documented migration to
  keyed records.
- Update `run_protocol`, Flutter consumers, validator persistence/projection, and
  compatibility fixtures together.
- Generate nothing yet; backend known-character metadata remains explicitly
  maintained until a later ownership decision.

### Exit gate

- A test definition can reuse an admitted enemy policy set without adding a
  concrete content-ID branch to a simulation system.
- Character traversal is selected by definition/policy, not an unconditional
  Eloise factory.
- Reordering declarations cannot reinterpret persisted kill results.
- Historical payload fixtures remain readable under an explicit version rule.

## Phase 5: `GameCore` responsibility extraction

### Objective

Reduce the change surface that the later content work will touch without hiding
or reordering the simulation.

### Work

- Extract content/derived-tuning construction from tick execution.
- Extract world/system wiring behind a named bootstrap seam.
- Extract an explicit simulation pipeline only if its phase order remains
  readable in one place.
- Move mutable run state behind a private owner and read-only output API.
- Retain a dedicated test harness rather than production unsafe setters.
- Split collision, motion, or ability algorithm files only when a separately
  measured responsibility and parity test justify it.

### Exit gate

- `GameCore` no longer changes for routine catalog wiring or test-only mutation.
- A tick-order signature prevents accidental phase reordering.
- Replay corpus, snapshots, events, score, and result fixtures remain identical
  unless an explicitly approved compatibility change says otherwise.
- No generic scheduler or broad algorithm rewrite was introduced.

## Phase 6: Core closure and extension-contract handoff

### Objective

Conclude Core hardening and document the stable seams that future, separately
authorized work may consume.

### Work

- Re-run the entire validation matrix and canonical cross-target replay corpus.
- Close or explicitly defer every audit finding with evidence and an owner.
- Publish a focused Core extension contract covering entity identity, allowed
  simulation influence, time units, runtime content validation, behavior-policy
  registration, stable result identity, and replay compatibility.
- Record which duplicated cross-layer facts still need an owner without choosing
  how a future pipeline will author or generate them.
- Mark entity creation, source formats, schemas, generators, and editor workflow
  as deferred and unstarted.
- Update relevant TDD/GDD documents and Core AGENTS guidance if ownership or
  workflow changed.
- Move this plan to `docs/building/archived/runnerCoreHardening/` only after no
  hardening phase remains open.

### Program exit gate

- RC-H01, RC-H02, and RC-H03 are closed.
- All Medium findings are closed or have an accepted, non-blocking deferral that
  cannot undermine Core or replay integrity.
- Core, protocol, validator, Flutter, and backend checks required by the touched
  slices pass.
- The extension contract describes what is stable without selecting a source
  format or starting an editor/content pipeline.

## Validation matrix

Run the smallest relevant checks after each coherent change and the full matrix
at phase boundaries.

| Slice | Required checks |
| --- | --- |
| Core-only | `dart analyze packages/runner_core`; `dart test packages/runner_core/test`; relevant `flutter test test/core/...` |
| Shared result/replay contract | Core checks; `dart analyze packages/run_protocol`; `dart test packages/run_protocol/test`; affected Flutter and validator tests |
| Validator compatibility | `dart analyze services/replay_validator`; `dart test services/replay_validator/test` |
| Backend character/existence contract | `corepack pnpm --dir functions build`; `corepack pnpm --dir functions test` |
| Cross-target replay | Canonical corpus on supported client-development and Linux validator targets |

Record exact commands, counts, platform, date, and any unrelated worktree
failure in the checklist evidence section. A broad green suite does not replace
a focused regression for the changed invariant.

## Commit and documentation discipline

- Land one independently validated contract change per commit.
- Do not mix identity, tick-rate, behavior-policy, and protocol work in one
  commit.
- Do not commit generated drift, known failures, or unrelated user changes.
- Update TDD documents in the same milestone as determinism, ordering,
  persistence, API, protocol, or ownership changes.
- Update GDD documents only when intended player-facing behavior changes; this
  hardening plan should normally preserve it.
- Record decisions and rejected alternatives. Do not rewrite plan history to make
  an uncertain choice appear predetermined.

## Rollback principles

- Prefer additive seams followed by one tested cutover and immediate legacy
  deletion within the same milestone.
- Keep compatibility readers only when historical persisted/replay data requires
  them; document their retirement condition.
- If a phase changes canonical replay outcomes unexpectedly, stop and classify
  the difference before continuing.
- Never weaken determinism, validation, or compatibility checks to make a phase
  pass.

## Initial decision log

| Date | Decision | Status |
| --- | --- | --- |
| 2026-08-16 | Run Core hardening as an independent program | Accepted |
| 2026-08-16 | Keep terrain/level JSON pipelines outside this plan | Accepted |
| 2026-08-16 | Keep runtime content typed and immutable | Accepted |
| 2026-08-16 | Defer entity creation and source-format decisions to a separate future pipeline | Accepted |
