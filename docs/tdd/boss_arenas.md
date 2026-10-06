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

## Victory blessing

When the required boss is positively defeated, the arena records the normal
death state's despawn deadline. Once the actor is gone and that deadline has
passed, it requests a reward keyed by the streamed chunk occurrence. Early or
unverified cleanup cannot grant the reward. Arena release keeps its existing
timing; it does not wait for the blessing effect.

`BossVictoryBlessingSystem` owns reward eligibility and deduplication,
independently of enemy identity. Its default definition names the Dames de la
forêt and restores 6,000 basis points (60%) of each current maximum: health,
mana and stamina. The shared `ResourceRestoration.restorePercent` helper also
serves restoration pickups. It rounds down in the pool's integer units and caps
at the current maximum, preserving equipment, regeneration rates and fractional
regeneration accumulators. This instant restore is separate from the persistent
shrine blessing in [world interactions](world_interactions.md).

The request is resolved after damage, enemy death/despawn and health cleanup in
phase 14, before world interactions and passive regeneration. A missing, dead or
dying player consumes the occurrence without a grant: the blessing cannot rescue
a fatal tick. A successful grant emits one `SpellImpactEvent` and exposes
`GameStateSnapshot.bossVictoryBlessing` for the duration of the effect.
The HUD names “Bénédiction des Dames de la forêt” and the three restored pools.
There is no extra control lock or score-time exclusion.

`SpellImpactId.holyBlessing` uses the unchanged supplied Holy VFX 02 sheet at
`assets/images/entities/effects/blessings/holy_02.png`: sixteen 48-by-48 cells,
0.05 seconds per frame, bottom-center pivot and 2x render scale.
Its quantized duration is 32/48/80 ticks at 30/60/90 Hz. Both the notice and the
one-shot sample Core ticks, so pause freezes their clocks.
The event attaches to the player's collider foot using `followEntityId` and
`followOffset`; its original world position remains the fallback.
Live and ghost rendering share the attachment interpolation helper and preserve
the original event start tick while the player moves. The registry owns loading
and captured editor Play automatically includes its runtime image.

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

Scythe Sweep commits facing and uses reviewed blade capsules. Both attacks
use the same attack executors as ordinary enemies. The catalog terrain profile's
`canJump` capability is false for Bringer: its surface graph publishes walk/drop
edges without jump edges, and shared locomotion rejects upward launch requests
and swim strokes. Other grounded enemies retain jumping. Gravity and collision
support remain authoritative; the boss is not pinned to a fixed Y coordinate.

Death Pillar captures the selected target's collider center on commit and never follows later
movement. Its first six effect frames are harmless telegraph; later pillar frames
use a world-anchored capsule and one hit per target. Both actions share cooldown
group zero. Stun immunity prevents indefinite interruption; other damage and
status rules remain ordinary Core behavior.

Both attacks configure the shared [post-damage knockback](combat_knockback.md).
Damage acceptance owns the effect; neither the boss AI nor arena lifecycle pushes
the player directly. The existing terrain controller resolves supported travel,
platform departure, walls and full-capsule confinement.

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
Victory tests cover once-per-occurrence restoration, full and uneven resource
pools, fatal-player exclusion, death-strip completion, movement during the effect,
Core-clock pause/expiry, and direct/worker replay equivalence.
The level pursuit matrix covers existing mobile enemies through Forest's full
finite assembly and 32 chunks of Field/new_level. Bringer is deliberately
excluded from route-wide pursuit because its actual movement domain is the
arena; boss integration tests cover that confinement separately.
