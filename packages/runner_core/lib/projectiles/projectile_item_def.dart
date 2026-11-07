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
    this.ballistic = false,
    this.gravityScale = 1.0,
    this.damageType = DamageType.physical,
    this.procs = const <WeaponProc>[],
    this.stats = const GearStatBonuses(),
    this.shotCount = 1,
    this.spreadRadians = 0,
    this.damageScaleBp = 10000,
  }) : assert(shotCount > 0),
       assert(spreadRadians >= 0),
       assert(damageScaleBp >= 0);

  final ProjectileId id;
  final WeaponType weaponType;

  final double speedUnitsPerSecond;
  final double lifetimeSeconds;
  final double colliderSizeX;
  final double colliderSizeY;
  final bool ballistic;
  final double gravityScale;

  final DamageType damageType;
  final List<WeaponProc> procs;
  final GearStatBonuses stats;

  /// Weapon-specific fan and total damage budget, before division into pellets.
  final int shotCount;
  final double spreadRadians;
  final int damageScaleBp;
}
