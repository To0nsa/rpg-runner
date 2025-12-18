import 'dart:math';

import '../math/vec2.dart';
import 'projectile_id.dart';

class ProjectileArchetype {
  const ProjectileArchetype({
    required this.speedUnitsPerSecond,
    required this.lifetimeSeconds,
    required this.colliderSize,
  });

  final double speedUnitsPerSecond;
  final double lifetimeSeconds;

  /// Full extents, in world units (virtual pixels).
  final Vec2 colliderSize;
}

class ProjectileCatalog {
  const ProjectileCatalog();

  ProjectileArchetype get(ProjectileId id) {
    switch (id) {
      case ProjectileId.iceBolt:
        return const ProjectileArchetype(
          speedUnitsPerSecond: 1600.0,
          lifetimeSeconds: 1.0,
          colliderSize: Vec2(18.0, 8.0),
        );
      case ProjectileId.lightningBolt:
        return const ProjectileArchetype(
          speedUnitsPerSecond: 900.0,
          lifetimeSeconds: 1.2,
          colliderSize: Vec2(16.0, 8.0),
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
