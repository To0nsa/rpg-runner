# Spell List Refactor (Completed)

Date: February 27, 2026
Status: Implemented

## Outcome

Spell ownership is now decoupled from `spellBook` gear.

- Each character has a persistent Spell List.
- Learned projectile spells are selected through `projectileSlotSpellId`.
- Learned spell-slot abilities are selected in `AbilitySlot.spell`.
- `spellBook` is gear only (stats and payload context), not ownership gating.

## Current Behavior

- Swapping spellbooks does not remove or rewrite learned spell selections.
- Any learned projectile spell can be equipped for projectile-slot abilities.
- Any learned spell-slot ability can be equipped in the spell slot.
- Loadout legality remains deterministic and slot/type driven.

## Data Model and Persistence

- Added `SpellList` model in `lib/core/meta/spell_list.dart`:
  - `learnedProjectileSpellIds`
  - `learnedSpellAbilityIds`
- Added per-character storage in `MetaState`:
  - `spellListByCharacter`
  - helpers `spellListFor(...)` and `setSpellListFor(...)`
- `MetaService.createNew()` seeds starter Spell Lists per character from
  character catalog starter fields.
- `MetaService.normalize(...)` normalizes Spell Lists and guarantees a valid
  baseline when data is missing.
- No legacy spellbook-grant migration map is kept.

## Runtime and Validation

- Removed spellbook-grant checks from:
  - `LoadoutValidator`
  - `AbilityActivationSystem`
  - projectile payload resolution helpers
- Spell legality now depends on:
  - slot compatibility
  - weapon/projectile type compatibility
  - selected source validity
  - learned ownership from Spell List (UI/meta normalization path)

## UI/Selection Integration

- Ability picker spell options are filtered by character Spell List.
- Projectile source options are built from:
  - equipped throwing weapon source
  - learned projectile spells from Spell List
- App-state loadout normalization repairs stale spell selections using Spell List
  ownership, not spellbook id.

## Character Namespace Handling

Ability visibility/ownership checks use the character ability namespace derived
from character catalog defaults (for example `eloiseWip` still maps to
`eloise.*` authored abilities).

## Verification

Validated with:

- `dart analyze`
- targeted spell-list refactor suites
- full `flutter test` pass

## Follow-up Work

- Add explicit progression APIs/events for learning new spells
  (`learnProjectileSpell`, `learnSpellAbility`) once progression UX is scoped.
- Keep backend sync contract aligned with `spellListByCharacter` when Firebase
  persistence is introduced.
