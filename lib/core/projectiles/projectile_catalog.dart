import 'dart:math';

import 'projectile_id.dart';

class ProjectileArchetype {
  const ProjectileArchetype({
    required this.speedUnitsPerSecond,
    required this.lifetimeSeconds,
    required this.colliderSizeX,
    required this.colliderSizeY,
  });

  final double speedUnitsPerSecond;
  final double lifetimeSeconds;

  /// Full extents, in world units (virtual pixels).
  final double colliderSizeX;
  final double colliderSizeY;
}

class ProjectileCatalog {
  const ProjectileCatalog();

  ProjectileArchetype get(ProjectileId id) {
    switch (id) {
      case ProjectileId.iceBolt:
        return const ProjectileArchetype(
          speedUnitsPerSecond: 1600.0,
          lifetimeSeconds: 1.0,
          colliderSizeX: 18.0,
          colliderSizeY: 8.0,
        );
      case ProjectileId.lightningBolt:
        return const ProjectileArchetype(
          speedUnitsPerSecond: 900.0,
          lifetimeSeconds: 1.2,
          colliderSizeX: 16.0,
          colliderSizeY: 8.0,
        );
    }
  }
}

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

  int lifetimeTicks(ProjectileId id) {
    final seconds = base.get(id).lifetimeSeconds;
    if (seconds <= 0) return 0;
    return max(1, (seconds * tickHz).ceil());
  }
}
