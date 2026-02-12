import '../abilities/ability_def.dart' show WeaponType;
import '../combat/damage_type.dart';
import '../projectiles/projectile_id.dart';
import '../weapons/weapon_proc.dart';
import '../stats/gear_stat_bonuses.dart';

/// Unified data definition for projectile slot items (spells + throwing weapons).
class ProjectileItemDef {
  const ProjectileItemDef({
    required this.id,
    required this.weaponType,
    required this.speedUnitsPerSecond,
    required this.lifetimeSeconds,
    required this.colliderSizeX,
    required this.colliderSizeY,
    this.originOffset = 0.0,
    this.ballistic = false,
    this.gravityScale = 1.0,
    this.damageType = DamageType.physical,
    this.procs = const <WeaponProc>[],
    this.stats = const GearStatBonuses(),
  });

  final ProjectileId id;
  final WeaponType weaponType;

  final double speedUnitsPerSecond;
  final double lifetimeSeconds;
  final double colliderSizeX;
  final double colliderSizeY;
  final double originOffset;
  final bool ballistic;
  final double gravityScale;

  final DamageType damageType;
  final List<WeaponProc> procs;
  final GearStatBonuses stats;
}
