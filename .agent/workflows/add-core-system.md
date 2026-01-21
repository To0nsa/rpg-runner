---
description: Add a new Core system to the game loop
---

# Add Core System Workflow

This workflow guides you through adding a new system to the Core layer's game loop.

## Prerequisites

- Understand ECS system patterns (see [lib/core/AGENTS.md - System Patterns](file:///c:/dev/rpg_runner/lib/core/AGENTS.md))
- Understand determinism requirements (see [lib/core/AGENTS.md - Determinism](file:///c:/dev/rpg_runner/lib/core/AGENTS.md))

## Steps

### 1. Identify System Dependencies

Before creating a system, identify:

- **Which components** does it read/write?
- **Which other systems** must run before/after it?
- **What events** does it produce?
- **Is it deterministic?** (must be if in Core)

Example: A "StatusEffectSystem" that applies poison/buffs
- Reads: `StatusEffectComponent`, `HealthComponent`
- Writes: `HealthComponent`, `StatusEffectComponent` (duration countdown)
- Produces: `DamageEvent` when status effect ticks
- Dependencies: Run after `CombatSystem`, before `HealthSystem`

### 2. Create System Class

Create the system in `lib/core/` (organize by domain):

```dart
// lib/core/combat/status_effect_system.dart
class StatusEffectSystem {
  final List<GameEvent> _events = [];
  
  List<GameEvent> execute(World world, double dt) {
    _events.clear();
    
    // Query entities with StatusEffect component
    for (final entityId in world.queryWithStatusEffect()) {
      final statusEffect = world.statusEffectStore.get(entityId)!;
      final health = world.healthStore.get(entityId);
      
      if (health == null) continue;
      
      // Update status effect duration
      statusEffect.duration -= dt;
      
      // Apply effect
      if (statusEffect.type == StatusEffectType.poison) {
        final damage = statusEffect.intensity * dt;
        health.current -= damage;
        
        _events.add(DamageEvent(
          entityId: entityId,
          damage: damage,
          source: 'poison',
        ));
      }
      
      // Queue removal if expired (don't remove mid-iteration!)
      if (statusEffect.duration <= 0) {
        world.queueComponentRemoval(entityId, StatusEffectComponent);
      }
    }
    
    return _events;
  }
}
```

**Critical rules** (from [lib/core/AGENTS.md](file:///c:/dev/rpg_runner/lib/core/AGENTS.md)):

- ✅ Use query-based iteration
- ✅ Return events for side effects
- ✅ Queue structural changes (add/remove components)
- ❌ Never add/remove components mid-iteration
- ❌ Never destroy entities mid-iteration
- ❌ Never use wall-clock time or unseeded RNG

### 3. Add to System Pipeline

Integrate the system into the game loop with correct execution order:

```dart
// lib/core/game_core.dart
class GameCore {
  // ... existing systems ...
  final statusEffectSystem = StatusEffectSystem();
  
  void tick() {
    final allEvents = <GameEvent>[];
    
    // Execute systems in dependency order
    allEvents.addAll(inputSystem.execute(world, tickDt));
    allEvents.addAll(movementSystem.execute(world, tickDt));
    allEvents.addAll(combatSystem.execute(world, tickDt));
    allEvents.addAll(statusEffectSystem.execute(world, tickDt)); // Add here
    allEvents.addAll(healthSystem.execute(world, tickDt));
    
    // Apply queued structural changes AFTER all systems
    world.applyQueuedChanges();
    
    // Emit events
    _currentEvents = allEvents;
  }
}
```

**Execution order matters:**
- Input processing → Movement → Combat → Status Effects → Health → Cleanup
- Systems that produce events should run before systems that consume them
- Structural changes (add/remove components) happen AFTER all systems

### 4. Handle Events

If the system produces events, ensure they're consumed properly:

```dart
// lib/game/components/status_effect_view.dart
class StatusEffectView {
  void handleEvents(List<GameEvent> events) {
    for (final event in events) {
      if (event is StatusEffectAppliedEvent) {
        // Spawn VFX for status effect
        spawnStatusVFX(event.entityId, event.effectType);
      }
    }
  }
}
```

Events flow: Core produces → Game consumes (VFX/SFX) → UI displays (notifications)

### 5. Add Determinism Tests

Test that the system behaves deterministically:

```dart
// test/core/combat/status_effect_system_test.dart
test('poison damage is deterministic', () {
  final world1 = World(seed: 12345);
  final world2 = World(seed: 12345);
  final system = StatusEffectSystem();
  
  // Add identical status effects
  final entity1 = world1.createEntity();
  final entity2 = world2.createEntity();
  
  world1.statusEffectStore.add(entity1, StatusEffectComponent(
    type: StatusEffectType.poison,
    intensity: 5.0,
    duration: 10.0,
  ));
  
  world2.statusEffectStore.add(entity2, StatusEffectComponent(
    type: StatusEffectType.poison,
    intensity: 5.0,
    duration: 10.0,
  ));
  
  // Execute system multiple times
  for (int i = 0; i < 100; i++) {
    system.execute(world1, 0.016);
    system.execute(world2, 0.016);
  }
  
  // Verify identical results
  final effect1 = world1.statusEffectStore.get(entity1)!;
  final effect2 = world2.statusEffectStore.get(entity2)!;
  
  expect(effect1.duration, equals(effect2.duration));
});
```

// turbo
Run determinism tests:
```bash
dart test test/core/combat/status_effect_system_test.dart
```

### 6. Add System-Specific Tests

Test the system's core behavior:

```dart
test('status effect expires after duration', () {
  final world = World();
  final system = StatusEffectSystem();
  
  final entityId = world.createEntity();
  world.statusEffectStore.add(entityId, StatusEffectComponent(
    type: StatusEffectType.poison,
    duration: 1.0,
  ));
  
  // Execute for 1 second
  for (int i = 0; i < 60; i++) {
    system.execute(world, 1.0 / 60.0);
  }
  
  // Apply queued removals
  world.applyQueuedChanges();
  
  // Verify effect was removed
  expect(world.statusEffectStore.has(entityId), isFalse);
});
```

### 7. Update Documentation

Document the system's purpose and behavior:

```dart
/// StatusEffectSystem applies over-time effects to entities.
///
/// This system:
/// - Counts down status effect durations
/// - Applies periodic damage/healing based on effect type
/// - Queues expired effects for removal
///
/// Dependencies:
/// - Must run after CombatSystem (which applies status effects)
/// - Must run before HealthSystem (which processes health changes)
///
/// Events produced:
/// - DamageEvent (when poison ticks)
/// - HealEvent (when regen ticks)
class StatusEffectSystem {
  // ...
}
```

## Common Issues

### System not executing
- Verify system is added to the game loop pipeline
- Check that system is constructed and stored as a field
- Ensure events are being collected

### Non-deterministic behavior
- Check for unseeded RNG usage
- Verify no wall-clock timing (`DateTime.now()`)
- Ensure iteration order is consistent

### Structural change crashes
- Never add/remove components during iteration
- Always queue structural changes
- Apply queued changes AFTER all systems execute

### Performance issues
- Avoid allocations in execute() (e.g., new List every frame)
- Reuse event lists (clear, don't create new)
- Profile with many entities (1000+)

## Execution Order Guidelines

Common system execution order:

1. **Input processing** - Convert commands to component updates
2. **AI/Decision** - AI decisions, pathfinding
3. **Movement** - Apply velocity, update positions
4. **Combat** - Process strikes, apply damage
5. **Status effects** - Apply over-time effects
6. **Health** - Process health changes, check for death
7. **Animation** - Select animations based on state
8. **Cleanup** - Remove dead entities, expired components
9. **Apply structural changes** - Add/remove queued components

## Follow-Up

After adding a system, consider:
- Adding debug visualization in Game layer
- Creating system-specific tuning parameters
- Extending system to handle more effect types
- Adding performance benchmarks
- Documenting system interactions in architecture docs
