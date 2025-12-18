import 'dart:math';

import '../math/vec2.dart';
import 'spell_id.dart';

class ProjectileSpellStats {
  const ProjectileSpellStats({
    required this.manaCost,
    required this.damage,
    required this.speedUnitsPerSecond,
    required this.lifetimeSeconds,
    required this.colliderSize,
  });

  final double manaCost;
  final double damage;
  final double speedUnitsPerSecond;
  final double lifetimeSeconds;

  /// Full extents, in world units (virtual pixels).
  final Vec2 colliderSize;
}

class SpellDef {
  const SpellDef.projectile({required this.projectile});

  final ProjectileSpellStats projectile;
}

class SpellCatalog {
  const SpellCatalog();

  SpellDef get(SpellId id) {
    switch (id) {
      case SpellId.iceBolt:
        return const SpellDef.projectile(
          projectile: ProjectileSpellStats(
            manaCost: 10.0,
            damage: 25.0,
            speedUnitsPerSecond: 1600.0,
            lifetimeSeconds: 1.0,
            colliderSize: Vec2(18.0, 8.0),
          ),
        );
      case SpellId.lightning:
        return const SpellDef.projectile(
          projectile: ProjectileSpellStats(
            manaCost: 10.0,
            damage: 10.0,
            speedUnitsPerSecond: 900.0,
            lifetimeSeconds: 1.2,
            colliderSize: Vec2(16.0, 8.0),
          ),
        );
    }
  }
}

class SpellCatalogDerived {
  const SpellCatalogDerived._({required this.tickHz, required this.base});

  factory SpellCatalogDerived.from(SpellCatalog base, {required int tickHz}) {
    if (tickHz <= 0) {
      throw ArgumentError.value(tickHz, 'tickHz', 'must be > 0');
    }
    return SpellCatalogDerived._(tickHz: tickHz, base: base);
  }

  final int tickHz;
  final SpellCatalog base;

  int lifetimeTicks(SpellId id) {
    final seconds = base.get(id).projectile.lifetimeSeconds;
    if (seconds <= 0) return 0;
    return max(1, (seconds * tickHz).ceil());
  }
}
