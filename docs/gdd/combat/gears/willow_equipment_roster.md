# Willow equipment roster

Willow has **42 selectable items**: 8 hunter blades, 10 bomb kits, 8 field kits,
8 ranged weapons and the 8 account-wide accessories. This matches Éloïse's
8 swords, 10 shields, 8 spellbooks, 8 ranged spells and 8 accessories.
The expansion adds 28 identities and gives the three starter kits passive tuning.

These values are implemented initial tuning, not evidence of competitive balance.
The intended decisions are preparation, pursuit, resource pressure and committed
attacks. Items preserve the action structure of [Willow's abilities](../abilities/willow.md).

## Ownership and progression

Fresh profiles own Hunter Blade, Bomb Kit, Field Kit, Pistol, Crossbow and Shotgun.
The 28 additions use the existing store rotation and **150 gold** item price.
They can also be granted through the existing authorized inbox catalog. Gear
ownership is account-wide, but blades/bomb kits/field kits are Willow-only;
ranged ownership is per character. Shared accessories are not duplicated or
all granted at startup: Strength Belt is the starter accessory.
Developer Practice exposes all compatible items. Saved builds, Training Field,
live gameplay and replay resolve the same catalogs.

## Stat and payload rules

- Percentages below are additive gear bonuses; critical chance uses percentage
  points. Power and cooldown changes apply to the whole loadout.
- Supplies and its regeneration use the existing mana storage and stat fields.
  Willow's gear details, comparisons and store descriptions display Supplies.
- Blade procs belong to melee payloads. Bomb-kit outgoing procs belong to blasts.
  Neither leaks into gunfire. Field kits are stat-only.
- Bomb-kit bonuses do not change the selected bomb ability, fuse, radius,
  terrain obstruction, ally safety, unlimited stock or zero resource cost.
- Ability procs precede item procs. Identical hook/profile entries are deduplicated;
  different hooks retain their tuning. Repeated same-type statuses follow normal
  refresh/strength rules, never independent copies of the same DoT channel.
- Gear/proc identities are unique within a character equipment family. Sharing
  an effect or stat pattern across mutually exclusive character families is legal.
- Reactive cooldowns use authored 60 Hz ticks converted to the runtime clock;
  Backtrail Rig's 1800 authored ticks mean 30 seconds at 30/60/120 Hz.

## Hunter blades

| Item / runtime ID | Bonuses | Tradeoff | Proc | Use |
| --- | --- | --- | --- | --- |
| Hunter Blade (`hunterBlade`) | global power +10%, stamina +15%, stamina regeneration +5% | defense -5% | None | Reliable mixed combat with a small defense tradeoff. |
| Notchknife (`hunterNotchknife`) | global power +5% | health -5% | On hit: 20% chance of bleed, 2 damage/s for 3s | Bleeding cuts reward disengaging, at the cost of maximum health. |
| Hookblade (`hunterHookblade`) | stamina regeneration +10% | defense -5% | On hit: 20% chance of movement slow, 20% for 2s | Slowing cuts create room for a shot or bomb, with lower defense. |
| Caustic Edge (`hunterCausticEdge`) | stamina +10% | health -5% | On hit: 20% chance of increased damage taken, 15% for 3s | Melee openings expose a target to follow-up damage, with lower health. |
| Cinderpoint (`hunterCinderpoint`) | critical chance +10 points | Supplies regeneration -5% | On critical hit: 100% chance of burn, 2 damage/s for 3s | Critical cuts ignite enemies, at the cost of Supplies regeneration. |
| Sapping Blade (`hunterSappingBlade`) | stamina regeneration +10% | health -5% | On hit: 20% chance of reduced damage dealt, 15% for 3s | Cuts can weaken enemy attacks, but maximum health is lower. |
| Pursuit Blade (`hunterPursuitBlade`) | global power +5%, stamina regeneration +10% | defense -5% | On kill: 35% chance of movement haste, 15% for 3s | Melee kills can grant a short burst of speed, with lower defense. |
| Last Word (`hunterLastWord`) | global power +15%, critical chance +10 points, stamina +10% | health -10% | None | Strong direct offense and stamina, with less health for mistakes. |

## Bomb kits

Kits are carried rigs; Blast, Shrapnel, Fire and Concussion remain ability choices.

| Item / runtime ID | Bonuses | Tradeoff | Proc | Use |
| --- | --- | --- | --- | --- |
| Bomb Kit (`hunterBombKit`) | defense +10%, stamina +15%, physical resistance +10% | movement speed -5% | None | A protective bomb rig that trades movement speed for steadiness. |
| Splinter Rig (`hunterSplinterRig`) | defense +5% | global power -5% | On critical hit: 100% chance of bleed, 2 damage/s for 3s | Critical blasts cause bleeding, at the cost of global power. |
| Pitch Rig (`hunterPitchRig`) | defense +5% | critical chance -5 points | On critical hit: 100% chance of burn, 2 damage/s for 3s | Critical blasts ignite survivors, with lower critical chance. |
| Snare Rig (`hunterSnareRig`) | stamina +10% | global power -5% | On hit: 25% chance of movement slow, 25% for 2s | Blasts can slow pursuers, at the cost of global power. |
| Etching Rig (`hunterEtchingRig`) | stamina regeneration +10% | critical chance -5 points | On hit: 20% chance of increased damage taken, 15% for 3s | Blasts can expose survivors to follow-up damage, with lower critical chance. |
| Sapper Harness (`hunterSapperHarness`) | defense +10%, physical resistance +15%, stamina regeneration +5% | movement speed -10% | None | Physical protection and stamina recovery, with substantially slower movement. |
| Kilnwrap Rig (`hunterKilnwrapRig`) | fire resistance +25%, defense +10%, stamina +5% | critical chance -5 points | None | Preparation for fire-heavy encounters, with lower critical chance. |
| Sealed Rig (`hunterSealedRig`) | acid resistance +20%, water resistance +15%, stamina +10% | global power -5% | None | Acid and water protection with stamina reserves, at the cost of power. |
| Stormwrap Rig (`hunterStormwrapRig`) | thunder resistance +25%, defense +5%, stamina regeneration +10% | critical chance -5 points | None | Thunder protection and stamina recovery, with lower critical chance. |
| Backtrail Rig (`hunterBacktrailRig`) | defense +10% | global power -10% | On crossing from above 30% health to 30% or below: 100% chance of movement haste, 15% for 3s; 30s internal cooldown | Low-health haste creates an escape opportunity, at a permanent power cost. |

## Field kits

All eight are stat-only, with no extra fieldcraft ability or finite inventory.

| Item / runtime ID | Bonuses | Tradeoff | Use |
| --- | --- | --- | --- |
| Field Kit (`hunterFieldKit`) | Supplies +15%, Supplies regeneration +10%, critical chance +5 points | stamina -5% | Balanced Supplies and critical chance, with a smaller stamina reserve. |
| Longtrail Pack (`hunterLongtrailPack`) | Supplies +20%, Supplies regeneration +10%, cooldown reduction +5% | health regeneration -5% | Sustained Supplies and faster recovery between actions, with slower health regeneration. |
| Marksman's Roll (`hunterMarksmanRoll`) | Supplies +10%, critical chance +10 points, cooldown reduction +5% | stamina regeneration -5% | Critical-shot preparation and faster cooldowns, with slower stamina recovery. |
| Quick-Access Satchel (`hunterQuickAccessSatchel`) | Supplies regeneration +10%, critical chance +5 points, cooldown reduction +5% | stamina -5% | Frequent short exchanges, with less stamina and no extra Supplies capacity. |
| Reserve Bandolier (`hunterReserveBandolier`) | Supplies +20%, Supplies regeneration +5%, critical chance +10 points | stamina -10% | A large opening reserve and critical chance, with substantially less stamina. |
| Tracker's Pouch (`hunterTrackerPouch`) | Supplies +10%, Supplies regeneration +5%, critical chance +10 points | health regeneration -5% | Offensive pursuit that preserves stamina, at the cost of health recovery. |
| Surveyor's Case (`hunterSurveyorCase`) | Supplies +20%, critical chance +5 points, cooldown reduction +5% | stamina regeneration -5% | A large Supplies reserve and ready utility, with slower stamina recovery. |
| Quarry Kit (`hunterQuarryKit`) | Supplies regeneration +5%, critical chance +10 points, cooldown reduction +5% | stamina -10% | Critical offensive windows and faster cooldowns, with little stamina headroom. |

## Ranged weapons

Speed is in world units/s; lifetime is in seconds; spread is the existing
angular spread field in radians. Damage multiplies the total ability budget
before division among pellets. These variants keep the existing ability costs,
aiming, charge, piercing and interruption behavior. The larger ability/item
pellet count and spread wins. There are no reloads or finite ammo stocks.

| Item / runtime ID | Art family | Speed | Lifetime | Damage | Minimum pellets | Spread | Use |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| Pistol (`hunterPistol`) | pistol | 720 | 0.9 | ×1 | 1 | 0 | Fast bullets with balanced range. Uses regenerating Supplies. |
| Crossbow (`hunterCrossbow`) | crossbow | 600 | 1.4 | ×1.15 | 1 | 0 | Long-range bolts with 15% more total damage. Uses regenerating Supplies. |
| Shotgun (`hunterShotgun`) | shotgun | 620 | 0.42 | ×1.3 | 3 | 0.18 | Short-range shells split into at least three pellets with 30% more total damage. Uses regenerating Supplies. |
| Roadside Pistol (`hunterRoadsidePistol`) | pistol | 850 | 0.55 | ×1.1 | 1 | 0 | Fast close-range bullets with 10% more damage, but shorter reach. |
| Longbarrel Pistol (`hunterLongbarrelPistol`) | pistol | 800 | 1 | ×0.9 | 1 | 0 | Fast, long-reaching bullets with 10% less damage. |
| Longwatch Crossbow (`hunterLongwatchCrossbow`) | crossbow | 720 | 1.35 | ×1 | 1 | 0 | Long-reaching, faster bolts with less damage than the standard crossbow. |
| Heavy-Limb Crossbow (`hunterHeavyLimbCrossbow`) | crossbow | 500 | 1 | ×1.25 | 1 | 0 | Heavy bolts with 25% more damage, but slower flight and shorter reach. |
| Brushgun (`hunterBrushgun`) | shotgun | 620 | 0.55 | ×1.1 | 5 | 0.28 | Five-pellet coverage with 10% more total damage; a wide spread rewards close placement. |

## Shared accessories

Use the existing [eight accessories](accessory_roster_design.md). Their mana
bonuses and restoration affect Supplies for Willow. Ownership and effect rules
are shared; no Willow-specific copies or starter grants are added.

## Example builds and balance acceptance

- Pursuit: Hookblade, Snare Rig, Quick-Access Satchel, Roadside Pistol, Speed Boots.
  Create separation and resume shooting; low stamina capacity punishes overuse.
- Quarry hunter: Caustic Edge, Etching Rig, Marksman's Roll, Heavy-Limb Crossbow,
  Strength Belt. Prepare a vulnerability window and commit a shot; weaker
  durability and stamina recovery punish missed setups.
- Long-run survivor: Sapping Blade, Sapper Harness, Longtrail Pack, Crossbow,
  Golden Ring. Trade speed and burst for resource recovery and protection.

Automated checks establish legality, ownership, effects, timing, rendering
coverage and replay determinism. Starter viability, proc frequency under real
encounter pacing, pellet concentration and sustained resource pressure still
need representative player balance sessions. No universal-best-item claim is made.

## World expression and art

External creative references were read in the parent Lothringen checkout:
`Brand/Identity.md`, `Brand/CrossMediaExpressionRules.md`,
`Brand/Naming&Terminology.md`, `Brand/VisualIdentity.md` and `Brand/VisuelTokens.md`.
Their practical tools, restrained presentation, resource pressure and situational
adaptation guide these names and tradeoffs. No new faction or historical canon
is implied. All 34 Willow-specific items have dedicated transparent 64×64
illustrations under `assets/images/icons/gear-icons/willow/`, grouped into
`blades`, `bomb_kits`, `field_kits` and `ranged`. The eight shared accessories
retain their existing illustrations. Muted steel, brass and leather, upper-left
light and dark outlines follow the existing equipment art.
Gameplay reuses the three supplied weapon animation families and their generated
silhouettes. See the [art review and provenance](../../../verification/willow-item-art-2026-11-08.md).

See the [technical contract](../../../tdd/willow.md).
