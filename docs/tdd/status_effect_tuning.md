# Status effect tuning

Core status profiles remain shared effect bundles identified by `StatusProfileId`.
Each source can supply an immutable `StatusProfileTuning` containing optional
`StatusApplicationTuning` values for any of the eleven `StatusEffectType` entries.
`StatusProfileCatalog.resolve` combines that tuning with `get`'s shared defaults.
Gameplay and UI descriptions use this same resolver.

Null fields inherit defaults. Explicit zero and false values override defaults.
Tuning does not mutate a shared profile, change effect identity, add effects to
a bundle, or change application order. Naming an effect absent from a selected
profile throws `ArgumentError`. For a bundle such as poison, `dot` and `slow`
have independent tuning; an omitted component retains its defaults.

## Authoring

For example, this proc authors 25% Weaken for three seconds:

```dart
WeaponProc(
  hook: ProcHook.onHit,
  statusProfileId: StatusProfileId.weakenOnHit,
  statusTuning: StatusProfileTuning(
    weaken: StatusApplicationTuning(
      magnitude: 2500,
      durationSeconds: 3,
    ),
  ),
)
```

Use `AbilityDef.selfStatusTuning` beside `selfStatusProfileId` for self spells;
use `MobilityImpactDef.statusTuning` beside `statusProfileId` for direct contact
effects. `WeaponProc.statusTuning` works on abilities, weapons, projectile items,
spellbooks and traps. `ReactiveProc.statusTuning` covers defensive gear effects.

| Field | Meaning |
| --- | --- |
| `magnitude` | Percent effects and power bonuses use basis points (`100 = 1%`); DoT uses fixed-point DPS (`100 = 1 HP/s`); restoration uses percent of maximum restored over the duration. |
| `durationSeconds` | Lifetime before Core tick quantization. Stun and silence use this for their control strength; their positive magnitude is an enable flag. |
| `periodSeconds` | DoT pulse interval; changing it retains the authored DPS. Restoration is continuous per tick and does not use this for cadence. |
| `scaleByDamageType` | Enables the existing positive typed-vulnerability scaling of magnitude. |
| `dotDamageType` | DoT damage channel and resistance type. |
| `resourceType` | Health, mana or stamina for restoration. |
| `critBonusBp` | The offense buff's separate critical-chance bonus; zero removes that bonus. |
| `applyOnApply` | Adds an immediate full-magnitude resource restoration before any restoration over time. With zero duration, only that immediate restoration occurs. |

Fields retain the existing effect-specific meaning; they are not new rules for
stacking, resistance, caps or immunity. DoT strength is not damage per pulse.
Resource magnitude is not restoration per pulse. Durations must be finite and
nonnegative, and pulse intervals finite and positive.

Death Pillar now authors its own Weaken tuning in `bringer_ability_defs.dart`:
2500 basis points for three seconds. Dark Bolt continues to inherit the shared
Weaken defaults of 5000 basis points for five seconds. Each can be edited
independently.

## Delivery and lifecycle

- Hit payloads retain the proc's tuning through melee, target-point and projectile
  intents, spawned hitboxes/projectiles, damage queues, and status requests.
- Proc deduplication still uses hook/profile identity and first-source precedence:
  ability, item, buffs, passives. The first proc owns its complete chance and
  tuning; a duplicate item proc cannot replace an ability's values.
- Self activation captures tuning in `SelfIntentStore`. Swap removal and entity
  recycling follow the store's ordinary lifecycle.
- Direct mobility and reactive procs pass tuning into `StatusRequest`.
- `StatusSystem` resolves the selected profile and local tuning before ordinary
  immunity, invulnerability, scaling, duration quantization and stacking rules.
  Accepted-hit provenance remains independent of tuning.

## Target scaling

`StatusScalingDef` describes the recipient's resistance or weakness, separate
from the source's `StatusProfileTuning` and the all-or-nothing
`StatusImmunityDef`. Player, enemy and NPC catalogs carry the same `statusScaling`
and `statusImmunity` definitions through spawning into their shared world stores.
The shared `StatusSystem` applies the same scaling rules to every actor. It is not
conditional on boss identity. An absent component or omitted catalog field is
neutral. The world registers the store for swap removal and entity recycling.

```dart
StatusScalingDef(
  defaultDebuff: StatusEffectScaling(magnitudeScaleBp: 5000),
  // Override the complete pair: full strength, one-quarter duration.
  slow: StatusEffectScaling(durationScaleBp: 2500),
  // Weakness: 50% stronger Vulnerable, with its full authored duration.
  vulnerable: StatusEffectScaling(magnitudeScaleBp: 15000),
)
```

Both multipliers are nonnegative: `10000` retains the full effect, `5000` retains
half, `15000` applies 1.5 times the authored value, and `0` removes that dimension.
Negative values are invalid. Values above `10000` allow stronger or longer
effects, subject to the existing effect caps (for example, Vulnerable remains
capped at 9000 basis points). The default applies to DoT, Slow, Stun, Vulnerable,
Weaken, Drench and Silence. Each named effect can override both multipliers; omitted fields
within that override use `10000`, rather than inheriting the default pair.
Haste, damage reduction, restoration and offense buffs always remain unchanged.

Application order is source tuning, eligibility/immunity, positive typed
amplification, target scaling, then existing caps, tick quantization and
stacking. Magnitude uses integer basis-point multiplication rounded down.
Duration scales in seconds before the existing ceiling-to-ticks conversion;
the neutral path preserves the original seconds exactly. DoT scales DPS, keeping
its pulse interval unchanged; each pulse still undergoes ordinary damage-type
mitigation. Stun and Silence have no meaningful magnitude, so only their duration
multiplier applies. Use immunity to reject either control entirely.

Scaling happens once per application, never every tick. Active effects retain
their captured strength and duration if the recipient's scaling changes.
Equal-strength applications still refresh duration, weaker ones do not replace
stronger ones, and different DoT damage channels retain their existing behavior.

All four bosses are immune to Stun and Silence. Their shared catalog default
retains 50% of other harmful status magnitudes and 100% of duration. Ordinary
enemies, summons, NPCs and players retain neutral defaults. NPC archetypes expose
the same separate immunity definition, with no immunities by default.
Halving both DoT strength and duration would reduce total damage to roughly one
quarter, so these are
independent tuning choices. Immunity is checked before control locks or cast
interruption can be applied.

Abilities and gear remain repository-authored. Tuning does not enter client
commands or replay blobs, and no system ordering or wire format changes. This
boss resistance tuning alters combat outcomes and remains within the
prepared, unreleased `2026.10.11` compatibility release. Matching client, worker
and issuance compatibility are required before release. Future balance changes
must follow the normal matching client/worker compatibility policy.
The scaling API rename, allowance for amplification, and neutral NPC catalog
fields preserve all current authored values and outcomes. Authoring a new
weakness remains a gameplay balance change requiring matched client/worker data.

## Validation

`packages/runner_core/test/combat/status_tuning_test.dart` covers every effect
type at 30/60/90 Hz, compound effects, local/default isolation, DoT pulse timing,
resource overrides, scaling, invalid timing and duplicate proc precedence.
Focused activation, mobility, projectile and reactive tests verify payload
propagation; UI tests verify resolved descriptions. Bringer replay tests retain
the matching client/worker Weaken outcome.
`status_scaling_test.dart` verifies all boss immunities, harmful and beneficial
effects, source/target scaling order, duration quantization, DoT cadence and
mitigation, refresh behavior and store lifecycle. It also verifies identical
player/enemy/NPC resistance, amplification and immunity at 30/60/90 Hz, neutral
NPC defaults, negative-value rejection and effect caps. Worker boss replay tests
cover actual Holy, Dark, Water and Acid Bolt hits at 30/60/90 Hz.
