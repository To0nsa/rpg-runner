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
Builder actions show the current build name with a 12-character rename control.
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
The source Dash Attack exports ten files, one entirely transparent; runtime
uses the nine visible poses packed contiguously in its sheet.

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

Shared presentation returns empty illustrations for new gear, guns and abilities.
Gameplay effects, the character portrait and animated previews still use supplied
assets. Menus do not borrow Éloïse's item artwork.

## Replay and validation

Client, Functions and worker use local gameplay compatibility `2026.11.7`;
replay/command format 1, rules-v2, score-v4 and ghost-v1 remain unchanged.
The version check prevents different simulations from accepting the same run.
It does not require a production data migration. Ranked seed preparation is
refreshed with the existing offline helper; navigation geometry is unchanged.
No deployment, board mutation or ticket cancellation is part of this work.

Core tests exercise all 25 commits, real melee damage at 30/60/120 Hz, bomb
terrain/lifecycle/status behavior, fan budgets, fieldcraft, marks and charged
shot interruption. Worker tests replay recorded inputs for each weapon. Widget
tests exercise character switching, remembered builds and actual Training Field
rendering. See [initial verification](../verification/willow-2026-11-07.md) and
[scale and selection checks](../verification/willow-scale-and-selection-2026-11-07.md).
