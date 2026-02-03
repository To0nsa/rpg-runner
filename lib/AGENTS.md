# AGENTS.md

Instructions for AI coding agents working in the `lib/` directory.

## Project Mission

Build a **complete vertical slice** of a production-grade Flutter + Flame runner game with:

**Core Features:**
- **Advanced combat & abilities** - Mobility skills, spells, weapons, and ultimate abilities
- **Character system** - 2 playable characters with unique traits
- **Loadout customization** - Pre-run ability selection menu
- **Content variety** - 2-3 distinct levels, 5-6 enemy types
- **Narrative integration** - Light story elements enhancing engagement

**Technical Excellence:**
- **Deterministic Core** - Enables ghost replay, multiplayer races, and eventual battle royale
- **Firebase backend** - Player data, progression, leaderboards
- **Multiplayer-ready** - Architecture supports online races and competitive modes
- **Monetization pipeline** - IAP and progression hooks
- **Mobile performance** - 60 FPS, clean architecture, scalable design

**Implementation phases** (step-by-step):
1. **Combat & Abilities** - Implement mobility, spells, weapons, ultimates (foundation for customization)
2. **Character & Loadout** - Character selection, loadout menu, customization system
3. **Content Scale** - Additional levels, enemy variety, balancing
4. **Backend & Ghost Run** - Firebase integration, replay system
5. **Narrative & Monetization** - Story elements, IAP pipeline
6. **Multiplayer Foundation** - Online race infrastructure, leaderboards

## Clean Architecture & Modularization Principles

**Senior-level engineering standards apply throughout this codebase.**

### Dependency Management

**Dependency Rule**: Dependencies point inward (UI → Game → Core, never reversed).

- **Core** has ZERO dependencies on Game or UI layers
- **Game** depends on Core contracts (snapshots, events), not Core internals
- **UI** depends on Game controller interfaces, not Core directly
- Use **dependency inversion** when lower layers need to notify upper layers (events, callbacks)

**Example violation to avoid**:
```dart
// ❌ BAD: Core importing Flutter
import 'package:flutter/material.dart'; // in lib/core/**

// ✅ GOOD: Core defines contracts, UI implements
abstract class GameEventListener {
  void onPlayerDeath(PlayerDeathEvent event);
}
```

### SOLID Principles

**Single Responsibility**:
- Each system/component has ONE reason to change
- `MovementSystem` does movement, not collision or damage
- Separate read operations from write operations where it improves clarity

**Open/Closed**:
- Extend behavior via composition, not modification
- Use strategy pattern for abilities (don't hardcode in player class)
- Level definitions extend base contracts without modifying core loading logic

**Liskov Substitution**:
- Subclasses must be substitutable for base types
- All `LevelDefinition` implementations must work with same loading logic
- All `Ability` implementations must work with same activation system

**Interface Segregation**:
- Narrow interfaces over fat ones
- Don't force systems to depend on methods they don't use
- Split large interfaces into focused contracts

**Dependency Inversion**:
- Depend on abstractions, not concrete implementations
- Core defines event interfaces, Game/UI implement handlers
- Use factory patterns for entity creation

### Decision-Making Standards

When approaching any implementation task, follow these standards:

**1. Consider Edge Cases First**
- What happens on different screen sizes, orientations, lifecycle events?
- What if the user backgrounds the app? Rotates the device? Loses network?
- What if this feature scales to 10x the current usage?

**2. Apply DRY Proactively**
- Before writing code, ask: "Does a similar pattern already exist?"
- If a pattern appears twice, extract it immediately into a reusable component
- Create shared utilities/widgets rather than duplicating logic

**3. Prefer Reusable Solutions**
- Create components that can be configured, not specialized one-offs
- Use composition over inheritance for flexibility
- Design for the 80% case but make the 20% possible via parameters

**4. Think About Future Changes**
- Will this pattern need to scale? What if we add 10 more pages/entities?
- Is the API stable enough for others to depend on?
- Are there implicit assumptions that could break later?

**5. Propose Alternatives for Non-Trivial Changes**
- Present 2-3 approaches with tradeoffs for architectural decisions
- Explain why one approach is preferred over others
- Call out risks and mitigation strategies

**6. Validate Before Implementing**
- Check if the solution handles lifecycle events (pause, resume, navigation)
- Consider platform-specific behaviors (iOS vs Android vs Web)
- Think about error states and graceful degradation

### Domain Separation

**Core domains** (organize by feature, not layer):
- **Combat** - Damage calculation, abilities, weapons, status effects
- **Movement** - Physics, velocity, collision response
- **Character** - Character definitions, stats, loadouts
- **Level** - Level data, spawning, progression
- **Inventory/Progression** - Items, unlocks, player progression

**Rules**:
- Keep domains loosely coupled
- Use events for cross-domain communication
- Define clear contracts between domains
- Avoid circular dependencies between domains

### Code Organization

**Module structure**:
```
lib/core/
  combat/          # Combat domain
    abilities/
    weapons/
    damage_system.dart
  character/       # Character domain
    character_definition.dart
    loadout.dart
  ecs/             # ECS framework (infrastructure)
    world.dart
    query.dart
```

**File size limits**:
- Keep files under 300 lines (ideally under 200)
- Extract helpers/utilities when files grow
- Split large systems into sub-systems

**Naming conventions**:
- Systems: `XxxSystem` (e.g., `CombatSystem`)
- Components: `XxxComponent` (e.g., `HealthComponent`)
- Events: `XxxEvent` (e.g., `PlayerDeathEvent`)
- Commands: `XxxCommand` (e.g., `UseAbilityCommand`)

### Testing Strategy

**Test coverage priorities**:
1. **Critical path** - Core gameplay loop, combat, movement (MUST have tests)
2. **Complex logic** - Ability interactions, damage calculations, AI decisions
3. **Edge cases** - Boundary conditions, error states, race conditions
4. **Regression** - Add tests for every bug fix

**Test types**:
- **Unit tests** (`test/core/**`) - Pure logic, systems, components
- **Integration tests** (`test/integration/**`) - Multi-system interactions
- **Widget tests** (`test/ui/**`) - UI behavior, interactions
- **Determinism tests** - Same seed → same results (critical for multiplayer)

**Test quality standards**:
- Tests must be fast (< 1s per test)
- Tests must be isolated (no shared state)
- Use meaningful test names: `test('shield recharges after cooldown expires')`
- Arrange-Act-Assert pattern

### Performance & Scalability

**Core performance rules**:
- **No allocations in hot loops** (per-tick systems)
- **Object pooling** for frequently created/destroyed entities
- **Batch operations** where possible (process arrays, not individual items)
- **Profile before optimizing** - measure, don't guess

**Scalability patterns**:
- Design systems to handle 100+ entities efficiently
- Use spatial partitioning for collision (quadtree/grid)
- Limit entity counts with object pools
- Async loading for heavy operations (assets, save data)

### Code Review Standards

When implementing/reviewing code, ensure:

- ✅ **No layer violations** (Core importing Flutter/Flame)
- ✅ **Single Responsibility** maintained
- ✅ **Tests included** for new behavior
- ✅ **Documentation updated** when contracts change
- ✅ **Performance considered** in hot paths
- ✅ **Error handling** for edge cases
- ✅ **Type safety** (no `dynamic` in gameplay code)
- ✅ **Consistent style** with existing codebase

## Architecture Overview

This project has **three hard layers**:

1. **Core** (`lib/core/`) - Pure Dart simulation: deterministic gameplay, physics, AI, RNG
2. **Game** (`lib/game/`) - Flame rendering: visuals only (sprites, animations, camera, parallax, VFX)
3. **UI** (`lib/ui/`) - Flutter widgets: menus, overlays, navigation, settings

**Hard rules:**
- **Core must not import Flutter or Flame.**
- Flame must not be authoritative for gameplay/collision.
- UI must not modify gameplay state directly; it sends **Commands** to the controller.
- The game must be embeddable: expose a reusable widget/route entrypoint; keep `lib/main.dart` as a dev host/demo only.

**For layer-specific implementation details**, see:
- **[lib/core/AGENTS.md](file:///c:/dev/rpg_runner/lib/core/AGENTS.md)** - ECS patterns, determinism, Core contracts
- **[lib/game/AGENTS.md](file:///c:/dev/rpg_runner/lib/game/AGENTS.md)** - Flame components, rendering, snapshot consumption
- **[lib/ui/AGENTS.md](file:///c:/dev/rpg_runner/lib/ui/AGENTS.md)** - Widget structure, command patterns, UI state

## Level System

**Goal**: Support multiple distinct levels (2-3 for vertical slice) as part of a scalable content pipeline.

**Rules:**
- Levels are **data-first**: define a `LevelId` + `LevelDefinition` (and optional level-specific systems) behind stable Core contracts.
- Level switching resets Core deterministically (seeded RNG, tick counter, entity world) and is driven by a **Command** from UI.
- Spawning/layout rules live in **Core** (authoritative). Render/UI only visualize and present selection/progress.
- Assets are organized and loaded **per level/scene**; avoid global "load everything at boot".
- Levels can have unique enemy compositions, difficulty curves, and environmental mechanics.

## Determinism Contract

- Simulation runs in **fixed ticks** (e.g. 60 Hz). Ticks are the only time authority.
- Inputs are **Commands** queued for a specific tick.
- RNG is seeded and owned by the Core. No wall-clock randomness.
- On app resume, clamp frame dt and **never** try to "catch up" thousands of ticks.

## Data Flow

### Commands → Core → Snapshots/Events

- **Input**: UI and Game layers send `Command` objects to the controller
- **Processing**: Core processes commands during tick execution
- **Output**: Core produces:
  - Immutable `GameStateSnapshot` for render/UI (serializable, renderer-friendly)
  - Transient `GameEvent`s (spawn/despawn/hit/sfx/screenshake/reward, etc.)

### Animation Resolution

Animation selection is resolved in Core via `AnimSystem` using `AnimResolver` + `AnimProfile`, and stored in `AnimStateStore` for snapshot consumption.

Renderer/UI must:
- Treat snapshots as read-only.
- Interpolate visuals using (`prevSnapshot`, `currSnapshot`, `alpha`) but **never simulate**.

## Prefer Existing Solutions

Before building something custom, check if a better solution already exists:

- In this repo (search for an existing pattern/component first)
- In Flame APIs (camera, viewport, parallax, input, effects)
- In well-maintained Dart/Flutter packages

**Rule of thumb:**
- Prefer **Flame** for *render concerns* (camera components, parallax rendering, effects).
- Prefer **UI (Flutter)** for *UI/input widgets* (joystick/buttons/menus/overlays).
- Prefer **Core** for *authoritative gameplay concerns* (movement/physics/collision, ability timing, damage rules), especially when determinism/networking is a goal.

## Implementation Sequencing

Prefer small, testable increments that move toward "multiple levels":

1. Define the Core level contracts (`LevelId`/`LevelDefinition`, load/reset flow).
2. Add level selection entry points (UI + dev menu) that send Commands only.
3. Make level-specific spawning/layout data-driven and deterministic.
4. Ship a second level that differs meaningfully (layout/spawns/tempo) without special-casing.
5. Add/extend Core tests to lock determinism per level (same seed ⇒ same snapshots/events).

## Code Quality Rules

- **Keep the codebase modular and scalable:**
  - Prefer small, cohesive modules with clear boundaries
  - Avoid tight coupling across Core/Game/UI; depend on stable contracts instead
  - Keep public embedding API stable (`lib/runner.dart`), treat internal folders as refactorable
- **Keep responsibilities narrow**: Avoid "god" classes that mix input/sim/render.
- **Prefer explicit data flow**: Commands in, snapshots/events out.
- **Keep Core allocation-light**: Avoid per-tick new Lists/Maps in hot loops.
- **Prefer `final`, `const`, and value types** for small structs (e.g. `Vec2`).
- **No `dynamic` in gameplay code**: Prefer typed payloads; if a temporary map is unavoidable, confine it to UI/debug only.
- **Make side effects explicit**: Core returns events; render/UI consume them.
- **Keep changes consistent** with existing style; avoid renames/reformatting unrelated code.
- **Add/extend tests** when relevant (especially when new behavior is introduced or existing behavior changes):
  - Core behavior: unit tests in `test/core/**` (`dart test`)
  - UI/viewport/widget behavior: widget tests where appropriate
- **Keep docs in sync** with code: update relevant docs whenever behavior, contracts, milestones, or public APIs change.

### UI House Style

When working in `lib/ui/**`, default to the UI “house style” described in `lib/ui/AGENTS.md`:

- Theme-driven components (`ThemeExtension`) with semantic APIs (`variant`, `size`), minimal styling knobs.
- No deprecated Flutter APIs (`WidgetState*`, `Color.withValues`).
- Avoid side-effects in `build` (e.g. `SystemChrome`).

## What an Agent Must Do on Each Task

When asked to implement/fix something:

1. **Identify which layer** it belongs to (Core vs Game vs UI).
2. **Check for an existing solution/pattern** that already fits the goal (repo + Flame + packages).
3. **Propose a minimal plan** (1-3 steps) and acceptance criteria.
4. **Implement** with deterministic rules intact.
5. **Update docs/comments** whenever a change affects behavior, contracts, milestones, or usage:
   - Update `docs/building/plan.md` if architecture rules/contracts change
   - If no existing doc fits, add a short doc under `docs/building/` and link it from `docs/building/plan.md`
   - Update `docs/building/TODO.md` if milestone checklist/follow-ups change
   - Treat `docs/building/v0-implementation-plan.md` as historical unless asked to revise it
   - Update top-of-file docs and public API docs (`lib/runner.dart`, route/widget docs) when embedding/API expectations change
6. **Add/extend relevant tests** when new behavior is introduced or existing behavior changes (especially Core determinism and systems).
7. **Provide:**
   - Files changed + why
   - How to run/verify (build + quick sanity checks)
   - Follow-ups (next incremental step)

## What NOT to Do

- Don't add Flutter/Flame imports into `lib/core/**`.
- Don't use Flame collision callbacks as gameplay truth.
- Don't introduce wall-clock timing in simulation (no `DateTime.now()`, no frame-dt gameplay).
- Don't "just make it work" by mixing UI/render/core responsibilities.

---

**For detailed layer-specific implementation guidance**, see the `AGENTS.md` file in each subdirectory (`core/`, `game/`, `ui/`).
