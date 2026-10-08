# Ancient God boss implementation

This source addition implements `voidbornGoddess`, `shoggoth`, `voidcaller`,
`shoggothMinion` and `voidTentacle` in Core, rendering and the editor. Existing
enemy/projectile/impact enum ordinals are preserved by appending identities.
Bosses are selected through the existing five-field chunk-v2 `bossArena`
contract. Forest's assembly places three dedicated one-chunk easy sections
after Bringer: `forest_voidborn_goddess_easy_001`, `forest_shoggoth_easy_001`,
then `forest_voidcaller_easy_001`, before the existing enchanted forest.
Each uses an independent arena ID and a single-candidate assembly group;
the shared lifecycle releases one encounter before activating the next. The shared
wire payloads and replay command encoding remain unchanged. Client and replay
worker consume the same Core in the deployed `2026.10.9` release.

## Catalogs and authority

`EnemyId.isBoss` and `isBossSummon` define arena roles. Bosses and summons are
rejected as ambient markers or rescue-roster participants. Only the four boss
identities can be required arena objectives. Strict content decoding, editor
Save/Build/Play and live spawn placement reuse the existing
[arena contract](boss_arenas.md).

`VoidbornGoddessCombatSystem`, `ShoggothCombatSystem` and
`VoidcallerCombatSystem` independently select actions by sequence, target range
and living summon count. They have no chunk-name dependency and consume no RNG.
Each boss owns separate ability definitions, render metadata and combat poses
under its own filename. Minion and tentacle definitions are also separate.
Projectile art lives with its owning actor's render catalog; Voidcaller's
generated beam composition has its own effect catalog and generator.

Global ability, enemy, projectile and pose catalogs remain lookup registries.
`BossCombatSystem` shares only engagement and committed-action dispatch;
`BossUtilitySystem` shares captured utility execution, terrain placement and
summon lifetime. Neither contains a concrete boss selection switch. Each boss
owns its spacing, pursuit speed, sequence and teleport cadence. Shoggoth owns
spin motion composition; `VoidTentacleCombatSystem` owns planted behavior.
Goddess owns her corner placement, hover and six-hand barrage in her own combat
system and lifecycle-registered `GoddessBarrageStore`.
Ordinary AI melee/cast selectors skip required bosses; the existing
committed-action executors own all damage.
The [gameplay document](../gdd/ancient_god_bosses.md) records the default kits.

Both summons use ordinary enemy targeting, health, damage, statuses and death
handling. Tentacles override pursuit speed to zero and discard navigation
plans; minions pursue normally. Boss stun immunity preserves committed threats.
Hit reactions do not replace active boss attack art.

## Lifecycle and tick dependencies

`BossCombatStateStore` and `BossSummonStore` are lifecycle-registered sparse
stores. The former holds action sequence, next teleport tick and utility action
identity/start/execute tick/target X. The latter holds owner and expiry tick.
Utility execution checks the exact active ability ID and start tick, living
owner, suspension and stun state, so interrupted or replaced actions cannot
execute a stale utility intent.

| Placement in `GameCore.stepOneTick` | Reason |
| --- | --- |
| Required arena spawn, then `BossUtilitySystem.prepare`, before terrain motion preparation | Admit summons and expire them before the authority enumerates tick bodies |
| Shared utility teleport execution after target selection and Hashash teleports, before water/navigation refresh | Publish validated relocated support and position before dependent consumers |
| Goddess barrage preparation immediately after utility teleports | Validate exact cast identity, commit corner/return placement, and schedule due hands before water/navigation |
| Boss decisions after shared engagement selection, before locomotion | Commit one action and set boss stand-off; keep tentacles planted |
| Spin motion composition after ordinary locomotion, before movement/knockback/gravity/terrain | Apply one committed horizontal charge, then retain the single terrain integration owner |
| Goddess hover composition alongside spin composition | Suppress gravity for one tick and stop locomotion while retaining normal knockback and one terrain integration |
| Arena isolation before damage; defeat after damage, before death cleanup | Owned summons participate; outside attacks stay excluded; player loss takes precedence |

AI timings are ceil-scaled from 60 Hz authoring ticks. Target-point effects
sample floor or top-side one-way support below the captured target. Delivery
and effect rendering use the same rounded frame-step ticks. Damage geometry
is resolved before broadphase; Flame never decides hit timing.

For prepared compatibility `2026.10.10`, Goddess captures the cast start tick,
original position/facing, first release tick and sweep direction. Six hands use
the already committed target-point payload, at half-second intervals and six
evenly spaced floor marks inset 50 units from the arena edges. Her far upper
corner is inset 64 units and 150 units above the level floor. Both corner and
return use terrain-owned checked teleports. Both corners blocked means no hover;
a blocked return resumes ordinary falling. She returns after the final hand's
17 effect frames. Death, interruption, suspension or same-ID recommit cancels
future releases and gravity suppression. State is removed before ID recycling.
Each spawned hand has its own ordinary one-hit ledger and shared render/damage
clock; committed effects retain normal impact lifetime behavior.

`BossSummonDelivery` defines type, living cap and lifetime. Summon candidates
are captured target X plus `[72, -72, 120, -120]`, in stable order. Admission
uses existing encounter spawn requests, published terrain support and clearance,
full-capsule horizontal bounds, player spacing and 40-unit summon spacing.
One successful candidate creates one normal spawn-intro actor with the owner's
motion bounds. Rejection consumes the cast without creating an actor.

`BossTeleportDelivery` uses captured X ±150 and checks terrain clearance,
full-capsule bounds and at least 70 units from the current target. Motion uses
`beginBodyTeleport` / `tryCommitBodyTeleport` / `cancelBodyTeleport`; a failed
candidate restores the retained origin. If neither candidate works, the normal
return animation plays at the original valid position.

Arena retention, confinement and combat protection recognize owned summons.
Owner death expires them during next tick preparation. `EcsWorld.destroyEntity`
cascades owner-to-summon and summon-to-projectile/hitbox destruction before
recycling IDs. Arena release and run termination also remove owned summons.
This prevents recycled IDs from inheriting surviving attacks or ownership.
Summon kill counts remain observable but their score multiplier is zero;
required boss kills reuse the 1000-point boss reward.

## Rendering and generated effects

The unchanged runtime PNGs and license copies live under
`assets/images/entities/enemies/ancient_god_pack/`. Full editable source exports
remain in ignored `resources/enemies_and_creatures/ancient_god_pack/`.
The [asset map](../../assets/images/entities/enemies/ancient_god_pack/ASSET_MAP.md)
records verified exported frame regions and discrepancies with Aseprite tags.
Actor, projectile and impact art all use 1.5x scale; source rectangles and pivots
remain source-pixel coordinates. Collider and attack dimensions are world units.
The source-backed Entities parser resolves static const visuals through explicit
relative imports and preserves anchor rewrite bindings in each actor's render
catalog. Collider and scale writes remain in `enemy_catalog.dart`; the existing
guarded export transaction updates both files together.

Goddess Cast 2 joins its six preparation and thirty cast frames using explicit
source rectangles. Projectile startup/loop/impact strips stay separate.
Voidcaller's beam exports are layered components rather than twenty sequential
full effects. `RenderFramePart` and `RenderAnimSetDefinition.compositeFramesByKey`
describe portal, middle and ground parts within one logical 138×146 canvas.
The vertical effect is anchored at `(92,146)` and the diagonal at `(46,146)`;
its portal is 60 source pixels right of the ground mark, matching the endcaps'
down-left slope. At 1.5x scale its damage segment runs from `(90,-180)` to
`(6,-12)` relative to the ground mark. World-anchored impact art and damage keep
this fixed orientation regardless of the caster's facing.
`CompositeFrameSprite` draws those parts from the same
run-owned PNG; it allocates no derived image or independent animation timer.
The middle tiles native vertical/diagonal strips at integer source-pixel offsets.
Fixed source-cell pivots align the axis despite changing endcap/debris bounds;
all pieces use the same bright/pink phase. Nearest-neighbor rendering without
edge antialiasing prevents seams at 1.5x scale. No piece is rotated or narrowed.

`tools/combat/generate_voidcaller_effects.py` derives component crop rectangles
from source alpha bounds and generates `voidcaller_effect_catalog.dart`.
`generate_projectile_profiles.py` includes the new projectile poses. Run both
with `--check` to detect stale outputs; never hand-edit generated catalogs.

## Verification

Arena tests cover deterministic duplicate runs at 30/60/90 Hz, introduction,
confinement, teleport/return, summon caps and lifetime, stationary tentacles,
both characters' real-combat victories, release and recycled-owner cleanup.
Effect tests verify captured surfaces, harmless warning frames, evasion and
one hit per distinct swing/pulse at all three rates. Barrage tests cover six
ordered floor marks, hover and return in flat and authored Forest rooms, plus
cancelled/replaced/dead casts and recycled IDs. Render tests load every catalog frame,
check source bounds/scale and render composed beams and melee pose previews.
Pixel checks require an unbroken opaque beam axis in all five active frames at
native and 1.5x scale, including every strip and endcap join.

The behavior-preserving separation commit `0ab07746` compares 28-second
per-tick traces for all three bosses at
30/60/90 Hz against the pre-refactor implementation: all nine hashes match.
The trace includes health, arena phase, entity identity, position and animation
frame. Additional isolation tests put two instances of each boss in one world:
one system cannot commit another boss's action, and one instance's cooldown
cannot block its sibling. Cancelled/replaced utilities are rejected before any
terrain query or spawn, including recommits of the same ability ID.

The [source video](https://www.youtube.com/watch?v=0rPsM1DjEuc) was reviewed across
its full 75-second duration on October 7. Goddess occupies approximately 0–20 s,
Shoggoth 21–49 s and Voidcaller 50–75 s. These are animation demonstrations;
combat timing, damage and sequencing remain the documented gameplay defaults.
The subsequent visual audit corrects the diagonal beam's reversed middle/slope
and Shoggoth spin frames 4–7: front crescents follow their visible arc and the
rear crescents now have damage geometry. Focused damage tests exercise both
spin facings and the visible versus empty diagonal at 30/60/90 Hz. These are
intentional gameplay corrections within the deployed `2026.10.9` cutover, separate
from the equivalence evidence for the file separation.

The full Core suite and 36 production-route pursuit cases exercise shared
terrain integration. Existing bosses remain covered by their arena tests;
arena actors are not claimed as route-wide pursuers. The route matrix retains
Field and `new_level` 32-chunk horizons and one full finite Forest assembly,
seeds 7/42/2026, Grojib/Hashash/Derf/Unoco. It does not replace spawn, combat,
render performance or full-run checks.

The consecutive Forest arena test uses both real character loadouts and normal
committed combat to defeat all four bosses without resetting resources or
teleporting between rooms. It checks four introductions, blessings, summon
cleanup and the exit into the ordinary section. Production-selector checks
retain seeds 7/42/2026 and verify the exact four-room order once per assembly.
Their Forest horizons are 114/105/116 chunks. New seed-7 transitions also retain
focused navigation regressions for the normal camp crate approach and the hard
grove gap; their authored foothold/clearance repairs leave actor capabilities
unchanged.

Navigation/run goldens now include nine grounded graph profiles. Review against
an isolated HEAD copy confirmed identical terrain surfaces and original four
graph views. Canonical scenario records differ only in the global graph digest
and SG-E05 graph-record count (118→143); movement checkpoints and outcomes are
unchanged. The checked-in prior goldens were already stale against HEAD, so
the updated digests reflect the current expanded catalog after that comparison.
