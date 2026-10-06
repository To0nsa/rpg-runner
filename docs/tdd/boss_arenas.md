# Boss arenas

Forest's `forest_boss_easy_001` contains the first mandatory boss encounter,
Bringer of Death. This implementation is prepared for gameplay compatibility
`2026.10.8` and score partition `score-v4`; it is not a production deployment.

## Ownership and authored contract

Chunk-v2 has an optional `bossArena` object with exactly five fields:
`id`, `enemyId`, `spawnX`, `minX`, `maxX`. Coordinates are whole chunk-local
pixels. The supported enemy identity is `bringerOfDeath`, appended to
`EnemyId` without changing earlier ordinals. Arenas must match the fixed
600-by-270 viewport; the boss spawn and complete catalog capsule must fit
inside the combat interval with valid polygon ground support and clearance.
Ambient markers, rescue groups and traps are excluded from this first arena
contract. Bosses cannot be ambient markers or rescue participants.

The shared content pipeline owns strict decoding and delegates placement to
Core's `resolveBossArenaPlacement`. Generation, captured editor Play and live
activation use the same placement rules. Source omission means an ordinary
chunk; explicit null and unknown fields are invalid. Generated patterns and
terrain remain generator-owned. A boss's assembly group must have exactly one
active candidate across the level's pools. Forest reserves one easy
`boss_bringer_of_death` chunk before its easy enchanted-forest section.

`BossArenaSystem` owns occurrence registration, entrance, confinement, terminal
outcomes and retention. `BossArenaSpawnAdapter` admits the required actor after
the matching terrain has been published. `BringerCombatSystem` chooses actions;
ordinary melee/cast committers and execution systems retain damage authority.
Flame and Flutter display snapshots and cannot advance the encounter.

## Tick and camera lifecycle

Approach selects the earliest pending streamed arena. Camera motion stops at
the exact chunk center and clears its forward target and velocity. It also frames
the full vertical viewport, including with follow-player camera tuning. The player
remains controllable while the camera approaches. After the complete arena is
framed and the player's capsule is inside the combat interval, Core holds the
player's motion and actions. The boss is created in the next world-preparation
phase, before terrain motion preparation and AI.

Introduction duration is the catalog spawn strip's quantized duration:
`frameCount * round(stepSeconds * tickHz)`. The reversed ten-frame dissolution
uses 0.12 seconds per frame: 70 ticks at 60 Hz, 40 at 30 Hz, and 110 at 90 Hz.
It is independent of widget timers, image-loading completion and render frame
rate. Player and boss are protected during introduction. Existing simulation
ticks, cooldowns, status durations and regeneration continue.
Entrance holds discard ability-charge progress while preserving held-input
transitions. Arena-owned protection is a lifecycle-registered ECS marker, so
release cannot remove protection from a recycled entity ID.

Short control locks refresh after timer maintenance and before action gates.
`ActorMotionBoundsStore` supplies horizontal containment and introduction motion
freeze to the existing terrain capsule controller. Confinement applies to
walking, jumps, mobility and knockback without a second terrain representation
or position teleport. Combat releases the introduction hold and boss protection
while retaining bounds, camera lock and terrain ownership. The behind-camera
failure check does not apply inside the framed arena; health and fatal world
loss remain authoritative.

Other autonomous actors retain their identities under `ArenaSuspensionStore`.
Their motion, teleport execution, attacks and damage are suspended; they are
excluded from player auto aim and render snapshots until release. Projectiles
and hitboxes from outside the roster cannot enter arena combat. Earlier combat
artifacts are cleared at entrance and pending boss attacks at defeat.

Player loss takes precedence over a simultaneous boss loss. Positive combat
defeat enters `defeated`; the camera and boundaries remain closed until normal
death animation/despawn completes. The next tick releases confinement and
normal running resumes with camera acceleration from zero. Unexpected boss
removal or rejected placement ends the run with `bossEncounterFailed`; removal
cannot open the exit or award a kill. Recycled entity IDs are checked against
the required enemy identity. Streamed instance indices prevent reactivation;
retired arena records are discarded without restoring a completed occurrence.

The first held Flame frame uses the authoritative arena camera rather than
interpolating from the preceding runner frame. Core's framing remains locked
while render-only entrance shake adds a small visual offset. Purple boundary
cues and the boss HUD are presentation only.

## Reusable entrance feedback

`BossArenaSnapshot.entrance` exposes the existing `startTick` and quantized
`durationTicks` after boss creation; it is absent before creation and outside
introduction. This presentation contract is independent of enemy identity and
does not change entrance duration or replay commands.

`BossEntranceFeedbackFrame` samples that clock into three evenly spaced pulses
at zero, one-third and two-thirds of the entrance. Each black border pulse uses
the same 340 ms cubic fade and edge geometry as player impact feedback.
`ScreenBorderVignette` owns the shared painter and semantic styles: crimson for
player impact, black for boss entrance. It leaves the center clear and ignores
pointer input. An older player-impact border remains mounted but hidden during
introduction so it cannot replay when combat begins.

`BossEntranceCameraFeedback` applies moderate shakes using the existing camera
shake controller and clears the sequence at combat release. The run-owned
`BossEntranceHapticsBinding` maps the same pulse keys to medium platform impact
cues. Consumers deduplicate by entrance start tick and pulse index, retain
deduplication across pause/resume, and dispose the haptics subscription before
run restart or exit. There are no widget timers advancing encounter phases,
fabricated player-hit events, or boss-specific IDs/assets in these modules.
The same adapters apply to future bosses exposing their entrance timing.

## Combat and animation

The runtime sheet is `assets/images/entities/enemies/bringer_of_death/sheet.png`.
The original 1120-by-744 sheet has eight columns of 140-by-93 cells. Source
metadata handles wrapped Attack, Hurt, Death and Cast sequences and explicit
reverse-order spawn rectangles. The body anchor is `(104, 68)`; the immutable
terrain capsule and vulnerable body remain separate from the scythe's attack
capsules. Committed attack art cannot be replaced by ordinary hit reactions.

Scythe Sweep commits facing and uses reviewed blade capsules. Death Pillar
captures the selected target's collider center on commit and never follows later
movement. Its first six effect frames are harmless telegraph; later pillar frames
use a world-anchored capsule and one hit per target. Both actions share cooldown
group zero. Stun immunity prevents indefinite interruption; other damage and
status rules remain ordinary Core behavior.

## Scoring and replay

`RunEndStats.excludedScoreTicks` counts ticks while the camera is stopped for
the arena, including entrance, combat, corpse presentation and terminal player
animation. This also excludes waiting just outside the combat interval after
camera framing. Duration continues to use the complete run tick count. Survival
points use `(tick - excludedScoreTicks) ~/ tickHz`. The Bringer kill awards a
fixed 1000 points through the existing per-enemy kill row, exactly once. A
simultaneous player death does not award that boss kill.

Client game-over and local-result scoring and worker validation pass the same
excluded tick count to `buildRunScoreBreakdown`. Validated-run generic stats
include `excludedScoreTicks` and the extended ordinal-preserving kill array.
Replay command encoding remains v1; no client-provided boss result is trusted.
Functions, client and worker compatibility defaults move together to
`2026.10.8`; board/worker score defaults use `score-v4` so earlier scores retain
their existing partitions. A coordinated release and drain policy are required
before this branch is deployed.

## Editor and verification

The Chunk owner metadata form enables an arena and edits its stable encounter ID,
spawn and combat interval. It uses the existing optimistic metadata command,
Undo/Redo and canonical Save path. Composition edits retain boss metadata;
removal is explicit. Bosses are excluded from ambient enemy catalogs. Build and
Play still require shared terrain readiness and unique candidate selection.

Targeted tests cover entrance timing, both characters at three tick rates,
confinement, real combat clears, release, entity recycling, invalid removal,
scoring, exact source rectangles, authoring round trips and validator replay.
The level pursuit matrix covers existing mobile enemies through Forest's full
finite assembly and 32 chunks of Field/new_level. Bringer is deliberately
excluded from route-wide pursuit because its actual movement domain is the
arena; boss integration tests cover that confinement separately.
