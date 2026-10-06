# Derf transformation and combat

Derf retains one `EnemyId.derf` entity, health pool, scoring identity and terrain
capsule across `caster`, `transforming`, and `twisted` phases in `DerfPhaseStore`.
Death remains owned by the existing death lifecycle.

## Phase authority and ordering

`DerfTransformationSystem` runs after lock refresh before AI, and again after
Core camera movement. The second pass makes the first visible snapshot already
transform. Visibility is positive-area body-AABB overlap with both camera axes;
transparent sprite padding and render-only camera shake cannot activate it.

Caster phase holds movement, navigation and melee locks for one tick at a time.
It retains original predicted-target explosions, mana/regeneration, cast timing
and cooldown, including casting before entering the camera. Visibility latches
the transformation start tick and clears active/transient ability state. Pending
casts cannot release afterward. Already-released world-anchored impacts retain
their existing damage, credit and lifetime.

Transformation blocks movement and offense for the quantized full strip duration.
At 60 Hz, `.08` seconds rounds to five ticks per frame: 12 frames take 60 ticks.
Hit/stun cannot replace or restart this pose; longer stun/control locks still
prevent action afterward. Death overrides transformation. Phase locks expire
naturally rather than clearing unrelated locks. Twisted phase never reverts;
`EnemyCastSystem` rejects its casts and shared ground AI owns pursuit/melee.

## Terrain and combat

Derf is grounded and dynamic from spawn. Its immutable capsule remains radius
`11.5`, half-spine `12.75`, offset `(0, 7)`. It uses 45-degree support, four-unit
step/snap, one-way support and level ground movement/jump tuning. Its own graph
uses those actual limits. Obstacle-top placement retains exact support selection
and a 32-unit minimum perch span, without an unrelated lower-surface fallback.
The obsolete kinematic enemy role, factory and dispatcher branch are removed.
`groundNavigatingEnemyIds` supplies all three ground-enemy graph profiles.

Descending-slope jump graph admission verifies final support with the production
capsule controller and rechecks cruise speed implied by the published landing
point/tick count. Forest seed 42 and the descending Rocky Grove slope/gap
sequence retain regressions for a corner contact that previously left Derf
airborne despite an admitted graph edge.

`derf.tentacle_strike` has seven poses with active indices `[3, 5)`. Thin damage
capsules follow the extended tentacle separately from the leaning torso hurtbox
and terrain shape. Damage is 8 physical, once per target per activation. Authored
60 Hz timing is 18 windup, 12 active, 12 recovery and 60 cooldown ticks.
`ActionFramePolicy` aligns extension and damage across tick rates/action speeds.
Derf engages using authored weapon reach; engagement publishes that resolved
range to locomotion. Other enemies retain their existing close-range tuning.

## Assets and snapshots

The supplied sheet is `assets/images/entities/enemies/derf/twisted_cultist.png`,
1092-by-462 with 91-by-42 cells. Runtime rows below are zero-based:

| Animation | Row | Frames |
| --- | --- | --- |
| Twisted idle with blink | 1 | 6 |
| Walk/run with blink | 3 | 8 |
| Tentacle strike | 4 | 7 |
| Hit/stun | 5 | 3 |
| Death | 6 | 12 |
| Jump / fall | 7 / 9 | 3 each |
| Transformation | 10 | 12 |

Original `derf/derf.png` remains source art. Run
`dart run tool/generate_derf_caster_sheet.dart` from the repository root to pad
its 45-by-42 cells by 44 pixels on the left into `derf/caster_sheet.png`.
`--dry-run` verifies freshness. Original idle/cast/hit/death rows stay 0/2/5/6;
no pixels are rescaled. Both forms share pivot `(72, 21)` and scale `1.5`.

Core selects appended `casterIdle`, `casterHit`, `casterDeath`, `transform` and
standard twisted animation keys. Existing enum ordering is preserved. Flame
and ghost views use the existing deterministic actor registry, with transformation
and reaction/death variants registered as one-shots. Static authoring previews
consume `EnemyArchetype.previewAnimKey`.

## Compatibility and checks

This deterministic gameplay change requires compatibility `2026.10.7` and a
coordinated client/Functions/worker release. Replay format, command encoding,
score rules and board wire shape are unchanged. Source preparation does not
mean production has been cut over.

Phase tests cover 30/60/120 Hz, camera boundaries, cast cancellation, released
effects, health/identity, longer locks and entity cleanup. Combat/render tests
cover pose timing, reach, mirroring and hit deduplication. Traversal includes
already-transformed Derf with actual catalog limits on Forest's finite assembly
and 32-chunk Field/`new_level` prefixes, seeds 7/42/2026. Lifecycle/combat remain
separate from that movement harness; generated freshness must pass before its
results describe current authored geometry.

A paired full-Core fixture verifies identical snapshots, first-visible
transformation, stationary strip playback, subsequent pursuit and player damage.
