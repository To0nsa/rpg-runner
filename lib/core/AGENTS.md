# AGENTS.md - Core Layer

Instructions for AI coding agents working in the **Core** simulation layer (`lib/core/`).

## Core Responsibility

The Core layer is a **pure Dart simulation engine**. It is the single source of truth for all gameplay logic, physics, AI, and state management.

**Hard rule:** Core must **never import Flutter or Flame**. This ensures determinism, testability, and future network-readiness.

## ECS Architecture

### Entity Storage

Core uses **SoA (Structure of Arrays) + SparseSet** per component type.

**Entity ID rules:**
- Entity IDs are **monotonic** and **never reused**
- IDs increment sequentially as entities are spawned
- Destroyed entity IDs are not recycled

### Component Iteration

**Query-based iteration:**
- Systems iterate via queries (e.g., `world.query<Position, Velocity>()`)
- Never directly access sparse/dense arrays unless implementing a new storage mechanism

**Structural change rules:**
- **Do not add/remove components or destroy entities mid-iteration**
- Queue structural changes and apply them after system execution
- Use deferred operations or command buffers for mid-tick mutations
- Do not keep references to dense arrays across ticks

### System Patterns

Systems should follow these patterns:

```dart
class ExampleSystem {
  void execute(World world, double dt) {
    // Query entities with required components
    final entities = world.query<ComponentA, ComponentB>();
    
    // Process entities (read-only iteration)
    for (final entity in entities) {
      final a = world.get<ComponentA>(entity);
      final b = world.get<ComponentB>(entity);
      
      // Update components in-place (safe)
      a.value += b.delta;
      
      // NEVER: world.destroyEntity(entity) here!
      // NEVER: world.addComponent(entity, newComponent) here!
    }
    
    // Apply structural changes after iteration
    // (queued during iteration, applied here)
  }
}
```

## Determinism Requirements

### Fixed Tick Simulation

- Simulation runs at a **fixed tick rate** (e.g., 60 Hz / 16.67ms per tick)
- Ticks are the **only time authority** in Core
- Use tick count for all timing logic, not wall-clock time

### Seeded RNG

- RNG is owned by Core and **must be seeded**
- Use a seeded `Random` instance stored in the game state
- Never use `Random()` without a seed in Core code
- Never use `DateTime.now()` or any wall-clock source for randomness

### Command Queueing

- Inputs are represented as **Command objects**
- Commands are queued for a specific tick
- Commands are processed deterministically during tick execution
- Example: `JumpCommand(tickNumber: 1234, playerId: 0)`

### Resumption Behavior

- On app resume, **clamp the frame delta-time**
- **Never** try to "catch up" thousands of ticks after backgrounding
- Skip or fast-forward deterministically if catch-up is needed

## Core Outputs

### GameStateSnapshot

- **Immutable** representation of the current game state
- Serializable and renderer-friendly
- Contains all data needed for rendering (positions, animations, health, etc.)
- Includes a `runId` field for session/replay/ghost metadata
- Produced once per tick
- Consumer layers (Game/UI) must treat this as **read-only**

### GameEvents

- **Transient** events emitted during tick execution
- Examples: spawn, despawn, hit, sfx, screenshake, reward, level-up
- Events have a short lifetime (typically one frame)
- Consumed by Game layer for VFX, sound effects, camera shake, etc.
- Not part of the persistent state

### Animation State

- Animation selection is resolved **in Core** via `AnimSystem`
- Uses `AnimResolver` + `AnimProfile` to determine which animation to play
- Stored in `AnimStateStore` for snapshot consumption
- Game layer reads animation state from snapshots and updates Flame sprite components accordingly

## Data Flow Pattern

**Commands → Core → Snapshots + Events**

1. **Input**: Game and UI layers create `Command` objects
2. **Queue**: Commands are queued for the next tick
3. **Process**: Core executes the tick, processing all queued commands
4. **Output**: Core produces:
   - One `GameStateSnapshot` (read by Game/UI for rendering)
   - Zero or more `GameEvent`s (consumed by Game for VFX/SFX)

## Performance Considerations

### Allocation-Light Hot Loops

- Avoid creating new `List`, `Map`, or objects in per-tick hot loops
- Prefer reusing buffers or pre-allocated pools
- Profile and optimize allocation-heavy systems

### Value Types

- Prefer **value types** for small structs (e.g., `Vec2`, `Rect`, `Color`)
- Use `final` and `const` where possible to prevent accidental mutations
- Avoid boxing primitives unnecessarily

### No Dynamic Types

- **Never use `dynamic`** in Core gameplay code
- Prefer strongly-typed payloads for all data structures
- If a temporary map is unavoidable, confine it to debug/tooling only

## Testing Core

### Unit Tests

- Core behavior should be covered by **unit tests** in `test/core/**`
- Run tests with: `dart test`
- Focus on:
  - Determinism (same seed → same results)
  - System behavior (physics, collision, AI)
  - Command processing
  - Edge cases (entity destruction, spawn limits, etc.)

### Determinism Tests

Example determinism test pattern:

```dart
test('same seed produces same results', () {
  final game1 = GameCore(seed: 12345);
  final game2 = GameCore(seed: 12345);
  
  for (int i = 0; i < 100; i++) {
    game1.tick();
    game2.tick();
    
    expect(game1.snapshot, equals(game2.snapshot));
  }
});
```

## Common Core Subsystems

- **ECS** (`lib/core/ecs/`) - Entity-Component-System framework
- **Commands** (`lib/core/commands/`) - Input command definitions
- **Snapshots** (`lib/core/snapshots/`) - Snapshot data structures
- **Events** (`lib/core/events/`) - Game event definitions
- **Collision** (`lib/core/collision/`) - Authoritative collision detection
- **Combat** (`lib/core/combat/`) - Damage, health, abilities
- **Levels** (`lib/core/levels/`) - Level definitions and loading
- **Navigation** (`lib/core/navigation/`) - Pathfinding, AI movement
- **Track** (`lib/core/track/`) - Track/lane system
- **Tuning** (`lib/core/tuning/`) - Gameplay constants and balance values
- **Util** (`lib/core/util/`) - Pure Dart utilities (math, geometry, RNG helpers)

## What NOT to Do in Core

- ❌ **Do not import Flutter** (`package:flutter/...`)
- ❌ **Do not import Flame** (`package:flame/...`)
- ❌ **Do not use wall-clock time** (`DateTime.now()`, `Stopwatch`, frame delta-time)
- ❌ **Do not mutate structure mid-iteration** (adding/removing components, destroying entities)
- ❌ **Do not make rendering decisions** (that's Game layer's job)
- ❌ **Do not read user input directly** (use Commands instead)

---

**For cross-layer architecture and general rules**, see [lib/AGENTS.md](file:///c:/dev/rpg_runner/lib/AGENTS.md).
