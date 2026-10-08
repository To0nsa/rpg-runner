# Mixed damage

An attack remains one hit when it contains multiple damage types. Its total
fixed-point amount and immutable `DamageComposition` travel together through
payloads, intents, hitboxes/projectiles and the damage queue. `DamageType` itself
implements a single-type composition, so existing authoring retains its behavior.
`DamageTypeMix` provides nonnegative integer weights for every damage type and
requires at least one positive weight.

## Authoring

```dart
baseDamage: 2200, // 22 HP total
baseDamageType: const DamageTypeMix(physical: 1, dark: 1),
```

This is the current `bringer.scythe_sweep` payload: 11 physical plus 11 dark.
Weights describe relative shares, not additional damage. For example a total of
1500 with physical 2 and dark 1 gives 10 physical plus 5 dark. More than two types
are supported. Melee, projectiles, target-point spells and mobility contact hits
share the same representation; no boss-specific resolution exists.

`HitPayloadBuilder` applies power to the total. An item's damage type converts
only the physical share and merges it with an existing share of that element.
Other authored elements remain intact. Charge scaling and riposte bonuses also
modify the total without changing its proportions.

## Resolution and rounding

System ordering is unchanged. Damage middleware (guard/ward) reduces or cancels
the whole request. After eligibility and invulnerability checks, `DamageSystem`:

1. Applies source Weaken, one critical roll and global target defense to the total.
2. Splits the resulting integer amount in `DamageType.values` order. Each boundary
   is `totalAmount * cumulativeWeight ~/ totalWeight`; adjacent boundaries give
   the share amounts. This preserves the exact total before resistances. The last
   participating type receives the remaining fixed-point units.
3. Applies each type's combined creature/store and gear modifier separately,
   rounding down and clamping each result to zero.
4. Sums the shares, then applies global Vulnerable once.
5. Updates HP and resolves participation, interruption, knockback, feedback,
   reactive damage, procs, death and post-hit protection once for the hit.

The single-type path retains its existing arithmetic and RNG consumption.
Fully resisted accepted hits retain the existing on-hit proc/protection rules;
they produce no positive-HP-loss events or combo bypass permission. Mixed damage
does not create extra combo strikes or permit a different attacker to bypass
protection. See [combo rules](combat_pose_geometry.md#combo-damage-and-post-hit-protection).

Feedback and status scaling still consume one `DamageType`: the largest authored
share, with ties resolved by enum order. For the equal physical/dark sweep this
is physical. Resistance or tiny-amount rounding does not change that identity.
DoT types authored by effects remain independent. Ability tooltips append the
authored split, including mobility contact damage; they do not estimate target
resistance or claim to include equipment/charge modifiers.

## Replay compatibility and validation

Scythe Sweep retains 2200 total base damage but now responds to physical and dark
resistance independently. This gameplay change is included in the already prepared
`2026.10.11` compatibility release. Client, issuer and worker must be deployed
together; no wire format, command encoding or tick order changes are introduced.

Core tests cover individual resistance, zero damage, shared crit/proc/ward/combo
semantics, conversion and rounding. Real Scythe Sweep collision is checked facing
both directions at 30/60/90 Hz; server replay tests exercise accepted sweep hits
at all three rates. Existing delivery, charge, guard and riposte tests cover the
shared paths. Tooltip tests verify the authored breakdown.

Local validation on 2026-10-08 compiled the worker successfully. The strict
36,000-tick throughput benchmark stopped at Forest tick 820 in both the mixed
implementation and an isolated pre-change Core copy with the same local level
sources. This is existing baseline failure evidence, not a throughput pass or
deployment approval.
