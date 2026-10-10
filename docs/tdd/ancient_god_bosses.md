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
worker consume the same Core in the deployed `2026.10.10` release. Prepared
source compatibility `2026.10.11` uses shared explicit `CombatCombo` definitions
for claws, sweeps, spin passes and beams. Their later strikes bypass only their
own activation's post-hit protection; see [combo damage](combat_pose_geometry.md#combo-damage-and-post-hit-protection).

## Catalogs and authority

`EnemyId.isBoss` and `isBossSummon` define arena roles. Bosses and summons are
rejected as ambient markers or rescue-roster participants. Only the four boss
identities can be required arena objectives. Strict content decoding, editor
Save/Build/Play and live spawn placement reuse the existing
[arena contract](boss_arenas.md).

`VoidbornGoddessCombatSystem`, `ShoggothCombatSystem` and
`VoidcallerCombatSystem` independently select actions without chunk-name dependencies.
Voidcaller uses a fixed sequence, range and living summon count. Shoggoth uses
distance, persistent health milestones and owned charge continuations. Goddess uses
separate seeded actor streams for tactical decisions and reactive dodges.
Each boss owns separate ability definitions, render metadata and combat poses
under its own filename. Minion and tentacle definitions are also separate.
Projectile art lives with its owning actor's render catalog; Voidcaller's
generated beam composition has its own effect catalog and generator.

Global ability, enemy, projectile and pose catalogs remain lookup registries.
`BossCombatSystem` defines the common tick interface;
`RotatingBossCombatSystem` supplies pursuit and committed-action dispatch for
Voidcaller;
`BossUtilitySystem` shares captured utility execution, terrain placement and
summon lifetime. Neither contains a concrete boss selection switch. Each boss
owns its spacing, pursuit speed and action cadence. Shoggoth owns
charge and sweep motion composition; `VoidTentacleCombatSystem` owns planted behavior.
Goddess owns her corner placement, hover, six-hand barrage and reactive dodge in
her own combat system and lifecycle-registered `GoddessBarrageStore`,
`GoddessHealthPhaseStore`, `GoddessDodgeStore` and `GoddessTacticsStore`.
`GoddessTacticsSystem` owns distance decisions and cancellable exit/reposition
transitions; the combat system retains threshold observation, hands and counters. Her damage middleware requests
dodges through that system.
Ordinary AI melee/cast selectors skip required bosses; the existing
committed-action executors own all damage.
The [gameplay document](../gdd/ancient_god_bosses.md) records the default kits.

In prepared compatibility `2026.10.11`, Goddess no longer uses action-index
modulo rotation or continuous pursuit. At melee height (vertical distance <=50),
within 45 horizontal units, an available voluntary teleport competes with claws
at 30/70 odds. At 45-70 units she may make one directly walkable approach, limited
to 25 units and ceil(0.5 * tickHz) ticks; its endpoint never follows the target.
Approach velocity is capped to remaining displacement before terrain integration.
Outside that band she holds ground and casts. One or two successful normal orbs
consume a seeded budget before relocation is considered; beyond 240 units she
prefers relocation. Unavailable/blocked teleports fall back to ordinary attacks.

Normal and reactive `goddess.claw_combo` actions track the current combat target
through windup and active time. `GoddessTacticsSystem` samples the same
`ActionFramePolicy` as animation and damage, using the committed timing and
current tick. Empty poses and new strike-window boundaries may update the action
facing and pending melee direction; damaging poses within one strike keep their
facing. A two-unit horizontal dead zone avoids overlap jitter. The combo uses
ordinary grounded locomotion at 0.5 speed toward a 35-unit stand-off, only when
navigation confirms direct walking. It holds when the target crosses behind a
live swipe, when support/path is unavailable, and during final recovery.

After locomotion, Goddess restores the strike-owned facing before terrain, art
and damage resolve, so shared target-facing logic cannot flip a live swipe.
Velocity is capped at the current stand-off goal, retaining the ground tangent;
normal knockback and terrain integration still follow. No combo clock, cooldown,
activation ID or per-strike hit ledger restarts when she turns. No new random
draws or teleport transitions are introduced by pursuit.

Tactical RNG uses `seedFrom(runSeed, entityId ^ 0x476f6454)`, independently of
reactive dodge cadence. Initial admission and completed teleports sample a 4-6
second minimum voluntary interval; a successful dodge resets it. Ordinary action
and cooldown gates also apply, preserving claw recovery. A pending health phase
always overrides regular decisions. Her orb retains 27 authoring ticks of
windup and 480 world units/second flight; Shoggoth's orb remains at 340.
The orb's flight pivot is `(69, 59)` in its 138x93 frame, keeping its opaque
silhouette and generated capsule on the captured aim line in either direction
and on diagonal shots. Impact frames use their own `(69, 57)` pivot. The render
registry places this burst at `ProjectileHitEvent.targetCenter`, the struck
combat-body center captured on the collision tick, in both live and ghost views.
The burst remains at that position and adds no area damage or target tracking.
Client and replay worker must ship matching Core selection and tuning.

Goddess refreshes ordinary and post-barrage `goddess.orb` casts after terrain
movement and self abilities, immediately before projectile launch. The current
combat target collider center determines actor/action facing (with a two-unit
horizontal dead zone) and the pending projectile direction. Her existing
30-unit radial launch offset is retained. Cast start, release time and cooldown
remain unchanged. Released orbs retain their launch direction even while her
casting animation continues to face the target. Pending releases require the
matching action start tick, a living available caster and a living selected
target; interruption, replacement, suspension or action lock cancels the pending
shot. This is part of prepared compatibility `2026.10.11` and uses the same Core
phase in client and replay worker.

Before tactical decisions, Goddess observes current/max health using integer
comparisons `hp * 4 <= hpMax * quarter` for quarters 3, 2 and 1. Her persistent
health-phase store retains the maximum number reached and the number of accepted
barrages. This records crossings during actions, scripted exits and cooldowns, including
multiple thresholds crossed by one nonlethal hit. Healing never revokes earned
phases or grants duplicates. Threshold selection waits for ordinary action and
cooldown gates; it does not interrupt a dodge, claw combo or scripted barrage exit.
Only an accepted barrage commit consumes one reached phase, so failed cast admission
retries, while an interrupted accepted barrage cannot repeat the same threshold.
The per-cast barrage store may be removed normally without losing this budget;
actor destruction clears both stores before ID reuse. Dead actors start no phase.

Both summons use ordinary enemy targeting, health, damage, statuses and death
handling. Tentacles override pursuit speed to zero and discard navigation
plans; minions pursue normally. Bosses use catalog Stun/Silence immunity and
the shared half-magnitude harmful-status resistance profile, retaining effect
duration. Summons retain neutral status resistance. These defenses are applied
by the generic status pipeline, described in
[target scaling](status_effect_tuning.md#target-scaling).
Hit reactions do not replace active boss attack art.

## Shoggoth tactics

Prepared compatibility `2026.10.11` replaces Shoggoth's modulo rotation with
`ShoggothCombatSystem` and lifecycle-registered `ShoggothTacticsStore`.
The catalog has 26000 fixed-point health (260 HP). Native 1.0x actor scale uses
a 32-by-52 collider with a six-unit downward center offset, and matching sweep
and spin capsules. Ground contact places the transform 32 units above the floor
(plus terrain collision skin), lowering the spin core from about 53 to 35 units
above ground. Damage geometry and renderer scale change together; the terrain
profile still derives from the same collider. Decisions use current combat
target identity and published navigation: at vertical separation <=50, directly
walkable targets within 70 units select a sweep; targets through 260 units
select a charge. Other targets select an orb. Ordinary cooldown and active
ability gates remain authoritative. Pursuit retains 0.8 shared ground speed and
45-unit spacing, retaining the existing jump and slope policies.

Integer comparisons `hp * 100 <= hpMax * threshold` for 80, 60 and 40
record reached summon phases during actions and cooldowns. The maximum reached
count survives healing. Successful summon commitments consume each phase once; failed
admission retries and interrupted accepted casts do not repeat. The first
summon has count/cap two, the second three and the third four. Burst damage
queues every crossed threshold in order. All three use the same nine-frame
summon timing, releasing at frame 7 after 42 authoring ticks.
Placement still runs before terrain body enumeration, including every admitted
minion in that tick's motion roster. Expiry, owner destruction and attack cleanup
use the shared summon lifecycle.

After earned summon waves, living owned summons prioritize an orb whenever the
target is outside the same directly walkable, <=70 horizontal / <=50 vertical
melee reach used by sweep selection. This precedes teleport and charge selection,
including a pending return continuation. `BossUtilitySystem.livingSummons`
excludes dead actors and other owners; expiry is resolved before AI. Existing
actions and cooldowns complete normally, and the absence of living minions
restores ordinary attack decisions. No new RNG or persistent target state is used.

Sweep preparation captures an endpoint at most 24 units ahead and no closer than
45 units to the captured target. During windup only, grounded direct walking
approaches it at 0.5 speed; remaining displacement and live target spacing cap
velocity. The endpoint never follows a retreating target. Windup/harmless frames
and new combo strike windows may retarget facing; a live strike cannot turn.
Post-locomotion composition restores action facing before art and damage resolve.
Active sweeps and recovery hold position; normal knockback still follows.

Both charge abilities track facing during windup, then compose 360 horizontal
units/second for their 36-authoring-tick active phase before the single terrain
integration. The existing two-pass geometry and ledgers remain unchanged.
A separate persistent `frenzyReached` flag records the 35% charge milestone;
healing cannot undo it and summon thresholds do not advance it. Once reached,
the first and every alternate accepted normal charge can queue a return. Its
exact ability/start/end identity is inspected after control lock refresh and **before** the active-phase system clears completed actions.
Only natural completion admits the continuation in that tick's decision phase.
Cancellation, replacement, suspension, missing target, death or stun discards it.
The target must be behind the first direction by >20 and <=260 units, at melee
height with direct walking available. Otherwise the original cooldown remains.

An admitted `shoggoth.return_charge` bypasses only the completing charge's
remaining cooldown and starts a new 150-authoring-tick cooldown. Failed admission
restores the prior remaining cooldown. The return is an ordinary independent
melee activation: 30 windup ticks, 36 active ticks and 48 recovery ticks. Its two
strikes share their own combo provenance, never the preceding charge's exception.
There is no continuation from a return charge.

Separation tracks consecutive ticks beyond 300 horizontal units or without a
directly walkable approach. After three seconds, a ready actor tries a captured
utility teleport, at most once per eight seconds after acceptance. Failed
placement preflight falls back to an orb with a one-second teleport retry delay.
No teleport or health event interrupts an action or skips its recovery.

Orb casting refreshes facing and the pending shot after terrain movement and
self abilities, immediately before shared projectile launch. The current combat
body center determines facing (with the same two-unit horizontal dead zone) and
aim. Cast frame 8's hand-tip center is source pixel (44, 79) relative to the
(79, 65) pivot: world offset (-35, 14) at native scale, mirrored in X when facing
right. Projectile intents carry a signed body-relative `sourceOffsetX` alongside
`sourceOffsetY`, with zero defaults for existing callers. These offsets precede
the ordinary aim-line offset; Shoggoth uses zero aim-line displacement so steep
aim never moves the projectile off his hands.

The refresh checks the exact orb ability/start identity, living actor/target,
suspension and control gates. Invalid pending intents are cleared before the
executor runs. Facing can follow through cast recovery, while aim changes end
at release. Turning spends no resources, advances no action index and changes no
cast/cooldown clock. The projectile executor contains no Shoggoth branch, and
released projectiles retain their normal independent flight and collision.

## Combo finishers and spell effects

Goddess's claws and Shoggoth's sweep, spinning charge and return charge author
`KnockbackTrigger.comboFinisher`. The shared hitbox resolver supplies whether
contact belongs to the final authored strike; only that strike resolves the
captured knockback source. No boss identity check or hit-count shortcut is used.
The fourth claw and second sweep/spin each push 112 world units over 0.28 seconds,
subject to normal damage acceptance, body caps and terrain. See
[combat knockback](combat_knockback.md) for motion and cancellation rules.

Both orb payloads and `goddess.eruption` use the same shove with the default
per-hit trigger. Each carries an `onHit` Weaken proc with source-local magnitude
2500 basis points and duration three seconds, matching Death Pillar. The existing
status store and snapshot mask drive live/ghost feedback. Released Goddess
spells retain these frozen payloads after owner death under her existing policy.
These deterministic changes belong to prepared compatibility `2026.10.11`;
client and worker share the same Core. No command or replay encoding changes.

## Lifecycle and tick dependencies

`BossCombatStateStore` and `BossSummonStore` are lifecycle-registered sparse
stores. The former holds action sequence, captured teleport destination and utility action
identity/start/execute tick/target X. The latter holds owner and expiry tick.
Utility execution checks the exact active ability ID and start tick, living
owner, suspension and stun state, so interrupted or replaced actions cannot
execute a stale utility intent.

| Placement in `GameCore.stepOneTick` | Reason |
| --- | --- |
| Required arena spawn, then `BossUtilitySystem.prepare`, before terrain motion preparation | Admit summons and expire them before the authority enumerates tick bodies |
| Shoggoth continuation preparation after control locks, before active ability phase update | Verify completion identity before the shared phase clears it; no placement or damage runs here |
| Shared utility teleport execution after target selection and Hashash teleports, before water/navigation refresh | Publish validated relocated support and position before dependent consumers |
| Goddess dodge, barrage and tactical preparation, immediately after utility teleports | Validate action identity, commit the dodge and counter or corner placement, schedule due hands and advance the orb/teleport exit before water/navigation |
| Boss decisions after shared engagement selection, before locomotion | Commit one action and set boss stand-off; keep tentacles planted |
| Spin motion composition after ordinary locomotion, before movement/knockback/gravity/terrain | Apply one committed horizontal charge, then retain the single terrain integration owner |
| Goddess hover/pursuit composition alongside spin composition | Suppress hover gravity, retain combo-facing ownership and cap pursuit velocity before knockback and one terrain integration |
| Shoggoth and Goddess orb refresh after motion/self abilities, immediately before projectile launch | Turn and aim from final target positions, including a release-tick crossing; Shoggoth also mirrors his authored hand origin |
| Arena isolation before damage; defeat after damage, before death cleanup | Owned summons participate; outside attacks stay excluded; player loss takes precedence |

AI timings are ceil-scaled from 60 Hz authoring ticks. Target-point effects
sample floor or top-side one-way support below the captured target. Delivery
and effect rendering use the same rounded frame-step ticks. Damage geometry
is resolved before broadphase; Flame never decides hit timing.

`GoddessDodgeMiddleware` counts eligible direct player damage requests before
damage resolution. Melee, projectile and spell-impact requests count; player
combos use `(source, activation)` to count once and retain the evasion decision
for later strikes. Non-combo player deliveries already hit each target once.
Ordinary invulnerability, action protection, suspension, stun, a pending dodge
and any barrage or scripted tactical transition exclude new attacks from the cadence. The registered
store clears cadence, consecutive projectile hits, RNG, pending identity/side
and the combo ledger when destroyed.

`DamageSystem` reports the request's source entity through `onDamageApplied`
only after positive HP loss and forced interrupts. GameCore routes that callback
to Goddess's combat module, which counts consecutive player-projectile hits.
The second landed hit requests the same checked vanish/counter without canceling
either hit. Landed melee/spell-impact hits reset this streak; DoT and NPC damage
do not change it. Lethal hits cannot counter. Barrages, scripted transitions,
suspension, stun and an already pending vanish exclude new streak updates.
Blocked placement retains two hits for the next landed projectile to retry.
Either successful reactive trigger clears both counters and samples a new
4–6 attack interval; no additional RNG stream or teleport executor is introduced.

The first eligible attack samples an interval of 4, 5 or 6 using `nextUint32`
modulo three plus four. A successful dodge samples the next interval. Each actor
has an independent stream initialized with `seedFrom(runSeed, entityId ^
0x476f6444)`; cadence and distant-side choices share that stream. Ineligible hits,
combo follow-ups and blocked attempts do not consume draws.

At the sampled attack, the owning combat system preflights supported landings
35 units from the current player and within full-capsule arena bounds. Within
45 horizontal units it requires the opposite side. Beyond 45 units it validates
both sides, draws an even/odd random choice if both are legal, or chooses the only
legal side without a draw. Failure retains a charged cadence and accepts damage.
Success cancels only that request and its combo follow-ups, resets the cadence,
interrupts the current ordinary action and starts `goddess.dodge`. Its four
vanish frames span eight 60 Hz authoring ticks, ceil-scaled to the simulation.
It grants no blanket invulnerability: earlier requests in the same damage batch
must still apply. Movement/navigation locks and brief gravity suppression hold
her during the vanish.

Before water/navigation on the execution tick, preparation validates the exact
action/start tick and recomputes the landing from current player position.
Close dodges retain the crossing rule; distant dodges retain their committed
left/right side without resampling. A destination that becomes blocked cancels
the dodge. It uses terrain-owned begin/commit/cancel teleport APIs, then commits
ordinary `goddess.claw_combo` facing the player. That reactive counter bypasses
the rotation cooldown but preserves the longer of its new cooldown and the
remaining prior cooldown; it does not advance the normal action sequence.
Death, stun, suspension, replacement or an invalid landing cancels the pending
counter and releases gravity suppression. Barrage casting, its exit and voluntary repositioning are never
interrupted by this dodge.

Goddess captures the cast start tick,
first release tick and sweep direction. Six hands use
the already committed target-point payload, at ceil(0.35 × tickHz) intervals and six
evenly spaced floor marks inset 50 units from the arena edges. Her far upper
corner is inset 64 units and 150 units above the level floor. Corner entry uses a
terrain-owned checked teleport. Both corners blocked means casting in place.
In prepared compatibility `2026.10.11`, the committed active duration covers
five hand intervals plus the final hand's 17 quantized effect frames. The pose
policy maps preparation to frames 0–5 and that complete active window to frames
6–35. One retained recovery tick lets barrage preparation end the action itself.
The activation's unconditional protection starts on commit and ends with that
action, independently of post-hit or arena protection. Shared combat eligibility
rejects damage and statuses, including combo bypasses; protected actors remain
living AI actors. Clearing, replacing or destroying the activation clears its
protection.

After the final effect ends, barrage state and its protected action clear.
Tactical state starts one ordinary orb while retaining hover; admission temporarily
bypasses group-zero cooldown and restores the longer remaining cooldown. The
ordinary orb animation, release and recovery all finish before exit placement.
The scripted exit bypasses only the voluntary teleport interval.

Repositioning preflights candidates at player X +/-140/180/220, rejecting destinations
less than 64 units from the current body and using full-capsule support and arena
validation. It uniformly samples the legal candidates and captures the destination.
`goddess.reposition_out` maps four frames across 18 authoring ticks. Placement
commits through terrain begin/commit/cancel before water/navigation; it never
retargets the captured mark. `goddess.reposition_in` maps five reappearance frames
across 12 active and 18 recovery authoring ticks. Neither action grants protection.
`EntityRenderSnapshot.teleportDestination` exposes the captured body center only
while the exact outgoing action/start tick remains current and alive. Flame's
`TeleportDestinationCues` draws that world-space mark without deciding timing.
The generic animation resolver accepts committed spawn/reappearance action frames.

Death, stun, suspension or action replacement cancels owned transitions and hover
without erasing a replacement ability. Blocked regular placements retain attacks
and delay another placement attempt by one second. A blocked exit releases hover
and ordinary gravity lands her; there is no glide-to-origin state or snap fallback.
Every store is removed before ID reuse. Already released hand effects retain
normal independent impact lifetimes. Floor marks with no supporting surface are
skipped without changing the remaining hand schedule or full casting duration.
Goddess opts into `EnemyArchetype.preserveReleasedSpellsOnDefeat`: arena defeat
retains her launched projectiles and world-anchored hands. They remain damaging
through their existing hit/expiry rules while pending casts and attached melee
end. At boss despawn, `EcsWorld` detaches surviving attacks from the recycled
entity ID and retains their enemy attribution; summon-owned attacks still cascade
to destruction. Her death does not extend any released spell's lifetime.
Each spawned hand has its own ordinary one-hit ledger and deals 1200 fixed-point
dark damage. Render and damage use a 0.06-second authored frame step, rounded
to simulation ticks. Ten harmless frames therefore warn for 20/40/50 ticks at
30/60/90 Hz (about 0.6 seconds); frames 10–14 can slap once. Marks stay fixed
regardless of subsequent player movement. Committed effects retain normal
impact lifetime behavior.
Each active hand frame uses a union of capsules traced around its palm and
fingers, converted from source pixels about `(69,92)` at the effect's 1.5x scale.
Detached motes, impact streaks and transparent corners are outside the damage
silhouette. All capsules share that hand's one-hit ledger and world anchor;
caster facing cannot mirror the floor effect.

`BossSummonDelivery` defines type, per-cast count (default one), living cap and
lifetime. Summon candidates are captured target X plus `[72, -72, 120, -120]`, in stable order. Admission
uses existing encounter spawn requests, published terrain support and clearance,
full-capsule horizontal bounds, player spacing and 40-unit summon spacing.
Each successful candidate creates one normal spawn-intro actor with the owner's
motion bounds, until the cast count or living cap is reached. Newly admitted
actors participate in subsequent spacing checks. Rejected candidates admit no
actor; unavailable space never postpones a released summon into a later cast.

`BossTeleportDelivery` preflights captured target X ±150, preferring the opposite
side, before accepting an action. Candidates require terrain clearance, full
capsule bounds, 70-unit target spacing and 64-unit displacement from the origin.
The captured body center is published through the existing snapshot
`teleportDestination` cue only while its exact ability/start identity survives
and placement is pending. Death, suspension, stun or interruption hides the cue.
At execution, the same supported body center and current player spacing are
revalidated; no alternate destination can replace the visible mark. Motion uses
`beginBodyTeleport` / `tryCommitBodyTeleport` / `cancelBodyTeleport`; invalidated
placement retains the origin and ordinary return/cooldown. Failed preflight
commits nothing, allowing the decision system's attack fallback.

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
Goddess has 300 HP (30000 fixed-point current and maximum health), with no
passive regeneration. Her actor art uses 1.0x scale, with a matching 18-by-54
body collider, scaled claw geometry and 35-world-unit approach stand-off.
Shoggoth also uses 1.0x actor scale, with a matching 32-by-52 body and
rescaled melee capsules. Voidcaller, summons, projectiles and impact art retain
1.5x scale. Source rectangles and pivots
remain source-pixel coordinates. Collider and attack dimensions are world units.
Ground-enemy jump templates use the terrain capsule's quantized radius and
spine, keeping graph and collision dimensions identical at fractional scales.
The source-backed Entities parser resolves static const visuals through explicit
relative imports and preserves anchor rewrite bindings in each actor's render
catalog. Collider and scale writes target the owning
`enemies/catalog/<name>_enemy.dart` definition; `enemy_catalog.dart` only provides
lookup. The existing guarded export transaction updates the definition and
render catalog together.

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
Component-supplied paints are copied with antialiasing disabled, preserving
effect/ghost tint and opacity without mutating the caller's paint.

`tools/combat/generate_voidcaller_effects.py` derives component crop rectangles
from source alpha bounds and generates `voidcaller_effect_catalog.dart`.
`generate_projectile_profiles.py` includes the new projectile poses. Run both
with `--check` to detect stale outputs; never hand-edit generated catalogs.

## Verification

The [October 9 Shoggoth verification](../verification/shoggoth-boss-2026-10-09.md)
records the new phase, movement, teleport, arena and replay checks, including
the unrelated failures in the broader boss run and the limits of local evidence.

The October 10 scale correction adds 48 grounded attack cases: sweeps, normal
charges, return charges and orbs against both characters in both facings at
30/60/90 Hz. Targets retain catalog bodies and ordinary floor contact, including
terrain collision skin. Real-PNG checks require sweep and front/rear spin pixels
within the middle 60% of a standing player's body, and render
`.tmp/shoggoth_height_preview.png` for visual inspection. Matching capsule tests
reject the previous enlarged arc's invisible reach. The 21 Shoggoth arena cases
and three phase/return-charge replay cases also pass with the smaller body.
Casting regressions additionally cover side changes through the release tick,
elevated targets, fixed hand origins, unchanged flight after turning, interrupted
intents and recycled projectile-origin state at 30/60/90 Hz. Three normal-input
replays cross the boss during windup and verify the first projectile snapshot
at the hand tip. Real-PNG casting checks render both facings and three aim angles
to `.tmp/shoggoth_cast_release.png`.

Arena tests cover deterministic duplicate runs at 30/60/90 Hz, introduction,
confinement, teleport/return, summon caps and lifetime, stationary tentacles,
both characters' real-combat victories, release and recycled-owner cleanup.
Effect tests verify captured surfaces, harmless warning frames, evasion and
one hit per distinct swing/pulse at all three rates. Barrage tests cover six
scheduled floor marks (six on a complete floor; unsupported marks skipped),
hover and orb/teleport exits in flat and authored Forest rooms, plus
cancelled/replaced/dead casts and recycled IDs. Tactical regressions cover
orb budgets, fixed approach bounds, captured legal landings, recovery, seeded
close choices, dodge cadence reset and cancellation at 30/60/90 Hz. Combo tests
verify turning and matching damage for all four strikes, terrain-resolved pursuit,
recovery, stand-off, blocked routes and movement locks for normal/counter combos.
Victory controllers evade tracking claws with ordinary retreat/jump/dash inputs
and punish recovery; player and boss combat stats remain catalog values. These are
finite 600-unit arenas, not ambient enemy traversal or full-level pursuit checks.
Render tests load every catalog frame,
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
