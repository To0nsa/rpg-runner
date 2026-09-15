# Capsule Target Combat Narrow Phase Strategy

Status: implemented and validated locally; production ranked drain and deploy
remain pending.

Companion checklist:
[capsule-target-narrowphase-implementation-checklist.md](capsule-target-narrowphase-implementation-checklist.md)

## Decision

Character combat collision will use the same upright capsule currently owned by
`WorldContactCapsuleStore` as its target hurt shape. The broad-phase spatial
grid will continue to index a tight axis-aligned bounding box (AABB) around
that capsule. A broad-phase candidate becomes a hit only after an exact
attack-shape-versus-target-capsule test.

```text
actor capsule -> tight enclosing AABB -> broad-phase candidate lookup
                                      -> capsule narrow-phase confirmation
                                      -> deterministic hit ordering/damage
```

This is a ruleset change. It does not change replay command encoding, but it
can change which attacks land and therefore can change health, deaths, score,
and run outcome. Ranked rollout must use `rules-v2`; `score-v1` may remain if
the score formula itself is unchanged.

## Pre-cutover problem

Before this implementation, the runtime already gave the player and current
enemies upright capsules for polygon-terrain contact, but combat did not use
those target shapes:

- `BroadphaseGrid` cached damageable target AABBs.
- melee/area hitboxes and projectiles queried with capsule-shaped attacks but
  confirmed against target AABBs;
- mobility impacts confirmed source AABB against target AABB;
- the target AABB is the capsule's enclosing rectangle, so its four empty
  corner regions could receive damage.

The existing `capsuleIntersectsAabb` helper expands the rectangle on each axis
and performs a segment/rectangle test. That is conservative at the expanded
corners rather than an exact Euclidean capsule/rectangle test. It must not be
reused as the basis of the new exact character narrow phase.

## Required outcome

- Broad phase remains an allocation-conscious spatial hash over AABBs.
- A character's broad-phase AABB is calculated from the same quantized capsule
  used by its combat narrow phase, so the index cannot omit a real capsule hit.
- Melee/area hitboxes, projectiles, and mobility impacts all confirm against
  target capsules.
- Empty AABB-corner overlap is rejected.
- Capsule tangency counts as contact, matching the current capsule attack
  paths' inclusive boundary behavior.
- Owner/faction filtering, stable `EntityId` ordering, piercing limits,
  hit-once policies, damage attribution, and system ordering do not change.
- Every damageable combat target must have an explicit target capsule. Missing
  capsule state is an invalid world composition, not a silent AABB fallback.
- The implementation remains deterministic and allocation-free in per-target
  narrow-phase loops.

## Scope

### Included

- the combat geometry kernel under `packages/runner_core/lib/ecs/hit/`;
- the damageable target cache and broad-phase bounds it publishes;
- `HitResolver` APIs and target-shape confirmation;
- melee/area, projectile, and mobility-impact collision paths;
- actor construction invariants for player and enemies;
- focused geometry, resolver, system, determinism, and replay-validation tests;
- entity-editor visualization of the derived actor capsule and its enclosing
  broad-phase AABB;
- TDD/GDD updates and the ranked `rules-v2` rollout gate.

### Excluded

- polygon-terrain collision behavior or terrain-controller ordering;
- attack tuning, damage amounts, cooldowns, or scoring formulas;
- swept combat collision/continuous collision detection between ticks;
- animation-frame-specific hurtboxes;
- independently authored movement and combat capsules;
- rectangular damageable props. A future prop system must introduce an
  explicit combat target-shape contract rather than restoring an implicit AABB
  fallback.

## Shape ownership

For this cutover, `WorldContactCapsuleStore` remains the single actor capsule
source. This prevents movement and combat geometry from drifting during the
initial migration.

The source definitions remain the existing catalog dimensions:

- player `colliderWidth`, `colliderHeight`, and offsets;
- enemy `ColliderAabbDef` dimensions and offsets.

`WorldContactCapsuleDef.fromAabb` continues to compile those values once:

```text
radius = halfX
verticalHalfSegment = max(halfY - halfX, 0)
```

The editor may present the result as a capsule, but it must write through the
existing catalog-bound fields. Introducing an independently tunable combat
hurtbox would be a separate gameplay/content migration.

## Target-cache contract

`DamageableTargetCache` remains the per-tick input to `BroadphaseGrid`, but its
character entries gain the world-space capsule representation needed by the
narrow phase:

- upper spine endpoint `(ax, ay)`;
- lower spine endpoint `(bx, by)`;
- radius;
- tight AABB center and half extents derived from those exact cached values.

Capsule values are resolved from `WorldContactCapsuleStore` using its
1/1024-world-unit dimensions and its facing-aware horizontal offset. The
broad-phase AABB must be derived from these resolved values rather than copied
from `ColliderAabbStore`; this avoids microscopic enclosure drift between the
authored double offsets and the quantized authoritative capsule.

The cache continues to preserve `HealthStore.denseEntities` iteration order.
The resolver continues to sort candidates by `EntityId` before confirming or
selecting hits.

## Narrow-phase geometry

All current damaging attack paths can be represented as capsules:

| Producer | Source shape after cutover | Target shape |
| --- | --- | --- |
| Melee/area hitbox | Existing oriented capsule | Upright actor capsule |
| Projectile | Existing direction-oriented capsule | Upright actor capsule |
| Mobility impact | Source actor's upright capsule | Upright actor capsule |

Capsule/capsule overlap is true when the squared minimum distance between the
two finite spine segments is less than or equal to the squared sum of their
radii. The kernel must cover parallel, crossing, point-segment, and point-point
degeneracies without allocating temporary objects. Zero spine length is a
circle, not an error.

The combat kernel should live in the combat hit layer and use world-unit
doubles, because current attack capsules contain arbitrary direction vectors
and world-unit values. It may reuse the proven closest-segment algorithmic
approach from the terrain kernel, but combat must not depend on terrain edges,
terrain contact tolerances, or terrain response objects.

## Resolver and system migration

`HitResolver` remains responsible for:

1. querying the AABB spatial grid;
2. sorting candidate indices by stable entity ID;
3. excluding owner and allied factions;
4. confirming capsule/capsule overlap;
5. returning all confirmed targets or the first confirmed target.

The current rectangle-confirmation APIs are removed after their production
callers and tests migrate. This prevents new combat code from accidentally
reintroducing AABB narrow-phase decisions.

`MobilityImpactSystem` must construct its source capsule from the active
actor's `WorldContactCapsuleStore` entry instead of `ColliderAabbStore`.
Hit-once/every-tick policy evaluation remains after geometric confirmation.

No `GameCore.stepOneTick` phase moves. Broad phase is still rebuilt after
actor motion and before projectile movement and hit resolution.

## Editor strategy

The entity scene should make the effective runtime behavior visible:

- player/enemy actors render their derived upright capsule as the primary
  collider outline;
- the tight enclosing AABB is available as a subdued broad-phase/debug outline;
- the inspector explains that `halfX` becomes radius and
  `halfY - halfX` becomes vertical half-spine;
- invalid actor dimensions and missing capsule derivation block save rather
  than previewing a shape the runtime cannot use.

This is a visualization and validation change, not a new authoring schema.
Projectile authoring continues to display its oriented attack-capsule meaning.

## Compatibility and rollout

The replay blob and command versions stay unchanged because no serialized input
shape changes. The gameplay ruleset must change because identical input frames
can produce different hit results.

The repository currently has one Core behavior implementation rather than a
version-dispatched historical simulator. The rollout therefore uses a hard
ruleset cutover instead of keeping the AABB narrow phase beside the capsule
path:

1. pause issuance of new ranked `rules-v1` sessions;
2. drain or explicitly close every issued/pending `rules-v1` session;
3. deploy the client and replay validator built from the capsule rules;
4. configure/provision ranked boards as `rules-v2` + `score-v1`;
5. make the validator accept `rules-v2` and reject new `rules-v1` work;
6. reopen ranked session issuance and verify validation, projection, and ghost
   publication on the new board identity.

Repository implementation defaults board provisioning to `rules-v2`, selects
the complete configured ruleset/score/ghost tuple for session and leaderboard
reads, and makes the validator accept only `rules-v2`. Production completed the
hard cutover on August 12, 2026. The owner explicitly abandoned the one
remaining pre-cutover `rules-v1` session instead of retaining the historical
AABB simulator or delaying deployment.

Old `rules-v1` ghosts and leaderboard entries must not be exposed as
`rules-v2` results. If product requirements demand continued validation or
playback of old sessions, implementation must stop and introduce a separately
reviewed version-dispatch strategy before rollout.

## Documentation impact

The implementation updates the terrain/navigation TDDs, Core simulation
contract, combat GDD, editor guide, Functions board documentation, and replay
validator deployment/runbook documentation. Those documents distinguish the
derived broad-phase AABB from exact capsule target confirmation. The archived
implementation checklist and rollout note hold the completed production
cutover evidence.

## Completion criteria

The strategy is complete only when:

- a query intersecting only an actor AABB corner produces no damage;
- a tangent attack produces one deterministic contact;
- melee, projectile, piercing, and mobility policies retain their existing
  ordering and deduplication behavior;
- player and every current enemy are proven to carry a capsule before broad
  phase rebuild;
- broad-phase bounds are proven to contain the cached target capsule;
- deterministic fixtures produce identical results on repeated runs;
- client and replay validator run the same Core behavior under `rules-v2`;
- relevant Core, root gameplay, editor, and replay-validator checks pass;
- the active plans are archived after implementation and rollout evidence is
  recorded.
