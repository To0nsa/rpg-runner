import '../abilities/ability_def.dart' show AbilityTag;
import '../combat/damage_type.dart';
import '../combat/status/status.dart';
import '../projectiles/projectile_id.dart';
import 'ranged_weapon_id.dart';
import 'weapon_proc.dart';
import 'weapon_stats.dart';

/// Static, data-first definition for a ranged weapon.
class RangedWeaponDef {
  const RangedWeaponDef({
    required this.id,
    // Weapon-owned projectile identity + physics
    required this.projectileId,
    this.originOffset = 0.0,
    this.ballistic = true,
    this.gravityScale = 1.0,
    this.grantedAbilityTags = const {},
    // Payload
    this.damageType = DamageType.physical,
    // Legacy (kept until Phase 5)
    this.statusProfileId = StatusProfileId.none,
    // New Phase 2 fields
    this.procs = const [],
    this.stats = const WeaponStats(),
    // Legacy runtime-owned values (Phase 4 moves these to AbilityDef)
    this.legacyDamage = 0.0,
    this.legacyStaminaCost = 0.0,
    this.legacyCooldownSeconds = 0.25,
  });

  final RangedWeaponId id;

  // Weapon-owned projectile identity + physics
  final ProjectileId projectileId;
  final double originOffset;
  final bool ballistic;
  final double gravityScale;

  /// Capabilities provided by this ranged weapon.
  final Set<AbilityTag> grantedAbilityTags;

  // Payload
  final DamageType damageType;

  /// LEGACY: Single on-hit status profile (Phase 2 keeps it).
  final StatusProfileId statusProfileId;

  // New Phase 2 fields
  final List<WeaponProc> procs;
  final WeaponStats stats;

  // Legacy runtime-owned values (Phase 4 moves these to AbilityDef)
  @Deprecated('Phase 4: AbilityDef owns damage')
  final double legacyDamage;

  @Deprecated('Phase 4: AbilityDef owns cost')
  final double legacyStaminaCost;

  @Deprecated('Phase 4: AbilityDef owns cooldown')
  final double legacyCooldownSeconds;
}
