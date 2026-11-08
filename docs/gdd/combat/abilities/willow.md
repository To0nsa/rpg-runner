# Willow

Willow is the playable bounty hunter. Choose Éloïse or Willow before opening
the character builder. Each character has three independent builds with their
own gear, ranged weapon and six abilities. Tap a card to select its character,
or a build button to open that configuration. Build 1 is available immediately;
Build 2 unlocks at confirmed account level 5 and Build 3 at level 12. Locked
buttons show their required level, including in Developer Practice.

Both cards fit on one screen, with illustration/name on the left, build buttons
on the right, and a dark overlay marking the unselected character. Builds start
as Build 1/2/3 and can be renamed from the builder header using up to 28
characters. Start, Restart and Training Field use the remembered build.


Willow and Éloïse share the same apparent body size in menus and gameplay.
Willow's grounded feet meet the floor across all three weapon art families; held
weapons can extend above the head. Her collision and blade geometry follow her
scaled body and action poses.

## Resources and weapons

Willow has 90 health, 100 stamina and 100 Supplies. Baseline regeneration is
0.5 health, 1.5 stamina and 3 Supplies per second. Supplies power shots,
fieldcraft and bomb throws. There are no ammo
pickups, magazines or finite bomb stocks.

Equip one ranged weapon before a run. The weapon changes the sprite set,
projectile, speed, damage multiplier and minimum pellet count. The three weapons
below are starter choices; five additional variants unlock through the store or
gifts. The ranged ability determines aiming, charge and piercing.

| Weapon | Speed (world units/s) | Lifetime | Ability damage multiplier | Pattern |
| --- | ---: | ---: | ---: | --- |
| Pistol | 720 | 0.90s | 1.00 | One bullet |
| Crossbow | 600 | 1.40s | 1.15 | One bolt |
| Shotgun | 620 | 0.42s | 1.30 | At least three pellets |

Bullets, bolts and pellets leave the visible weapon tip while standing,
running or airborne, mirrored with Willow's facing. A fan starts at one shared
muzzle and spreads along its shot directions.
Willow keeps facing the shot through its windup and release while still moving
normally, so running away from a target does not switch the firing muzzle.
Turning follows movement again after release or cancellation.

Scatter Shot uses five pellets with any weapon. Listed shot damage is a total
budget divided across pellets, not damage per pellet. Weapon choice does not
change the base Supplies cost. The [complete equipment roster](../gears/willow_equipment_roster.md) lists all
42 compatible items, including 8 blades, 10 bomb kits, 8 field kits, 8 ranged
weapons and 8 shared accessories. Ordinary gear,
status, critical-hit and resistance rules still apply.

## Complete roster: 24 abilities

Numbers below are authored base values before gear and status modifiers.
The starter blade, bomb kit and field kit now contribute passive bonuses;
base resource and damage values are not final equipped totals.
Cooldown durations use the 60 Hz authoring clock and scale with runtime tick
rate. Equip one ability per slot.

| Slot | Ability | Base effect | Cost | Cooldown |
| --- | --- | --- | --- | --- |
| Primary | Quick Cut | One 12-damage slash | 4 stamina | 0.30s |
| Primary | Twin Cut | Two 9-damage slashes | 7 stamina | 0.65s |
| Primary | Lunge Slash | Advance during the strike; 17 damage | 8 stamina | 0.53s |
| Secondary | Blast Bomb | 26 damage, radius 48 | 6 Supplies | 4s |
| Secondary | Shrapnel Bomb | 17 damage and bleed, radius 48 | 6 Supplies | 5s |
| Secondary | Fire Bomb | 16 fire damage and burn, radius 48 | 6 Supplies | 5s |
| Secondary | Concussion Bomb | 10 damage and 1s stun, radius 54 | 6 Supplies | 6s |
| Ranged | Snap Shot | Auto-aim; 13 damage budget | 7 Supplies | 0.50s |
| Ranged | Quick Shot | Aim and release; 9 damage budget | 4 Supplies | 0.27s |
| Ranged | Piercing Shot | 17 damage budget; up to three targets per projectile | 10 Supplies | 0.60s |
| Ranged | Scatter Shot | Five-pellet fan, 22 damage budget | 11 Supplies | 0.70s |
| Ranged | Charged Shot | 23 base damage budget, 70–150% by charge | 13 Supplies | 0.75s |
| Mobility | Dash | Ground/air, 550 units/s for 0.20s | 2 stamina | 2s |
| Mobility | Double Dash | Ground/air, up to two 68.75-unit bursts; second tap within 0.5s after burst one | 2 stamina per burst | 2s from first burst |
| Mobility | Blink Dash | Cross a nearby obstacle up to 138 units wide; clear exit required | 4 Stamina | 3s |
| Jump | Jump | One ground jump | 2 stamina | None |
| Jump | Double Jump | Ground jump plus one air jump | 2 + 3 stamina | None |
| Fieldcraft | Hunter's Focus | +25% power and +15% critical chance for 5s | 12 Supplies | 7s |
| Fieldcraft | Mark Quarry | +25% direct damage from Willow to one quarry for 5s | 10 Supplies | 7s |
| Fieldcraft | Forced March | +50% movement speed for 5s | 10 Supplies | 5s |
| Fieldcraft | Field Dressing | Restore 35% maximum health over 5s | 15 Supplies | 8s |
| Fieldcraft | Antidote | Cleanse harmful effects, including stun and silence | 14 Supplies | 8s |
| Fieldcraft | Second Wind | Restore 35% maximum stamina over 5s | 15 Supplies | 7s |
| Fieldcraft | Prepare Charges | Restore 35% maximum Supplies over 5s | 15 stamina | 7s |

Double Dash lets you change direction between bursts. Early taps do not queue
the second burst; its `+1` indicator appears when the follow-up becomes usable.
Skipping the follow-up spends no additional stamina. Both bursts share the
cooldown started by the first tap.

Quick Cut and Twin Cut have independent per-swing hits. Twin Cut uses the low
sweep and overhead slash from the add-on combo, ending before the weapon draw.
It retains two 9-damage hits, 7 stamina and its 0.65-second base cooldown.
Threefold Cut, Roll and Slide are no longer selectable or purchasable.
Dash and Double Dash grant no invulnerability; Blink Dash protects only while
vanished. Charged Shot reaches the middle tier after 20 authored ticks and full
charge after 45;
those tiers add 5%/10% critical chance. Full charge pierces two targets. Taking
damage interrupts Charged Shot. Mark Quarry selects the nearest living enemy
within 320 units with a clear terrain ray, breaking distance ties by entity ID.
No eligible quarry means no cost or cooldown. Damage over time does not gain
the mark bonus. Only one quarry is marked per attacker.

Dash plays frames 1–3, holds frame 4 through the dash and its remaining ground
slide, then plays recovery frames 5–7 before returning to running or idle.
Jumps, new actions, turning around and damage reactions take over immediately.
Airborne exits return to the air animation. This extra animation coverage does
not extend the movement burst or change dash distance, cost or cooldown.

Blink Dash is a separate mobility choice. Willow prepares for 0.20s, vanishes
for 0.05s while relocating, then reappears through a 0.25s recovery. It travels
110 units in open space or just beyond the first solid obstacle within 32 units
of her body. The 138-unit obstacle limit matches the widest tent **as placed in
the woodcamp chunks**, including its 1.5 scale. She needs room for her whole body
at the exit; a blocked or oversized crossing costs no stamina or cooldown.
It works in either direction, on the ground or airborne, preserving height.
She is protected only while invisible; damage interrupts visible preparation
and recovery. Blink Dash deals no damage. Lunge Slash uses the final five-frame
blade attack strip instead of the teleport art.

## Bomb behavior

Press the secondary action to throw the chosen bomb, on the ground or in the
air. After its 0.30s windup it leaves the throwing hand in an upward arc. Auto-aim
selects the farthest reachable enemy within 320 units, leading its motion over
a 0.8s flight and rejecting terrain-blocked arcs. Without a target, Willow lobs
forward. The bomb detonates on enemy or terrain contact, or one second after
release, whichever happens first. A single blast hits each eligible enemy once.
Solid terrain blocks the blast, one-way platforms do not. Allies
and Willow are unaffected. A released bomb persists through later actions and
owner removal. An interrupted, unreleased throw cannot leave a delayed bomb.
The bomb and its explosion use the same sprite scale as Willow.

Every bomb costs 6 Supplies when the throw commits; insufficient Supplies
prevents the action and starts no cooldown. Bombs cost no stamina and have no
finite inventory. Their existing cooldowns still apply.

## Progression and art

Fresh profiles own the Hunter Blade, Bomb Kit, Field Kit and the three starter
guns. The 28 additional equipment items each use the existing 150-gold store
price and normal offer rotation.
Starter abilities are Quick Cut, Blast Bomb, Snap Shot, Dash, Jump, Hunter's
Focus and Prepare Charges. Other abilities use the existing store price of
150 gold and normal store offer rotation. Developer Practice unlocks all 24.
Gear and skills remain character-specific; accessories are shared.

The imported base/add-on sprites provide gameplay animations, gun variants and
bomb effects. All 34 Willow-specific equipment items now have dedicated
illustrations; the eight shared accessories retain their existing art.
All 24 abilities have distinct transparent pixel-art icons. Blade arcs distinguish
single and double attacks; bomb effects distinguish blast, fragments,
fire and concussion. Projectile icons describe guidance, piercing, spread or
charge independently of the equipped ranged weapon. Fieldcraft uses preparation,
recovery and tracking symbols. See [ability-art verification](../../../verification/ability-icon-art-2026-11-08.md).
Fieldcraft uses the ready pose because the
pack has no dedicated fieldcraft casting animation. Unused ladder, ledge and
wall-slide art does not add new traversal mechanics.

See the [technical contract](../../../tdd/willow.md) and
[local verification](../../../verification/willow-2026-11-07.md).
