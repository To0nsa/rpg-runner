---
description: Create a new ECS component in the Core layer
---

# Create ECS Component Workflow

This workflow guides you through creating a new ECS (Entity-Component-System) component following the SoA + SparseSet architecture.

## Prerequisites

- Understand ECS architecture (see [lib/core/AGENTS.md - ECS Architecture](file:///c:/dev/rpg_runner/lib/core/AGENTS.md))
- Understand component storage patterns (SoA + SparseSet)

## Steps

### 1. Define Component Class

Create the component class in `lib/core/ecs/components/`:

```dart
// lib/core/ecs/components/shield_component.dart
class ShieldComponent {
  double durability;
  double maxDurability;
  double rechargeRate;
  double rechargeCooldown;
  
  ShieldComponent({
    required this.durability,
    required this.maxDurability,
    this.rechargeRate = 10.0,
    this.rechargeCooldown = 0.0,
  });
}
```

**Key points** (from [lib/core/AGENTS.md](file:///c:/dev/rpg_runner/lib/core/AGENTS.md)):
- Components are plain data classes
- Use `final` where possible
- Prefer value types for small structs
- No logic in components (that goes in systems)

### 2. Create Component Store

Create a SparseSet-based store for the component:

```dart
// lib/core/ecs/stores/shield_store.dart
class ShieldStore {
  final _sparse = <int, int>{}; // entity ID -> dense index
  final _dense = <int>[];        // dense array of entity IDs
  final _components = <ShieldComponent>[]; // parallel array of components
  
  void add(int entityId, ShieldComponent component) {
    if (_sparse.containsKey(entityId)) return;
    
    final denseIndex = _dense.length;
    _sparse[entityId] = denseIndex;
    _dense.add(entityId);
    _components.add(component);
  }
  
  void remove(int entityId) {
    if (!_sparse.containsKey(entityId)) return;
    
    final denseIndex = _sparse[entityId]!;
    final lastIndex = _dense.length - 1;
    
    if (denseIndex != lastIndex) {
      // Swap with last element
      final lastEntityId = _dense[lastIndex];
      _dense[denseIndex] = lastEntityId;
      _components[denseIndex] = _components[lastIndex];
      _sparse[lastEntityId] = denseIndex;
    }
    
    _dense.removeLast();
    _components.removeLast();
    _sparse.remove(entityId);
  }
  
  ShieldComponent? get(int entityId) {
    final index = _sparse[entityId];
    return index != null ? _components[index] : null;
  }
  
  bool has(int entityId) => _sparse.containsKey(entityId);
  
  Iterable<int> get entities => _dense;
}
```

### 3. Register Component in World

Add the component store to the ECS World:

```dart
// lib/core/ecs/world.dart
class World {
  // ... existing stores ...
  final shieldStore = ShieldStore();
  
  // Add to query support
  Iterable<int> queryWithShield() {
    return shieldStore.entities;
  }
}
```

### 4. Create System (if needed)

If the component requires logic, create a system:

```dart
// lib/core/ecs/systems/shield_system.dart
class ShieldSystem {
  void execute(World world, double dt) {
    // Query entities with Shield component
    for (final entityId in world.queryWithShield()) {
      final shield = world.shieldStore.get(entityId)!;
      
      // Update shield logic
      if (shield.rechargeCooldown > 0) {
        shield.rechargeCooldown -= dt;
      } else if (shield.durability < shield.maxDurability) {
        shield.durability = min(
          shield.maxDurability,
          shield.durability + shield.rechargeRate * dt
        );
      }
    }
  }
}
```

**Critical rules** (from [lib/core/AGENTS.md](file:///c:/dev/rpg_runner/lib/core/AGENTS.md)):
- ❌ **Never add/remove components mid-iteration**
- ❌ **Never destroy entities mid-iteration**
- ✅ Queue structural changes and apply after iteration

### 5. Add to System Pipeline

Register the system in the game loop execution order:

```dart
// lib/core/game_core.dart
class GameCore {
  final shieldSystem = ShieldSystem();
  
  void tick() {
    // Execute systems in order
    inputSystem.execute(world, tickDt);
    movementSystem.execute(world, tickDt);
    shieldSystem.execute(world, tickDt); // Add here
    combatSystem.execute(world, tickDt);
    // ... other systems
  }
}
```

### 6. Update Snapshot Builder (if renderable)

If the component affects rendering, add it to the snapshot:

```dart
// lib/core/snapshot_builder.dart
class SnapshotBuilder {
  EntitySnapshot buildEntitySnapshot(int entityId) {
    final shield = world.shieldStore.get(entityId);
    
    return EntitySnapshot(
      // ... other fields ...
      shieldDurability: shield?.durability,
      shieldMaxDurability: shield?.maxDurability,
    );
  }
}
```

And update the snapshot data class:

```dart
// lib/core/snapshots/entity_snapshot.dart
class EntitySnapshot {
  // ... existing fields ...
  final double? shieldDurability;
  final double? shieldMaxDurability;
  
  // Update constructor and copyWith
}
```

### 7. Add Tests

Create tests for the component and system:

```dart
// test/core/ecs/systems/shield_system_test.dart
test('shield recharges after cooldown', () {
  final world = World();
  final system = ShieldSystem();
  
  final entityId = world.createEntity();
  world.shieldStore.add(entityId, ShieldComponent(
    durability: 50.0,
    maxDurability: 100.0,
    rechargeRate: 10.0,
    rechargeCooldown: 2.0,
  ));
  
  // Tick during cooldown
  system.execute(world, 1.0);
  expect(world.shieldStore.get(entityId)!.durability, equals(50.0));
  
  // Tick after cooldown
  system.execute(world, 2.0);
  expect(world.shieldStore.get(entityId)!.durability, greaterThan(50.0));
});
```

// turbo
Run tests:
```bash
dart test test/core/ecs/systems/shield_system_test.dart
```

## Common Issues

### Component not updating
- Verify system is registered in the system pipeline
- Check system execution order (dependencies)
- Ensure component is actually added to entities

### Memory leaks
- Ensure components are removed when entities are destroyed
- Check for dangling references in sparse/dense arrays
- Verify swap-and-pop logic in remove()

### Performance issues
- Avoid allocations in hot loops (system execute)
- Use value types for small data (Vec2, not class)
- Profile with many entities (1000+)

## Follow-Up

After creating a component, consider:
- Adding component to entity factory functions
- Creating debug visualization in Game layer
- Adding component serialization for save/load
- Documenting component purpose and usage
