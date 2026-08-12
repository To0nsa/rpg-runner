# Capsule Target Combat Narrow Phase Implementation Checklist

Status: proposed; implementation has not started.

Strategy:
[capsule-target-narrowphase-strategy.md](capsule-target-narrowphase-strategy.md)

## Phase 0 — Freeze baseline and rollout decision

- [ ] Capture focused baseline results for hit resolver, projectile,
  hitbox-damage, mobility-impact, determinism, and replay-validator tests.
- [ ] Record the current replay benchmark result for Field and Forest at
  36,000 ticks with `--strict`.
- [ ] Confirm that every production damageable actor is created with
  `WorldContactCapsuleStore` and `ColliderAabbStore` entries.
- [ ] Enumerate any production `HealthStore` entity that is not a player or
  enemy; either give it an explicit capsule or remove it from this migration.
- [ ] Confirm operational authority to pause ranked starts and drain
  `rules-v1` sessions before the final cutover.
- [ ] Freeze boundary behavior: capsule tangency counts as a hit.

Gate: implementation does not start until damageable-target coverage and the
hard `rules-v2` cutover are confirmed.

## Phase 1 — Add exact combat capsule geometry

- [ ] Replace the conservative capsule/AABB-corner assumption in focused tests
  with an exact capsule/capsule contract.
- [ ] Add an allocation-free finite-segment squared-distance helper under
  `packages/runner_core/lib/ecs/hit/`.
- [ ] Add the capsule/capsule overlap predicate using summed radii.
- [ ] Define and document handling for:
  - [ ] crossing segments;
  - [ ] parallel separated and overlapping segments;
  - [ ] endpoint contact;
  - [ ] tangent capsules;
  - [ ] empty-corner AABB overlap with separated capsules;
  - [ ] zero-length spine/circle cases;
  - [ ] large and very small valid world-unit values.
- [ ] Keep comparisons deterministic and free of wall-clock, random, or
  platform-specific inputs.
- [ ] Add focused unit tests in the Core package test suite rather than relying
  only on Flutter integration coverage.

Gate: the geometry suite proves both positive contact and AABB-corner
rejection before resolver code changes.

## Phase 2 — Make the target cache capsule-aware

- [ ] Extend `DamageableTargetCache` with reusable parallel arrays for target
  capsule spine endpoints and radius.
- [ ] Resolve facing-aware capsule `offsetX` consistently with terrain motion
  and the existing collider-facing convention.
- [ ] Convert stored 1/1024-world-unit capsule values to the combat world-unit
  representation at cache rebuild, once per target rather than once per query.
- [ ] Derive each spatial-grid AABB from the cached capsule representation.
- [ ] Add an invariant failure for a damageable combat target without a
  capsule; do not silently confirm it with its rectangle.
- [ ] Preserve health dense-order population and stable entity identities.
- [ ] Prove with tests that:
  - [ ] the enclosing AABB contains both spine endpoints plus radius;
  - [ ] left/right facing mirrors only the authored horizontal offset;
  - [ ] vertical offset and capsule dimensions do not change with facing;
  - [ ] removed/dead entities do not remain cached;
  - [ ] a malformed damageable world fails deterministically.

Gate: the grid returns every possible capsule candidate without making the
grid itself responsible for exact hit decisions.

## Phase 3 — Centralize shape-aware hit resolution

- [ ] Update `HitResolver.collectOrderedOverlapsCapsule` to confirm attack
  capsule versus cached target capsule.
- [ ] Update `HitResolver.firstOrderedOverlapCapsule` with the same predicate.
- [ ] Retain owner exclusion and faction filtering before hit delivery.
- [ ] Retain stable `EntityId` ordering before selecting the first real
  narrow-phase hit.
- [ ] Add a regression where the lowest-ID broad-phase candidate fails the
  capsule test and the next valid candidate is selected.
- [ ] Add a regression where a query overlaps only the target's former AABB
  corner and returns no target.
- [ ] Remove rectangle-confirmation resolver APIs after all production callers
  migrate; do not leave an unused alternate combat path.
- [ ] Review nearby API documentation so it says capsule target rather than
  target bounds/AABB.

Gate: `HitResolver` is the only combat target-overlap authority.

## Phase 4 — Migrate every damage-producing overlap path

### Melee and area hitboxes

- [ ] Keep existing oriented attack-capsule construction.
- [ ] Route all hitbox target confirmation through the new resolver behavior.
- [ ] Preserve `HitPolicy`, `HitOnceStore`, combo arming, riposte consumption,
  source attribution, and damage-queue order.

### Projectiles

- [ ] Keep existing direction-oriented projectile capsule construction.
- [ ] Migrate both non-piercing first-hit and piercing all-hit paths.
- [ ] Preserve lowest-entity selection, piercing counts, deferred despawn,
  owner detachment, hit events, and source attribution.

### Mobility impacts

- [ ] Construct the source overlap shape from its upright actor capsule rather
  than its AABB.
- [ ] Confirm source capsule versus target capsule through `HitResolver`.
- [ ] Preserve `everyTick`, `once`, and `oncePerTarget` bookkeeping.
- [ ] Preserve status-only, damage-only, and combined impact behavior.

### Cleanup

- [ ] Remove dead AABB-versus-AABB combat helpers and stale comments from the
  migrated paths.
- [ ] Keep AABB utilities still required by pickups, culling, render debug,
  cast origins, and other non-combat consumers.
- [ ] Do not change `GameCore.stepOneTick` phase order.

Gate: repository search finds no damage-confirming actor target path that uses
an AABB narrow phase.

## Phase 5 — Update authoring and debug visibility

- [ ] Render player/enemy capsules in the entity editor from the same
  `halfX`/`halfY` derivation used by Core.
- [ ] Render the tight broad-phase AABB as a secondary debug outline.
- [ ] Explain the radius and vertical-half-spine derivation in the inspector.
- [ ] Keep writes bound to the existing player/enemy catalog fields.
- [ ] Add widget tests for tall capsule, circle, offset, facing-preview, and
  invalid-dimension states.
- [ ] Confirm projectile collider presentation remains accurate for its
  direction-oriented attack capsule.

Gate: an author can see both the actual actor hit shape and its broad-phase
enclosure without editing JSON or Dart manually.

## Phase 6 — Lock behavior in tests and documentation

- [ ] Add/update focused tests for:
  - [ ] `HitResolver` ordering and corner rejection;
  - [ ] `HitboxDamageSystem` melee/area behavior;
  - [ ] `ProjectileHitSystem` piercing and non-piercing behavior;
  - [ ] `MobilityImpactSystem` damage/status hit policies;
  - [ ] player and all enemy capsule attachment;
  - [ ] facing-aware offsets;
  - [ ] repeated-run deterministic event/state hashes.
- [ ] Add a replay-validator fixture whose result depends on capsule corner
  rejection and assert the new authoritative result.
- [ ] Update `docs/tdd/terrain_capsule_controller.md`.
- [ ] Update `docs/tdd/sloped_navigation_and_enemy_terrain.md`.
- [ ] Update `docs/tdd/runner_core_simulation_contract.md`.
- [ ] Update `docs/gdd/combat/combat_system_design.md`.
- [ ] Update `tools/editor/README.md`.
- [ ] Update replay-validator deployment/runbook documentation for
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
- [ ] Change the configured/default ranked ruleset to `rules-v2` while keeping
  `score-v1` only if scoring logic is unchanged.
- [ ] Update validator supported rulesets for the hard cutover.
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
