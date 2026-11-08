# Willow implementation contract

Willow's gameplay is defined in Core; Flutter owns selection and labels, and
Flame consumes Core animation metadata and snapshots. See the
[roster and tuning](../gdd/combat/abilities/willow.md).

## Identities, selection and ownership

The display name is `Willow`. Internal IDs remain `bountyHunter` for the
character, `bounty_hunter.*` for abilities and `hunter*` for equipment/projectiles;
asset paths retain the source pack's `bounty_hunter` name. No aliases are needed.
`PlayerCharacterRegistry.playable` exposes Éloïse and Willow, excluding Éloïse WIP.

Hub Edit opens `/setup/character`. Card taps select in place; three build
buttons on each card select an independent saved configuration before opening
the builder. Build 2 requires level 5 and Build 3 requires level 12. Unselected
cards share the level selector's dark scrim and both fit without scrolling.
Builder actions show the current build name with a 28-character rename control.
Start, Restart and Training Field resolve the selected build. Developer Practice
unlocks compatible catalog content while retaining build-level locks. See the
[build persistence and authorization contract](character_builds.md).

`CharacterEquipmentPolicy` gates gear by character catalog weapon families and
ranged sources by their required weapon types. Core meta normalization and UI
pickers use it; TypeScript's `ownership/character_catalog.ts` mirrors the IDs,
starter grants and families. Whole selection/loadout authorization, individual
equip/learn commands, store offers and inbox rewards enforce both ownership
and compatibility. Admin uses shared Core presentation to filter recipients.
Account-wide accessories remain available to both characters.

Fresh backend profiles contain Willow's complete starter branches. There is no
new old-profile migration or older-client selection fallback. Development
accounts predating this content can be reset through the existing account flow.
The local implementation does not perform remote data resets or cancellations.
Revision, command idempotency, auth and reward settlement behavior are unchanged.

## Simulation extensions and order

All timings are authored at 60 Hz and scaled by existing tick math. Supplies
reuse Core's mana store and serialized contracts; the UI changes the resource
label for Willow. No new command encoding or resource authority is introduced.

- `BombHitDelivery` commits through the secondary weapon and offhand slot mask.
  `ProjectileLaunchSystem` materializes a bomb only when the queued release
  tick survives interruption. `BombStore` holds radius, absolute fuse tick and
  the once-only explosion flag.
- Ordinary terrain motion runs before bombs. Terrain collision disables a
  grounded bomb's body without deleting the projectile. Projectile contact,
  flight-pose and directional-animation systems skip bombs.
- `BombSystem` runs after combat hurtboxes and broadphase, before hit damage.
  It collects ordered hostile overlaps, checks a solid-terrain ray to each
  target and queues one damage request per target. Fuse animation and the
  explosion clock come from Core. The nine-frame explosion stays alive for
  the quantized frame duration, without another damage pulse.
- Projectile fans use the larger ability/item pellet count and angular spread.
  Item damage multipliers apply to the total budget; integer remainders are
  distributed in stable pellet order. Single-shot direction behavior remains
  unchanged.
- `MarkHitDelivery` captures a quarry before cost/cooldown commitment.
  `SelfAbilitySystem` writes attacker-owned `TargetMarkStore` state only if the
  captured quarry is alive. `TargetMarkMiddleware` adjusts matching direct
  damage before normal damage resolution; expiry is an absolute tick check.
  World destruction removes marks involving either endpoint and clears pending
  quarry references before IDs can be recycled. Released bombs detach from
  destroyed owners while retaining their damage credit.
- `CombatLungeSystem` applies authored forward velocity only during the active
  phase, before knockback, gravity and terrain. Ground-only movement checks
  support before commit. Neither low poses nor mobility add protection flags.

The existing status pipeline handles bleed, burn, stun, buffs, restoration and
cleanse. Antidote explicitly allows committing while stunned. Charged Shot opts
into damage interruption using the existing policy. No UI timers apply effects.

## Blink Dash

`BlinkMobilityDef` configures a horizontal displacement in the existing mobility
slot. `AbilityActivationSystem` asks terrain authority for a full-capsule sweep
and a clear destination before paying stamina or starting cooldown. Open travel
is 110 world units. The first solid obstacle must be within 32 units of capsule
travel and at most 138 units wide, measured from placed polygon bounds. This is
`woods_tent_02`'s 92-unit collision width at the chunks' scale 1.5; smaller tents
and atlas padding do not define the limit. Exit includes body radius and 2 units
of clearance. One-way platforms do not obstruct blink. Height is preserved;
landing support is optional so a blink may cross a gap and then fall.

The committed destination lives in `MobilityIntentStore` and is guarded by
ability ID and commit tick. `MobilitySystem` holds motion through preparation,
relocates once through the existing begin/commit/cancel teleport authority, and
holds recovery. Execution revalidates clearance and encounter bounds; failure
restores the origin and refunds stamina/cooldown. Jump, damage, stun, death or
replacement cannot execute a stale destination. World authority also fences
teleports to encounter confinement. Swapped/reused intent entries reset targets.

Authored phases are 12/3/15 ticks at 60 Hz, with a 180-tick cooldown and 4 stamina
base cost. Only the invisible active phase grants protection; preparation and
recovery remain vulnerable. The action-frame policy maps these phases to four
preparation frames, one blank frame and five recovery frames in every gun family.
No damage payload is emitted. Signed blink displacement joins ordinary movement
once in run-distance accounting; normal Dash keeps its existing behavior.

The client, Functions catalog, Admin fixture and replay worker share the ability
ID and compatibility `2026.11.8.2`. Command and replay shapes are unchanged.

## Animation and collision

`players/characters/bounty_hunter.dart` defines native frame composition for
pistol, crossbow and shotgun. Base 73×54 cells occupy `(6,11)` on an 89×65
canvas; add-on cells use `(0,0)`. The common anchor is `(34,47)`, with the support
line at canvas y=64 aligned to the character's terrain capsule. Cells are not stretched.
`PlayerCharacterDefinition.renderScale` owns source-pixel scale for live play,
ghosts and menu previews: Willow uses 1.35 and Éloïse retains 0.75. Their idle
reference bodies have the same apparent height. Willow's 21.6×43.2 terrain
capsule, y offset 1.35, cast origin and combat poses use the corresponding world
units. Menu previews share a world-space viewport and foot baseline; they do
not fit each full transparent frame or apply a character-selection-only zoom.
The Entities editor reads the definition's scale, retaining guarded bindings to
imported constants and the shared default. Collider literals remain editable.
The source Dash Attack exports ten files, one entirely transparent; Blink Dash restores the transparent fifth frame as an empty composite between
the nine visible sheet poses (row 27 onward). Lunge Slash uses the final five-frame
strip (row 29), with strike frames 2�3 and recovery frames 4�5.

The seven-frame mobility Dash uses `dashHoldFrame: 3` (zero-based) in all
weapon variants. `AnimSystem` plays frames 1–3 at the quantized authored step,
holds frame 4 through the active dash and excess grounded momentum, then plays
frames 5–7 once normal input-driven speed is reached (or she stops with no
input). `AnimStateStore` tracks this presentation by activation/recovery ticks;
both full and actor snapshots project it through the existing animation fields.
Jump, another action, reversal, swimming, hit, stun or death cancels it. An
airborne dash exit returns to jump/fall rather than grounded recovery poses.
The ordinary action animation remains the combat pose clock: this visual tail
changes no movement, collision, ability duration, cost or cooldown.

`BountyHunterPoseCatalog` owns Willow's vulnerable poses and four melee strike
profiles. `HitboxFollowOwnerSystem` receives the selected render metadata and
recognizes Twin Cut, Threefold Cut and Lunge Slash. Each visible swing uses
the existing combo hit policy and damage protection exception. Terrain capsules
remain separate from low combat hurtboxes.

AnimSystem chooses ground/air/run shots, air hurt/death and the short double-jump
sequence. Run shooting combines three firing phases with eight locomotion poses.
GameCore resolves the equipped gun's render variant; GameController, Flame and
ghosts consume the same metadata. Projectile silhouettes are generated from
the imported art through `tools/combat/generate_projectile_profiles.py`.
Projectile render definitions are explicit constants. The Entities editor reuses
its guarded relative-import resolver to retain their source bindings and previews.

`PlayerCharacterDefinition.projectileMuzzles` owns each gun's firing-tip
geometry in world units. Native barrel endpoints are translated through the
composed canvas pivot and Willow's 1.35 scale. Posture selection and the eight
running-body frames share AnimSystem's quantized clock. ProjectileLaunchSystem
samples current support, velocity, facing and position at release, before
spawning all pellets at one tip; aim changes velocity rather than rotating the
muzzle offset. Auto aim forecasts that same attachment, including terrain
sightlines, and retains the chosen muzzle's facing for close quarries. Missing
attachments preserve the existing caster-owned radial offset. Bomb drops and
autonomous casters retain their existing launch contracts. Tick order and
command encoding are unchanged; matching client/worker Core builds are required
because projectile origins affect hits. See the
[muzzle verification](../verification/willow-projectile-muzzles-2026-11-08.md).

Shared presentation maps all 34 Willow-specific equipment identities to dedicated
64×64 transparent PNGs in `assets/images/icons/gear-icons/willow/`.
`ui_icon_coords.dart` owns weapon, field-kit and ranged-item asset keys.
`GearIcon` and `ProjectileIconFrame` resolve them through the consumer's asset
bundle with nearest-neighbor filtering, so game menus, inbox attachments and
repository-backed Admin share the same artwork. Ranged inventory illustrations
are independent of projectile flight effects. The eight shared accessories keep
their existing icons. All 26 Willow ability IDs map to dedicated 64×64 transparent
PNGs under `assets/images/icons/skills-icons/willow/` in
`ability_skill_icon.dart`. `AbilitySkillIcon` uses the consumer asset bundle and
nearest-neighbor filtering; unknown IDs remain empty fixed-size boxes. See
[ability-art verification](../verification/ability-icon-art-2026-11-08.md).
Gameplay effects, the character portrait and animated previews still use supplied
assets. See [item-art verification](../verification/willow-item-art-2026-11-08.md).

## Replay and validation

Client, Functions and worker use local gameplay compatibility `2026.11.8.2`;
replay/command format 1, rules-v2, score-v4 and ghost-v1 remain unchanged.
The version check prevents different simulations from accepting the same run.
It does not require a production data migration. Ranked seed preparation is
refreshed with the existing offline helper; navigation geometry is unchanged.
No deployment, board mutation or ticket cancellation is part of this work.

Core tests exercise all 26 commits, real melee damage at 30/60/120 Hz, bomb
terrain/lifecycle/status behavior, fan budgets, fieldcraft, marks and charged
shot interruption. Worker tests replay recorded inputs for each weapon. Widget
tests exercise character switching, remembered builds and actual Training Field
rendering. See [initial verification](../verification/willow-2026-11-07.md) and
[scale and selection checks](../verification/willow-scale-and-selection-2026-11-07.md).

## Equipment parity

[The equipment roster](../gdd/combat/gears/willow_equipment_roster.md) contains
8 blades, 10 bomb kits, 8 field kits and 8 ranged items, plus 8 shared accessories.
New enum values are appended; retained identifiers and indices do not move.
Starter grants remain the original three kits and three guns. All 28 additions
use the existing 150-gold store/gift paths. No schema or data reset is required.

Core family validation remains based on WeaponType. Functions' explicit family
lists cover every item; the full ranged list is separate from starter grants.
Both store offers and inbox catalog entries derive from those definitions.
The generated Admin fixture and its catalog hash must be refreshed together;
activating that hash in an environment remains a separately authorized release.

Each ranged item retains its actual ID in loadouts, projectiles, snapshots and
replays while resolving the pistol/crossbow/shotgun animation family. Projectile
capsules are regenerated from the canonical art, not handwritten. Damage remains
one total budget divided across the larger ability/item pellet count.

Blade outgoing procs flow only through melee payloads; bomb-kit outgoing procs
flow through the committed offhand blast payload. Field kits remain stat-only.
Ability-first hook/profile deduplication and normal same-channel status merging
remain authoritative. Backtrail Rig uses the shared low-health reactive pipeline.
ReactiveProcSystem receives GameCore's tick rate and scales authored 60 Hz
cooldowns, so 1800 authored ticks are 30 seconds at all supported rates.

The client, Functions issuer and worker require compatibility `2026.11.8.2` for
these changed outcomes. This is source preparation only, not a deployment.

See [equipment verification](../verification/willow-equipment-2026-11-08.md) for
local checks and the remaining release/balance boundaries. Item illustrations are
covered by the [art verification](../verification/willow-item-art-2026-11-08.md).
