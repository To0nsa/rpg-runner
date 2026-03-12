class DeathState {
  DeathState({
    required this.phase,
    required this.deathStartTick,
    required this.despawnTick,
    required this.maxFallDespawnTick,
  });

  DeathPhase phase;
  int deathStartTick;
  int despawnTick;
  int maxFallDespawnTick;
}

enum DeathPhase {
  fallingUntilGround,
  deathAnim,
}

class DeathStateComponent {
  final Map<int, DeathState> _data = {};

  bool has(int entity) => _data.containsKey(entity);
  int indexOf(int entity) => entity;
  int? tryIndexOf(int entity) => _data.containsKey(entity) ? entity : null;

  void add(int entity, DeathState state) {
    _data[entity] = state;
  }

  DeathPhase get phase => throw UnimplementedError('Use entity index');
  // This component structure seems to be property-based in the system.
  // Let's look at how other components are used in world.dart or other systems.
}

// Based on the system usage, it expects:
// deathState.phase[di]
// deathState.deathStartTick[di]
// deathState.despawnTick[di]
// deathState.maxFallDespawnTick[di]
// This suggests deathState is a component with multiple arrays or maps.

class DeathStateDef {
  const DeathStateDef({
    required this.phase,
    required this.deathStartTick,
    required this.despawnTick,
    required this.maxFallDespawnTick,
  });

  final DeathPhase phase;
  final int deathStartTick;
  final int despawnTick;
  final int maxFallDespawnTick;
}