# AGENTS.md - Core Layer

Instructions for AI coding agents working in `packages/runner_core/lib/`.

## Core Responsibility

`packages/runner_core/lib/` is the authoritative gameplay layer. It is pure Dart and owns:

- simulation timing and deterministic progression
- ECS world state, stores, and systems
- commands, events, and snapshots
- combat, movement, AI, collision, projectiles, pickups, and scoring rules
- level definitions, track streaming, spawn logic, and tuning data
- player, gear, loadout, meta, and progression data structures used by the run

If gameplay truth matters, it belongs here.

## Hard Constraints

- never import Flutter
- never import Flame
- never use wall-clock time as gameplay authority
- never move authoritative gameplay rules into `lib/game/` or `lib/ui/`

Core is intentionally portable and testable. Preserve that.

## Key Entry Points And Coordinators

Important files to understand before editing:

- `packages/runner_core/lib/game_core.dart`: central simulation coordinator and system ordering contract
- `packages/runner_core/lib/track_manager.dart`: track streaming and world geometry lifecycle
- `packages/runner_core/lib/spawn_service.dart`: deterministic entity spawning
- `packages/runner_core/lib/snapshot_builder.dart`: ECS-to-snapshot conversion
- `packages/runner_core/lib/levels/`: level IDs, registry, definitions, world constants
- `packages/runner_core/lib/ecs/`: world, stores, queries, spatial helpers, hit logic, systems
- `packages/runner_core/lib/events/` and `packages/runner_core/lib/snapshots/`: output contracts consumed by Game/UI

Treat `GameCore.stepOneTick()` ordering as a behavior contract, not incidental implementation detail.

## Determinism Rules

Core currently depends on deterministic fixed-tick behavior. Preserve these rules:

- commands are tick-stamped and processed in tick order
- RNG must come from the deterministic facilities already used by Core
- timing should be expressed in ticks or derived tick math, not frame-time drift
- equal inputs must continue to produce equal snapshots and events
- tie-breaks must stay stable when iterating entities or resolving conflicts

If you touch a rule that could affect replay stability, document it and add or update tests.

## How The Current Core Is Organized

The current directory layout is broader than the older ECS-only docs. Major areas include:

- gameplay definitions: `abilities/`, `weapons/`, `accessories/`, `spellBook/`, `projectiles/`, `players/`, `enemies/`
- simulation contracts: `commands/`, `events/`, `snapshots/`, `contracts/`
- infrastructure: `ecs/`, `util/`, `collision/`, `camera/`, `navigation/`
- run content and flow: `levels/`, `track/`, `pickups/`, `scoring/`, `progression/`
- player/meta state used during runs: `loadout/`, `meta/`, `stats/`, `tuning/`

When extending behavior, put the change in the domain that owns it instead of growing `game_core.dart` into a dumping ground.

## Working Rules For Systems And Stores

Follow existing ECS patterns:

- put persistent component data in stores under `ecs/stores/`
- put per-tick logic in systems under `ecs/systems/`
- keep systems focused; if behavior spans phases, use explicit ordering in `GameCore`
- prefer typed stores, typed payloads, and catalog lookups over stringly-typed maps
- keep hot paths allocation-light

When changing system order:

- explain why the order matters
- update nearby docs/comments in `game_core.dart`
- verify downstream systems and events that depend on that order

## Commands, Events, And Snapshots

Core is consumed through explicit contracts:

- inputs enter through `commands/`
- transient feedback leaves through `events/`
- renderer/UI state leaves through `snapshots/`

Rules:

- do not sneak render-only data into systems when a snapshot or render contract is the correct boundary
- do not emit backend/UI-specific concepts from Core unless the run actually depends on them
- keep snapshots immutable and renderer-friendly
- keep events transient and side-effect free from the Core perspective

## Adding Or Changing Gameplay Content

When adding a new gameplay item such as an ability, weapon, projectile, enemy, or level, check the full Core surface:

- definitions and catalogs
- tuning or stat resolution
- spawn/setup path
- command handling if player-triggered
- snapshot and event exposure if render/UI need to know about it
- loadout validation if equip/select behavior changes

Do not stop after the first compile error. Finish the content path end to end.

## Testing Expectations

Core changes usually need tests. Target the most relevant slice:

- `test/core/**` for gameplay rules and deterministic behavior
- integration tests when a feature spans multiple systems or run flow

Focus tests on:

- deterministic output for stable seeds and command streams
- ordering-sensitive behavior
- combat/status/resource edge cases
- level/track streaming invariants
- regression coverage for bug fixes

## Common Failure Modes To Avoid

- importing UI or Flame convenience types into Core
- using `DateTime.now()` or unseeded randomness for gameplay
- burying important rules in widgets or render components
- changing snapshot/event shape without updating all consumers
- weakening loadout or stats validation to bypass a content bug

---

For app-level boundaries, see `lib/AGENTS.md`. For render/UI consumers of Core, see `lib/game/AGENTS.md` and `lib/ui/AGENTS.md`.
