import '../combat/damage_type.dart';
import '../combat/status/status.dart';
import '../projectiles/projectile_id.dart';
import 'ammo_type.dart';
import 'ranged_weapon_id.dart';

/// Static, data-first definition for a ranged weapon.
class RangedWeaponDef {
  const RangedWeaponDef({
    required this.id,
    required this.projectileId,
    required this.damage,
    this.damageType = DamageType.physical,
    this.statusProfileId = StatusProfileId.none,
    this.staminaCost = 0.0,
    required this.ammoType,
    this.ammoCost = 1,
    this.originOffset = 0.0,
    this.cooldownSeconds = 0.25,
    this.ballistic = true,
    this.gravityScale = 1.0,
  });

  final RangedWeaponId id;
  final ProjectileId projectileId;

  final double damage;
  final DamageType damageType;
  final StatusProfileId statusProfileId;

  /// Stamina consumed per shot.
  final double staminaCost;

  /// Ammo category and cost per shot.
  final AmmoType ammoType;
  final int ammoCost;

  /// How far from the caster center to spawn the projectile, along aim dir.
  final double originOffset;

  /// Cooldown after firing (seconds).
  final double cooldownSeconds;

  /// If true, projectile uses physics (gravity + world collision).
  final bool ballistic;

  /// Multiplier applied to global gravity for ballistic projectiles.
  final double gravityScale;
}

