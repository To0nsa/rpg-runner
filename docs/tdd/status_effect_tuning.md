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

Abilities and gear remain repository-authored. Tuning does not enter client
commands or replay blobs, and no system ordering or wire format changes. This
authoring extension preserves current gameplay values and remains within the
prepared `2026.10.11` compatibility release. Future authored balance changes
must follow the normal matching client/worker compatibility policy.

## Validation

`packages/runner_core/test/combat/status_tuning_test.dart` covers every effect
type at 30/60/90 Hz, compound effects, local/default isolation, DoT pulse timing,
resource overrides, scaling, invalid timing and duplicate proc precedence.
Focused activation, mobility, projectile and reactive tests verify payload
propagation; UI tests verify resolved descriptions. Bringer replay tests retain
the matching client/worker Weaken outcome.
