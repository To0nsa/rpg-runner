# Character Stats V1 Implementation Plan (TDD)

This document translates `docs/gdd/13_character_stats.md` into an implementation plan focused on:

- deterministic Core behavior,
- clean layering (Core authoritative, UI presentation-only),
- scalable architecture for future unlocks, multiplayer/ghost parity, and content growth.

## Implementation status (2026-02-06)

- [x] Phase 1 - Canonical stat domain introduced under `lib/core/stats/`.
- [x] Phase 2 - Gear stat payloads unified through `GearStatBonuses`.
- [x] Phase 3 - Pure resolver introduced and integrated in runtime call sites.
- [x] Phase 4 - Outgoing damage integrates global power + deterministic crit chance.
- [x] Phase 5 - Incoming damage applies global defense before type resistance.
- [x] Phase 6 - Cooldown reduction + move speed integrated in runtime systems.
- [x] Phase 7 - Resource max pools scale at authoritative player spawn.
- [x] Phase 8 - UI presenter aligned to Core stat descriptors and signed deltas.
- [~] Phase 9 - Legacy cleanup in progress; compatibility aliases are intentionally retained during migration.

## Validation status (2026-02-06)

- [x] `flutter test` full suite passes.
- [x] New resolver coverage added in `test/core/stats/character_stats_resolver_test.dart`.
- [x] Damage pipeline regression coverage added in `test/core/damage_system_test.dart` for defense + crit.
- [x] Analyzer checked; remaining warnings are pre-existing and outside this refactor scope.

---

## 0) Scope and constraints

### In scope

- V1 core stat set:
  - Health
  - Mana
  - Stamina
  - Defense (global incoming damage reduction)
  - Power (global outgoing damage increase)
  - Move Speed
  - Cooldown Reduction
  - Crit Chance
- Integrate these stats in authoritative Core gameplay calculations.
- Keep status effects and per-damage-type resistances as layered specialization.
- Align loadout/gear UI with Core-driven stat semantics.

### Out of scope (for this plan)

- New economy/unlock rules.
- Full crit-damage redesign.
- Full status taxonomy redesign.

---

## 1) Current state audit (baseline)

Existing implementation is functional but fragmented across multiple schemas:

- Gear stat definitions:
  - `lib/core/weapons/weapon_stats.dart`
  - `lib/core/accessories/accessory_def.dart` (`AccessoryStats`)
- Runtime damage and mitigation:
  - `lib/core/combat/hit_payload_builder.dart` (power scaling from weapon stats)
  - `lib/core/ecs/systems/damage_system.dart` (damage-type resistance application)
- Runtime resources/cooldowns:
  - `lib/core/abilities/ability_gate.dart`
  - `lib/core/ecs/systems/resource_regen_system.dart`
  - intent stores with raw cooldown/stamina/mana fields
- UI stat presentation:
  - `lib/ui/pages/selectCharacter/gear/gear_stats_presenter.dart`

Observed gaps relative to GDD V1 stat intent:

1. No single canonical stat contract across gear types.
2. Cooldown reduction is defined in accessory stats but not fully authoritative in cooldown start path.
3. Defense (global reduction) is not first-class; only damage-type resistance exists.
4. Crit chance exists as data, but runtime crit pipeline is incomplete.
5. UI stat rows are manually assembled per item type, increasing drift risk.

---

## 2) Architecture options considered

### Option A: Patch in place (minimal refactor)

Add fields and ad-hoc reads where needed in existing systems.

- Pros: fastest short-term delivery.
- Cons: increases coupling and duplication; harder to validate long-term correctness.

### Option B: Unified stat contract + resolver layer (recommended)

Introduce a canonical Core stat model and a pure resolver that aggregates base + gear + status modifiers, then feed runtime systems through that model.

- Pros: clean boundaries, deterministic math centralized, easy testability, scalable for future gear/status content.
- Cons: medium refactor across Core and UI call sites.

### Option C: Full dynamic stat graph engine now

Build a generalized dependency graph for all derived stats and effects.

- Pros: maximal future flexibility.
- Cons: high complexity and overkill for current vertical-slice stage.

### Recommendation

Adopt **Option B** now. It gives production-grade structure without premature complexity.

---

## 3) Target architecture (Option B)

### 3.1 Canonical stat contract in Core

Create a dedicated module:

- `lib/core/stats/character_stat_id.dart`
- `lib/core/stats/gear_stat_bonuses.dart`
- `lib/core/stats/character_stats_resolver.dart`

Current implementation keeps caps and stat math colocated in
`character_stats_resolver.dart` to minimize migration surface.

Design rules:

- Use fixed-point integer units only (no floating-point authority in gameplay math).
- Keep operation order explicit and centralized.
- Keep caps centralized and test-covered.

### 3.2 Unified gear stat contribution model

Create a shared gear stat contribution type and migrate all gear defs to it:

- weapon
- projectile item
- spell book
- accessory

Result: all gear catalog entries speak one stat language.

### 3.3 Runtime consumption by systems

Systems consume resolved stats via dedicated helpers, not ad-hoc field reads.

- Damage pipeline reads `power` and `defense` from resolved stats.
- Cooldown start uses `cooldownReduction` consistently.
- Movement uses resolved move-speed scalar with status modifiers layered on top.
- Crit chance is applied in one deterministic place (hit payload/final damage path).

### 3.4 UI reads stat metadata, not hardcoded labels

UI presenter uses Core-backed stat descriptors/formatting contracts to reduce drift and prepare localization.

---

## 4) Implementation phases

## Phase 0 - Freeze contracts before code changes

Deliverables:

- Freeze numeric units and stacking order in one Core doc comment + tests.
- Freeze caps policy for V1 stats.

Acceptance:

- One authoritative statement for how outgoing/incoming damage and cooldown are computed.
- No unresolved ambiguity on stack order.

## Phase 1 - Introduce canonical stat domain types

Deliverables:

- Add `core/stats/*` contract files.
- Add stat IDs for the V1 set only.
- Add math helpers for bp/fixed-point operations and clamping.

Acceptance:

- Unit tests for math and cap helpers pass.
- No behavior change yet.

## Phase 2 - Migrate gear definitions to unified stat contributions

Deliverables:

- Replace fragmented stat payloads with one shared contribution model.
- Update catalogs and constructors to compile with new schema.
- Keep same effective values as pre-migration.

Acceptance:

- Catalogs load identically from gameplay perspective.
- Existing gear picker still renders equivalent stat values.

## Phase 3 - Build pure resolver (base + gear + modifiers)

Deliverables:

- Add pure resolver API:
  - input: base archetype stats + equipped gear + optional runtime status modifiers
  - output: resolved, capped, display-ready numeric bundle
- Ensure resolver is deterministic and allocation-light.

Acceptance:

- Resolver tests cover additive/scalar/cap interactions and edge cases.
- No system reads gear stat fields directly anymore in touched paths.

## Phase 4 - Integrate outgoing damage (Power + Crit Chance)

Deliverables:

- Route outgoing damage assembly through resolved offensive stats.
- Introduce deterministic crit roll/crit application in one canonical place.
- Keep proc merge order deterministic.

Acceptance:

- Golden tests validate same seed => same crit outcomes.
- Damage diffs match expected power/crit formulas.

## Phase 5 - Integrate incoming damage (Defense + damage-type resistance)

Deliverables:

- Add global defense to damage mitigation path.
- Keep per-damage-type resistance as layered specialization.
- Explicit formula order (for example: base -> defense -> type resistance -> floor/clamp).

Acceptance:

- Damage-system tests validate ordering and caps.
- Existing resistance behavior remains compatible when defense = 0.

## Phase 6 - Integrate movement and cooldown scaling

Deliverables:

- Apply move-speed stat in movement systems through a shared accessor.
- Apply cooldown reduction in all cooldown start call sites.
- Remove duplicated cooldown math snippets.

Acceptance:

- Ability cadence tests pass for multiple CDR values.
- Movement speed scales correctly with and without status effects.

## Phase 7 - Integrate resource max pools (Health/Mana/Stamina)

Deliverables:

- Resolve max-pool bonuses from gear at authoritative loadout resolution points.
- Clamp current resources to new max where required.
- Ensure spawn/init path and loadout change path behave consistently.

Acceptance:

- Spawn/equip tests validate max/current clamping invariants.
- No negative or overflow values in stores.

## Phase 8 - UI alignment and localization prep

Deliverables:

- Replace hardcoded stat-label assembly in `gear_stats_presenter.dart` with shared stat metadata access.
- Keep current UX behavior (hide zero, show signed positive with `+`, compare deltas).
- Add stable localization keys map (even if localization is not yet enabled).

Acceptance:

- Gear picker stats exactly reflect Core stat semantics.
- No CamelCase/raw enum leakage in UI labels.

## Phase 9 - Cleanup and legacy removal

Deliverables:

- Remove obsolete stat fields/paths that duplicate new contract.
- Remove dead adapters and temporary migrations.
- Ensure docs reflect final architecture.

Acceptance:

- No parallel stat systems left.
- `dart analyze` clean on touched areas.

---

## 5) Test strategy (TDD gates)

### Core unit tests (must-have)

- `character_stat_math_test.dart`
- `character_stats_resolver_test.dart`
- `damage_formula_order_test.dart`
- `cooldown_reduction_math_test.dart`
- `resource_pool_clamp_test.dart`

### Integration tests

- Equip change -> resolved stat bundle update -> combat/movement/cooldown outputs updated.
- Determinism replay test: same seed + same command stream => identical snapshots/events after refactor.

### UI tests

- Gear compare rows render signed values and hide zero stats.
- Locked vs equipped vs selected visuals unchanged by stat refactor.

---

## 6) Refactor safety rules

1. Keep migration phases compile-green at each checkpoint.
2. Prefer adapters only for short transition windows; remove them in same milestone.
3. Never leave dual authority for the same stat.
4. Keep formulas in one place; systems call helpers.
5. Avoid per-tick allocations in hot systems.

---

## 7) Risk register and mitigations

### Risk: Formula regressions in combat feel

Mitigation:
- Golden damage tests + before/after combat scenario snapshots.

### Risk: Cooldown behavior drift

Mitigation:
- Dedicated CDR integration tests across all ability slots/groups.

### Risk: UI/Core stat drift

Mitigation:
- Use shared stat metadata contract; avoid duplicated label/math logic in UI.

### Risk: Scope creep into wide stat sheet

Mitigation:
- Enforce V1 stat set as hard boundary in this implementation.

---

## 8) Definition of done

This refactor is done when all are true:

- V1 stat set is authoritative in Core and used by runtime systems.
- Damage, movement, cooldown, and resources use resolved stats consistently.
- UI displays are derived from the same stat contract.
- Determinism tests pass.
- No legacy parallel stat path remains.
- Touched files are analyzer-clean and documented.

---

## 9) Suggested execution order (practical)

1. Phase 0 + Phase 1 + tests.
2. Phase 2 migration with no behavior change.
3. Phase 3 resolver + tests.
4. Phases 4-7 one subsystem at a time with regression tests.
5. Phase 8 UI alignment.
6. Phase 9 cleanup and final determinism sweep.

This order minimizes breakage while allowing a large refactor to remain controlled and production-grade.
