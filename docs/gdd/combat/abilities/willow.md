# Willow

Willow is the playable bounty hunter. Choose Éloïse or Willow before opening
the character builder; each keeps her own gear and six ability selections.
The builder's character-name button returns to selection. Start and Restart
use the remembered build without making the player choose again.

## Resources and weapons

Willow has 90 health, 100 stamina and 100 Supplies. Baseline regeneration is
0.5 health, 1.5 stamina and 3 Supplies per second. Supplies power shots and
fieldcraft; bombs have unlimited uses and only a cooldown. There are no ammo
pickups, magazines or finite bomb stocks.

Equip one ranged weapon before a run. The weapon changes the sprite set,
projectile, speed, damage multiplier and minimum pellet count. All three are
starter choices. The ranged ability determines aiming, charge and piercing.

| Weapon | Speed (world units/s) | Lifetime | Ability damage multiplier | Pattern |
| --- | ---: | ---: | ---: | --- |
| Pistol | 720 | 0.90s | 1.00 | One bullet |
| Crossbow | 600 | 1.40s | 1.15 | One bolt |
| Shotgun | 620 | 0.42s | 1.30 | At least three pellets |

Scatter Shot uses five pellets with any weapon. Listed shot damage is a total
budget divided across pellets, not damage per pellet. Weapon choice does not
change the base Supplies cost. Ordinary gear,
status, critical-hit and resistance rules still apply.

## Complete roster: 25 abilities

Numbers below are authored base values before gear and status modifiers.
Cooldown durations use the 60 Hz authoring clock and scale with runtime tick
rate. Equip one ability per slot.

| Slot | Ability | Base effect | Cost | Cooldown |
| --- | --- | --- | --- | --- |
| Primary | Quick Cut | One 12-damage slash | 4 stamina | 0.30s |
| Primary | Twin Cut | Two 9-damage slashes | 7 stamina | 0.65s |
| Primary | Threefold Cut | Three 8.5-damage slashes | 10 stamina | 0.80s |
| Primary | Lunge Slash | Advance during the strike; 17 damage | 8 stamina | 0.53s |
| Secondary | Blast Bomb | 26 damage, radius 48 | Free | 4s |
| Secondary | Shrapnel Bomb | 17 damage and bleed, radius 48 | Free | 5s |
| Secondary | Fire Bomb | 16 fire damage and burn, radius 48 | Free | 5s |
| Secondary | Concussion Bomb | 10 damage and 1s stun, radius 54 | Free | 6s |
| Ranged | Snap Shot | Auto-aim; 13 damage budget | 7 Supplies | 0.50s |
| Ranged | Quick Shot | Aim and release; 9 damage budget | 4 Supplies | 0.27s |
| Ranged | Piercing Shot | 17 damage budget; up to three targets per projectile | 10 Supplies | 0.60s |
| Ranged | Scatter Shot | Five-pellet fan, 22 damage budget | 11 Supplies | 0.70s |
| Ranged | Charged Shot | 23 base damage budget, 70–150% by charge | 13 Supplies | 0.75s |
| Mobility | Dash | Ground/air, 550 units/s for 0.20s | 2 stamina | 2s |
| Mobility | Roll | Ground, low body pose, 320 units/s for 0.30s | 3 stamina | 2s |
| Mobility | Slide | Ground, low body pose, 360 units/s for 0.40s | 4 stamina | 2s |
| Jump | Jump | One ground jump | 2 stamina | None |
| Jump | Double Jump | Ground jump plus one air jump | 2 + 3 stamina | None |
| Fieldcraft | Hunter's Focus | +25% power and +15% critical chance for 5s | 12 Supplies | 7s |
| Fieldcraft | Mark Quarry | +25% direct damage from Willow to one quarry for 5s | 10 Supplies | 7s |
| Fieldcraft | Forced March | +50% movement speed for 5s | 10 Supplies | 5s |
| Fieldcraft | Field Dressing | Restore 35% maximum health over 5s | 15 Supplies | 8s |
| Fieldcraft | Antidote | Cleanse harmful effects, including stun and silence | 14 Supplies | 8s |
| Fieldcraft | Second Wind | Restore 35% maximum stamina over 5s | 15 Supplies | 7s |
| Fieldcraft | Prepare Charges | Restore 35% maximum Supplies over 5s | 15 stamina | 7s |

Quick/Twin/Threefold Cut have independent per-swing hits. Mobility does not
grant invulnerability. Roll and Slide cannot commit in the air. Charged Shot
reaches the middle tier after 20 authored ticks and full charge after 45;
those tiers add 5%/10% critical chance. Full charge pierces two targets. Taking
damage interrupts Charged Shot. Mark Quarry selects the nearest living enemy
within 320 units with a clear terrain ray, breaking distance ties by entity ID.
No eligible quarry means no cost or cooldown. Damage over time does not gain
the mark bonus. Only one quarry is marked per attacker.

## Bomb behavior

Press the secondary action to drop the chosen bomb, on the ground or in the
air. After its 0.30s windup it falls, settles on terrain and detonates one second
after release. Contact causes no damage; a single blast hits each eligible
enemy once. Solid terrain blocks the blast, one-way platforms do not. Allies
and Willow are unaffected. A released bomb persists through later actions and
owner removal. An interrupted, unreleased drop cannot leave a delayed bomb.

Bombs remain usable with empty Supplies and stamina. Their cooldown is the
only repeating limit, so an endless run never exhausts a stock of bombs.

## Progression and art

Fresh profiles own the Hunter Blade, Bomb Kit, Field Kit and all three guns.
Starter abilities are Quick Cut, Blast Bomb, Snap Shot, Dash, Jump, Hunter's
Focus and Prepare Charges. Other abilities use the existing store price of
150 gold and normal store offer rotation. Developer Practice unlocks all 25.
Gear and skills remain character-specific; accessories are shared.

The imported base/add-on sprites provide gameplay animations, gun variants and
bomb effects. Newly added items and abilities have empty illustration areas
until dedicated illustrations exist. Fieldcraft uses the ready pose because the
pack has no dedicated fieldcraft casting animation. Unused ladder, ledge and
wall-slide art does not add new traversal mechanics.

See the [technical contract](../../../tdd/willow.md) and
[local verification](../../../verification/willow-2026-11-07.md).
