import '../util/tick_math.dart';

import 'projectile_id.dart';

/// Static properties for a projectile type.
///
/// Defines speed, lifetime, and collision bounds. Damage is determined by
/// the spell that spawns the projectile, not the projectile itself.
class ProjectileArchetype {
  const ProjectileArchetype({
    required this.speedUnitsPerSecond,
    required this.lifetimeSeconds,
    required this.colliderSizeX,
    required this.colliderSizeY,
  });

  /// Travel speed in world units per second.
  final double speedUnitsPerSecond;

  /// How long before auto-despawn (seconds).
  final double lifetimeSeconds;

  /// Full width of the collision box (world units).
  final double colliderSizeX;

  /// Full height of the collision box (world units).
  final double colliderSizeY;
}

/// Lookup table for projectile archetypes by [ProjectileId].
///
/// All values are authoring-time constants. For tick-rate-dependent values,
/// use [ProjectileCatalogDerived].
class ProjectileCatalog {
  const ProjectileCatalog();

  /// Returns the archetype for the given projectile type.
  ProjectileArchetype get(ProjectileId id) {
    switch (id) {
      case ProjectileId.iceBolt:
        return const ProjectileArchetype(
          speedUnitsPerSecond: 1000.0,
          lifetimeSeconds: 1.0,
          colliderSizeX: 18.0,
          colliderSizeY: 8.0,
        );
      case ProjectileId.thunderBolt:
        return const ProjectileArchetype(
          speedUnitsPerSecond: 1000.0,
          lifetimeSeconds: 1.2,
          colliderSizeX: 16.0,
          colliderSizeY: 8.0,
        );
      case ProjectileId.fireBolt:
        return const ProjectileArchetype(
          speedUnitsPerSecond: 900.0,
          lifetimeSeconds: 1.3,
          colliderSizeX: 20.0,
          colliderSizeY: 10.0,
        );
      case ProjectileId.arrow:
        return const ProjectileArchetype(
          speedUnitsPerSecond: 1000.0,
          lifetimeSeconds: 1.4,
          colliderSizeX: 18.0,
          colliderSizeY: 6.0,
        );
      case ProjectileId.throwingAxe:
        return const ProjectileArchetype(
          speedUnitsPerSecond: 900.0,
          lifetimeSeconds: 1.6,
          colliderSizeX: 16.0,
          colliderSizeY: 10.0,
        );
    }
  }
}

/// Tick-rate-aware wrapper for [ProjectileCatalog].
///
/// Converts time-based values (seconds) to tick counts for use in systems.
class ProjectileCatalogDerived {
  const ProjectileCatalogDerived._({required this.tickHz, required this.base});

  factory ProjectileCatalogDerived.from(
    ProjectileCatalog base, {
    required int tickHz,
  }) {
    if (tickHz <= 0) {
      throw ArgumentError.value(tickHz, 'tickHz', 'must be > 0');
    }
    return ProjectileCatalogDerived._(tickHz: tickHz, base: base);
  }

  final int tickHz;
  final ProjectileCatalog base;

  /// Converts [lifetimeSeconds] to ticks (rounded up).
  int lifetimeTicks(ProjectileId id) {
    return ticksFromSecondsCeil(base.get(id).lifetimeSeconds, tickHz);
  }
}
