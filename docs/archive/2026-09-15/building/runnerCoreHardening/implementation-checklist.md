# Runner Core Hardening Checklist

- Date: August 16, 2026
- Status: Proposed; all implementation phases open

Plan: [Runner Core Hardening Plan](plan.md)

This is the live progress record. Check an item only when its code,
documentation, tests, and dated evidence exist. A phase may not be marked
complete because a later phase is expected to replace unfinished work.

## Phase status

| Phase | Outcome | Status |
| --- | --- | --- |
| 0 | Baseline and contract freeze | Not started |
| 1 | Entity identity and lifetime safety | Not started |
| 2 | Input, time, and replay determinism | Not started |
| 3 | Runtime content boundary and admission | Not started |
| 4 | Behavior, character policy, and result identity | Not started |
| 5 | `GameCore` responsibility extraction | Not started |
| 6 | Core closure and extension-contract handoff | Not started |

## Phase 0: baseline and contract freeze

### Repository baseline

- [ ] Record HEAD, platform, Dart/Flutter versions, and relevant working-tree
  changes.
- [ ] Assign ownership for overlapping changed files before implementation.
- [ ] Confirm the current Core audit finding IDs and severities.
- [ ] Confirm entity creation, editor workflows, and source-format decisions are
  outside this program.

### Determinism baseline

- [ ] Define the canonical replay corpus and fixture ownership.
- [ ] Cover movement, terrain transitions, melee, projectile, ability, each
  enemy policy, player death, scoring, and successful run completion.
- [ ] Record snapshot, ordered-event, score, result, and tick-order signatures.
- [ ] Document commands for same-process, fresh-process, and cross-target runs.

### Lifetime and API inventory

- [ ] Inventory every owner/source/target `EntityId` field and consumer.
- [ ] Inventory every `EcsWorld.createEntity`/`destroyEntity` call site.
- [ ] Inventory all direct production `GameCore` mutation.
- [ ] Record long-run entity churn, maximum allocated ID, memory, and time.
- [ ] Confirm tracked Core `.bak` files are non-authoritative, preserve any
  needed recovery copy, and define their Core-source cleanup.

### Validation

- [ ] Run `dart analyze packages/runner_core`.
- [ ] Run `dart test packages/runner_core/test`.
- [ ] Run `flutter test test/core`.
- [ ] Record exact results and unrelated failures.

### Exit gate

- [ ] Baselines are reproducible and committed.
- [ ] Overlapping worktree changes are isolated.
- [ ] No intended gameplay output changed.

### Evidence and notes

- None yet.

## Phase 1: entity identity and lifetime safety

### Failing regressions first

- [ ] Reproduce stale projectile ownership after entity reuse.
- [ ] Reproduce stale hitbox following after entity reuse.
- [ ] Cover damage/proc/source/target references that outlive an entity.
- [ ] Cover zero, negative, never-created, double-destroyed, and already-free
  IDs.
- [ ] Add a deterministic long-run churn benchmark/test fixture.

### Design decision

- [ ] Compare slot-plus-generation references with monotonic run IDs using the
  recorded churn evidence.
- [ ] Record the chosen live-identity/liveness contract in `docs/tdd/**`.
- [ ] Record migration impact for every reference-bearing store and event.
- [ ] Accept a memory/performance budget.

### Implementation

- [ ] Implement allocator live-identity validation.
- [ ] Migrate every persistent owner/source/target reference.
- [ ] Make stale-reference handling explicit at each consumer.
- [ ] Remove the superseded raw-ID lifetime path in the same cutover.
- [ ] Preserve iteration and simulation ordering.

### Validation and exit gate

- [ ] Focused allocator/liveness regressions pass.
- [ ] No stale reference can resolve to a new entity.
- [ ] Invalid destroy cannot create an allocatable ID.
- [ ] Churn benchmark stays within the accepted budget.
- [ ] Core analysis, package tests, root Core tests, and replay corpus pass.

### Evidence and notes

- None yet.

## Phase 2: input, time, and replay determinism

### Core influence boundary

- [ ] Classify command, lifecycle, test-control, and output APIs.
- [ ] Decide and document pause/resume replay semantics.
- [ ] Make tick, terminal state, score/distance, position, velocity, and facing
  read-only to production consumers.
- [ ] Replace direct controller mutation with the accepted lifecycle API.
- [ ] Move unsafe mutation to a dedicated test harness.
- [ ] Add focused tests preventing undocumented production influence.

### Tick-rate contract

- [ ] Decide fixed 60 Hz versus supported configurable rates.
- [ ] Inventory authored tick fields and classify their units.
- [ ] Fix reactive-proc cooldown semantics.
- [ ] Centralize each accepted tick conversion and rounding policy.
- [ ] Align Core, run protocol, validator, and public API validation.
- [ ] Add 30/60/120 Hz tests if configurable rates remain supported.

### Cross-target replay

- [ ] Execute the canonical corpus on a client development target.
- [ ] Execute the same corpus on the Linux validator target.
- [ ] Compare quantized state, ordered events, score, and results.
- [ ] Investigate any float-sensitive mismatch before changing math.
- [ ] Commit stable parity fixtures or CI automation.

### Exit gate

- [ ] Production consumers cannot use unsafe simulation setters.
- [ ] Every authored duration has a documented unit/conversion owner.
- [ ] Supported rates preserve intended duration deterministically.
- [ ] Cross-target replay evidence is green or has an accepted bounded contract.
- [ ] Relevant cross-layer analysis/tests pass.

### Evidence and notes

- None yet.

## Phase 3: runtime content boundary and admission

### Consumer and ownership inventory

- [ ] Inventory character facts and all consumers.
- [ ] Inventory enemy facts and all consumers.
- [ ] Inventory projectile facts and all consumers.
- [ ] Inventory ability, weapon, accessory, and spell-book facts and consumers.
- [ ] Classify every fact as gameplay, visual, UI discovery, protocol,
  validator, or backend product authority.
- [ ] Identify duplicate facts and choose one current owner without migrating
  source format.

### Runtime boundary

- [ ] Design the immutable content bundle/set and compatibility manifest.
- [ ] Inject abilities through the same explicit boundary as other catalogs.
- [ ] Separate gameplay revision from visual-only revision.
- [ ] Update client and validator construction to select the same gameplay
  revision.
- [ ] Reject mismatched revisions before replay.
- [ ] Keep existing Dart catalogs as the only production authority.

### Explicit validation

- [ ] Define stable diagnostic code and field-path types.
- [ ] Replace assertion-only player definition validation.
- [ ] Replace assertion-only ability/catalog validation.
- [ ] Replace assertion-only proc/gear validation in scope.
- [ ] Validate IDs, duplicates, ranges, finite values, references, and set-wide
  integrity explicitly.
- [ ] Prove validators execute with assertions disabled.

### Exit gate

- [ ] Client and validator consume one explicit compatible gameplay set.
- [ ] Mismatch and dangling-reference tests pass.
- [ ] Release-active validation has deterministic diagnostics.
- [ ] No production catalog was converted or generated from a new source.
- [ ] Relevant Core, protocol, Flutter, validator, and backend checks pass.

### Evidence and notes

- None yet.

## Phase 4: behavior, character policy, and result identity

### Enemy behavior policies

- [ ] Inventory every concrete enemy-ID branch in construction, navigation,
  motion, streaming, placement, combat, scoring, snapshots, and rendering.
- [ ] Define closed locomotion policies from existing enemies.
- [ ] Define closed navigation/terrain-contact policies.
- [ ] Define closed spawn-placement policies.
- [ ] Define closed combat-controller and score policies.
- [ ] Register bespoke code policies explicitly where required.
- [ ] Refactor systems to consume policy/capability rather than content ID.
- [ ] Add a reusable-policy fixture that requires no new content-ID branch.

### Character and ability policies

- [ ] Replace unconditional Eloise traversal derivation with definition-selected
  policy.
- [ ] Decide and document `eloiseWip` lifecycle/identity.
- [ ] Replace hard-coded parry and Hashash ability keys with declared policy
  references.
- [ ] Validate policy/ability compatibility through the runtime content set.

### Result identity and compatibility

- [ ] Decide keyed kill records versus an immutable ordinal bridge.
- [ ] Update `run_protocol` and version the payload.
- [ ] Update Core event/result construction.
- [ ] Update Flutter consumers.
- [ ] Update validator persistence/projections.
- [ ] Add historical payload compatibility fixtures.
- [ ] Prove declaration reordering cannot reinterpret results.

### Exit gate

- [ ] Runtime systems contain no concrete content-ID branch where a reusable
  admitted policy is intended.
- [ ] Character traversal is content-policy selected.
- [ ] Historical result payloads remain correctly interpretable.
- [ ] Cross-layer validation and canonical replay corpus pass.

### Evidence and notes

- None yet.

## Phase 5: `GameCore` responsibility extraction

### Construction and content

- [ ] Extract content and derived-tuning construction.
- [ ] Extract world/system bootstrap wiring.
- [ ] Keep dependency ownership and initialization order explicit.

### Pipeline and state

- [ ] Define a named simulation pipeline with the existing readable order.
- [ ] Add/retain a tick-order signature regression.
- [ ] Move mutable run state behind a private owner.
- [ ] Expose read-only output and explicit lifecycle controls.
- [ ] Keep unsafe controls only in the test harness.

### Scope protection

- [ ] Confirm no generic ECS scheduler was introduced.
- [ ] Confirm collision/navigation algorithms were not cosmetically rewritten.
- [ ] Justify any large-file split with a responsibility and parity test.
- [ ] Remove superseded construction/state paths in the same cutover.

### Exit gate

- [ ] Routine catalog wiring does not require editing the tick orchestrator.
- [ ] Simulation phase order remains visible and protected.
- [ ] Canonical replay/snapshot/event/result fixtures remain accepted.
- [ ] Core analysis and all relevant tests pass.

### Evidence and notes

- None yet.

## Phase 6: Core closure and extension-contract handoff

### Finding closure

- [ ] Close RC-H01 with implementation/test evidence.
- [ ] Close RC-H02 with reusable-policy evidence.
- [ ] Close RC-H03 with content/replay compatibility evidence.
- [ ] Close or accept a non-blocking deferral for every Medium finding.
- [ ] Resolve backup hygiene and documentation drift.
- [ ] Record cross-platform replay evidence.

### Core extension contract

- [ ] Document the accepted entity identity and liveness contract.
- [ ] Document allowed simulation influence and lifecycle controls.
- [ ] Document time units and tick conversion ownership.
- [ ] Document runtime content validation and compatibility revision semantics.
- [ ] Document behavior-policy registration and stable result identity.
- [ ] Document replay admission/parity requirements.
- [ ] Record unresolved cross-layer fact ownership without choosing a source
  format, generator, or editor workflow.
- [ ] Mark entity creation and source-format work as deferred to a separate
  future pipeline.

### Final validation

- [ ] Run Core analysis and package/root Core tests.
- [ ] Run protocol analysis/tests if its contract changed.
- [ ] Run validator analysis/tests.
- [ ] Run affected Flutter tests.
- [ ] Run backend build/tests if character/result contracts changed.
- [ ] Run the canonical cross-target replay corpus.
- [ ] Validate all plan/audit/document links.

### Program exit gate

- [ ] No unresolved Core identity, policy, result, validation, or replay blocker
  remains inside this program.
- [ ] The extension contract is complete without selecting a source format or
  starting an editor/content pipeline.
- [ ] This plan and checklist are archived together after all open work closes.

### Evidence and notes

- None yet.
