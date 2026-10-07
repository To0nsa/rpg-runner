# Ancient God boss implementation

This source addition implements `voidbornGoddess`, `shoggoth`, `voidcaller`,
`shoggothMinion` and `voidTentacle` in Core, rendering and the editor. Existing
enemy/projectile/impact enum ordinals are preserved by appending identities.
Bosses are selected through the existing five-field chunk-v2 `bossArena`
contract; production authored chunks and assemblies are unchanged. The shared
wire payloads and replay command encoding remain unchanged. Client and replay
worker must consume the same Core in the pending `2026.10.9` release.

## Catalogs and authority

`EnemyId.isBoss` and `isBossSummon` define arena roles. Bosses and summons are
rejected as ambient markers or rescue-roster participants. Only the four boss
identities can be required arena objectives. Strict content decoding, editor
Save/Build/Play and live spawn placement reuse the existing
[arena contract](boss_arenas.md).

`AncientGodCombatSystem` selects actions by enemy identity, action sequence,
target range and living summon count. It has no chunk-name dependency and
consumes no RNG. Ordinary AI melee/cast selectors skip required bosses; the
existing committed-action executors own all damage. Ability definitions,
combat poses and effect/projectile definitions stay in Core catalogs.
The [gameplay document](../gdd/ancient_god_bosses.md) records the default kits.

Both summons use ordinary enemy targeting, health, damage, statuses and death
handling. Tentacles override pursuit speed to zero and discard navigation
plans; minions pursue normally. Boss stun immunity preserves committed threats.
Hit reactions do not replace active boss attack art.

## Lifecycle and tick dependencies

`AncientBossStateStore` and `BossSummonStore` are lifecycle-registered sparse
stores. The former holds action sequence, next teleport tick and utility action
identity/start/execute tick/target X. The latter holds owner and expiry tick.
Utility execution checks the exact active ability ID and start tick, living
owner, suspension and stun state, so interrupted or replaced actions cannot
execute a stale utility intent.

| Placement in `GameCore.stepOneTick` | Reason |
| --- | --- |
| Required arena spawn, then Ancient God `prepare`, before terrain motion preparation | Admit summons and expire them before the authority enumerates tick bodies |
| Ancient God teleport execution after target selection and Hashash teleports, before water/navigation refresh | Publish validated relocated support and position before dependent consumers |
| Boss decisions after shared engagement selection, before locomotion | Commit one action and set boss stand-off; keep tentacles planted |
| Spin motion composition after ordinary locomotion, before movement/knockback/gravity/terrain | Apply one committed horizontal charge, then retain the single terrain integration owner |
| Arena isolation before damage; defeat after damage, before death cleanup | Owned summons participate; outside attacks stay excluded; player loss takes precedence |

AI timings are ceil-scaled from 60 Hz authoring ticks. Target-point effects
sample floor or top-side one-way support below the captured target. Delivery
and effect rendering use the same rounded frame-step ticks. Damage geometry
is resolved before broadphase; Flame never decides hit timing.

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
relative imports and preserves anchor rewrite bindings in the shared render
catalog. Collider and scale writes remain in `enemy_catalog.dart`; the existing
guarded export transaction updates both files together.

Goddess Cast 2 joins its six preparation and thirty cast frames using explicit
source rectangles. Projectile startup/loop/impact strips stay separate.
Voidcaller's beam exports are layered components rather than twenty sequential
full effects. `RenderFramePart` and `RenderAnimSetDefinition.compositeFramesByKey`
describe portal, middle and ground parts within one logical 138×146 canvas,
anchored at `(92,146)`. `CompositeFrameSprite` draws those parts from the same
run-owned PNG; it allocates no derived image or independent animation timer.
The diagonal middle reuses the vertical middle rotated toward its ground mark.

`tools/combat/generate_ancient_god_effects.py` derives component crop rectangles
from source alpha bounds and generates `ancient_god_effect_catalog.dart`.
`generate_projectile_profiles.py` includes the new projectile poses. Run both
with `--check` to detect stale outputs; never hand-edit generated catalogs.

## Verification

Arena tests cover deterministic duplicate runs at 30/60/90 Hz, introduction,
confinement, teleport/return, summon caps and lifetime, stationary tentacles,
both characters' real-combat victories, release and recycled-owner cleanup.
Effect tests verify captured surfaces, harmless warning frames, evasion and
single-hit damage at all three rates. Render tests load every catalog frame,
check source bounds/scale and render composed beams and melee pose previews.

The full Core suite and 36 production-route pursuit cases exercise shared
terrain integration. Existing bosses remain covered by their arena tests;
arena actors are not claimed as route-wide pursuers. The route matrix retains
Field and `new_level` 32-chunk horizons and one full finite Forest assembly,
seeds 7/42/2026, Grojib/Hashash/Derf/Unoco. It does not replace spawn, combat,
render performance or full-run checks.

Navigation/run goldens now include nine grounded graph profiles. Review against
an isolated HEAD copy confirmed identical terrain surfaces and original four
graph views. Canonical scenario records differ only in the global graph digest
and SG-E05 graph-record count (118→143); movement checkpoints and outcomes are
unchanged. The checked-in prior goldens were already stale against HEAD, so
the updated digests reflect the current expanded catalog after that comparison.
