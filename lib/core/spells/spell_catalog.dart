import '../combat/damage_type.dart';
import '../combat/status/status.dart';
import '../projectiles/projectile_id.dart';
import 'spell_id.dart';

/// Combat stats for a projectile-based spell.
class ProjectileSpellStats {
  const ProjectileSpellStats({
    required this.manaCost,
    required this.damage,
    this.damageType = DamageType.physical,
    this.statusProfileId = StatusProfileId.none,
  });

  /// Mana consumed when casting.
  final double manaCost;

  /// Damage dealt on hit.
  final double damage;

  /// Damage type used for resistance/vulnerability rules.
  final DamageType damageType;

  /// Optional status profile applied on hit.
  final StatusProfileId statusProfileId;
}

/// Definition of a spell's properties.
///
/// Separates spell stats (cost, damage) from projectile stats (speed, size)
/// so the same projectile can be used by multiple spells with different values.
class SpellDef {
  const SpellDef({
    required this.stats,
    required this.projectileId,
  });

  /// Combat stats (resource cost, damage).
  final ProjectileSpellStats stats;

  /// Projectile type to spawn, or `null` for non-projectile spells.
  final ProjectileId? projectileId;
}

/// Lookup table for spell definitions by [SpellId].
class SpellCatalog {
  const SpellCatalog();

  /// Returns the definition for the given spell.
  SpellDef get(SpellId id) {
    switch (id) {
      case SpellId.iceBolt:
        return const SpellDef(
          stats: ProjectileSpellStats(
            manaCost: 10.0,
            damage: 15.0,
            damageType: DamageType.ice,
            statusProfileId: StatusProfileId.iceBolt,
          ),
          projectileId: ProjectileId.iceBolt,
        );
      case SpellId.lightning:
        return const SpellDef(
          stats: ProjectileSpellStats(
            manaCost: 10.0,
            damage: 5.0,
            damageType: DamageType.lightning,
          ),
          projectileId: ProjectileId.lightningBolt,
        );
    }
  }
}
