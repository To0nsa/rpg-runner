import '../util/tick_math.dart';
import '../projectiles/projectile_id.dart';
import 'ranged_weapon_def.dart';
import 'ranged_weapon_id.dart';

/// Lookup table for ranged weapon definitions.
class RangedWeaponCatalog {
  const RangedWeaponCatalog();

  RangedWeaponDef get(RangedWeaponId id) {
    switch (id) {
      case RangedWeaponId.throwingAxe:
        return const RangedWeaponDef(
          id: RangedWeaponId.throwingAxe,
          projectileId: ProjectileId.throwingAxe,
          damage: 18.0,
          staminaCost: 8.0,
          originOffset: 8.0,
          cooldownSeconds: 0.40,
          ballistic: true,
          gravityScale: 1.0,
        );
      case RangedWeaponId.throwingKnife:
        return const RangedWeaponDef(
          id: RangedWeaponId.throwingKnife,
          projectileId: ProjectileId.throwingKnife,
          damage: 10.0,
          staminaCost: 5.0,
          originOffset: 6.0,
          cooldownSeconds: 0.30,
          ballistic: true,
          gravityScale: 0.9,
        );
    }
  }
}

/// Tick-rate-aware wrapper for [RangedWeaponCatalog].
class RangedWeaponCatalogDerived {
  const RangedWeaponCatalogDerived._({required this.tickHz, required this.base});

  factory RangedWeaponCatalogDerived.from(
    RangedWeaponCatalog base, {
    required int tickHz,
  }) {
    if (tickHz <= 0) {
      throw ArgumentError.value(tickHz, 'tickHz', 'must be > 0');
    }
    return RangedWeaponCatalogDerived._(tickHz: tickHz, base: base);
  }

  final int tickHz;
  final RangedWeaponCatalog base;

  int cooldownTicks(RangedWeaponId id) {
    return ticksFromSecondsCeil(base.get(id).cooldownSeconds, tickHz);
  }
}
