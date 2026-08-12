# Capsule Target Combat Narrow Phase Implementation Checklist

Status: implementation complete and validated locally; production ranked
drain, deployment, and end-to-end rollout verification remain pending.

Strategy:
[capsule-target-narrowphase-strategy.md](capsule-target-narrowphase-strategy.md)

## Phase 0 — Freeze baseline and rollout decision

- [x] Capture focused baseline results for hit resolver, projectile,
  hitbox-damage, mobility-impact, determinism, and replay-validator tests.
- [x] Record the current replay benchmark result for Field and Forest at
  36,000 ticks with `--strict`.
- [x] Confirm that every production damageable actor is created with
  `WorldContactCapsuleStore` and `ColliderAabbStore` entries.
- [x] Enumerate any production `HealthStore` entity that is not a player or
  enemy; either give it an explicit capsule or remove it from this migration.
- [ ] Confirm operational authority to pause ranked starts and drain
  `rules-v1` sessions before the final cutover.
- [x] Freeze boundary behavior: capsule tangency counts as a hit.

Gate: implementation required damageable-target coverage and a frozen hard
`rules-v2` strategy. External cutover authority remains a deployment gate.

Baseline evidence at `11b98224` (36,000 ticks, AOT, `--strict`): Field
`0.332417 s` / `1804.96x` real time; Forest `0.45905 s` / `1307.05x` real
time. Both deterministic outcome checks passed.

## Phase 1 — Add exact combat capsule geometry

- [x] Replace the conservative capsule/AABB-corner assumption in focused tests
  with an exact capsule/capsule contract.
- [x] Add an allocation-free finite-segment squared-distance helper under
  `packages/runner_core/lib/ecs/hit/`.
- [x] Add the capsule/capsule overlap predicate using summed radii.
- [x] Define and document handling for:
  - [x] crossing segments;
  - [x] parallel separated and overlapping segments;
  - [x] endpoint contact;
  - [x] tangent capsules;
  - [x] empty-corner AABB overlap with separated capsules;
  - [x] zero-length spine/circle cases;
  - [x] large and very small valid world-unit values.
- [x] Keep comparisons deterministic and free of wall-clock, random, or
  platform-specific inputs.
- [x] Add focused unit tests in the Core package test suite rather than relying
  only on Flutter integration coverage.

Gate: the geometry suite proves both positive contact and AABB-corner
rejection before resolver code changes.

## Phase 2 — Make the target cache capsule-aware

- [x] Extend `DamageableTargetCache` with reusable parallel arrays for target
  capsule spine endpoints and radius.
- [x] Resolve facing-aware capsule `offsetX` consistently with terrain motion
  and the existing collider-facing convention.
- [x] Convert stored 1/1024-world-unit capsule values to the combat world-unit
  representation at cache rebuild, once per target rather than once per query.
- [x] Derive each spatial-grid AABB from the cached capsule representation.
- [x] Add an invariant failure for a damageable combat target without a
  capsule; do not silently confirm it with its rectangle.
- [x] Preserve health dense-order population and stable entity identities.
- [x] Prove with tests that:
  - [x] the enclosing AABB contains both spine endpoints plus radius;
  - [x] left/right facing mirrors only the authored horizontal offset;
  - [x] vertical offset and capsule dimensions do not change with facing;
  - [x] removed/dead entities do not remain cached;
  - [x] a malformed damageable world fails deterministically.

Gate: the grid returns every possible capsule candidate without making the
grid itself responsible for exact hit decisions.

## Phase 3 — Centralize shape-aware hit resolution

- [x] Update `HitResolver.collectOrderedOverlapsCapsule` to confirm attack
  capsule versus cached target capsule.
- [x] Update `HitResolver.firstOrderedOverlapCapsule` with the same predicate.
- [x] Retain owner exclusion and faction filtering before hit delivery.
- [x] Retain stable `EntityId` ordering before selecting the first real
  narrow-phase hit.
- [x] Add a regression where the lowest-ID broad-phase candidate fails the
  capsule test and the next valid candidate is selected.
- [x] Add a regression where a query overlaps only the target's former AABB
  corner and returns no target.
- [x] Remove rectangle-confirmation resolver APIs after all production callers
  migrate; do not leave an unused alternate combat path.
- [x] Review nearby API documentation so it says capsule target rather than
  target bounds/AABB.

Gate: `HitResolver` is the only combat target-overlap authority.

## Phase 4 — Migrate every damage-producing overlap path

### Melee and area hitboxes

- [x] Keep existing oriented attack-capsule construction.
- [x] Route all hitbox target confirmation through the new resolver behavior.
- [x] Preserve `HitPolicy`, `HitOnceStore`, combo arming, riposte consumption,
  source attribution, and damage-queue order.

### Projectiles

- [x] Keep existing direction-oriented projectile capsule construction.
- [x] Migrate both non-piercing first-hit and piercing all-hit paths.
- [x] Preserve lowest-entity selection, piercing counts, deferred despawn,
  owner detachment, hit events, and source attribution.

### Mobility impacts

- [x] Construct the source overlap shape from its upright actor capsule rather
  than its AABB.
- [x] Confirm source capsule versus target capsule through `HitResolver`.
- [x] Preserve `everyTick`, `once`, and `oncePerTarget` bookkeeping.
- [x] Preserve status-only, damage-only, and combined impact behavior.

### Cleanup

- [x] Remove dead AABB-versus-AABB combat helpers and stale comments from the
  migrated paths.
- [x] Keep AABB utilities still required by pickups, culling, render debug,
  cast origins, and other non-combat consumers.
- [x] Do not change `GameCore.stepOneTick` phase order.

Gate: repository search finds no damage-confirming actor target path that uses
an AABB narrow phase.

## Phase 5 — Update authoring and debug visibility

- [x] Render player/enemy capsules in the entity editor from the same
  `halfX`/`halfY` derivation used by Core.
- [x] Render the tight broad-phase AABB as a secondary debug outline.
- [x] Explain the radius and vertical-half-spine derivation in the inspector.
- [x] Keep writes bound to the existing player/enemy catalog fields.
- [x] Add model/widget tests for tall capsule, circle, offset, facing-preview, and
  invalid-dimension states.
- [x] Confirm projectile collider presentation remains accurate for its
  direction-oriented attack capsule.

Gate: an author can see both the actual actor hit shape and its broad-phase
enclosure without editing JSON or Dart manually.

## Phase 6 — Lock behavior in tests and documentation

- [x] Add/update focused tests for:
  - [x] `HitResolver` ordering and corner rejection;
  - [x] `HitboxDamageSystem` melee/area behavior;
  - [x] `ProjectileHitSystem` piercing and non-piercing behavior;
  - [x] `MobilityImpactSystem` damage/status hit policies;
  - [x] player and all enemy capsule attachment;
  - [x] facing-aware offsets;
  - [x] repeated-run deterministic event/state behavior.
- [x] Add a replay-validator-side Core fixture whose result depends on capsule
  corner rejection and assert the new authoritative result.
- [x] Update `docs/tdd/terrain_capsule_controller.md`.
- [x] Update `docs/tdd/sloped_navigation_and_enemy_terrain.md`.
- [x] Update `docs/tdd/runner_core_simulation_contract.md`.
- [x] Update `docs/gdd/combat/combat_system_design.md`.
- [x] Update `tools/editor/README.md`.
- [x] Update replay-validator deployment/runbook documentation for
  `rules-v2`.

Gate: no active documentation still claims that actor combat confirmation uses
the derived AABB.

## Phase 7 — Validate locally

- [ ] `dart format` all changed Dart files.
- [ ] `dart analyze packages/runner_core`.
- [ ] From `packages/runner_core`, run `dart test`.
- [ ] Run focused root combat tests before the full root Core suite.
- [ ] Run `flutter test test/core`.
- [ ] From `tools/editor`, run `dart analyze` and `flutter test`.
- [ ] From `services/replay_validator`, run `dart analyze` and `dart test test`.
- [ ] Compile the replay-validator executable.
- [ ] Run the replay benchmark for Field and Forest with
  `benchmark --ticks=36000 --strict`.
- [ ] Compare allocation/performance evidence with the Phase 0 baseline and
  investigate any regression before rollout.
- [ ] Inspect `git diff --check` and confirm generated files were not edited by
  hand.

Gate: all relevant checks pass from one commit before deployment begins.

## Phase 8 — Cut over ranked rules safely

- [ ] Pause issuance of new ranked `rules-v1` sessions.
- [ ] Verify that every issued/pending `rules-v1` session is drained or closed.
- [ ] Confirm no replay-validation tasks for `rules-v1` remain in flight.
- [x] Change the repository default ranked ruleset to `rules-v2` while keeping
  `score-v1` only if scoring logic is unchanged.
- [x] Update validator supported rulesets for the hard cutover.
- [ ] Provision and verify new board manifests keyed by `rules-v2`.
- [ ] Deploy validator and client artifacts built from the same reviewed Core
  commit.
- [ ] Reopen ranked starts only after readiness checks pass.
- [ ] Submit and validate one controlled run that exercises melee, projectile,
  and mobility contact.
- [ ] Verify settlement, leaderboard projection, and ghost publication land on
  the `rules-v2` board identity.
- [ ] Verify old `rules-v1` ghosts/results are not exposed as `rules-v2`.
- [ ] Record commit IDs, deployed revisions, configuration, timestamps, and
  verification evidence in a rollout note.

Gate: ranked client simulation and replay validation agree under `rules-v2`
with no old-session ambiguity.

## Phase 9 — Close the plan

- [ ] Run a final repository search for stale AABB-combat claims and obsolete
  rectangle-confirmation APIs.
- [ ] Confirm the completion criteria in the strategy document.
- [ ] Move both plan documents to `docs/building/archived/combat/`.
- [ ] Update any active links after the move.
- [ ] Commit the closure and rollout evidence.
