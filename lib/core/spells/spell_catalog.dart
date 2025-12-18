import '../projectiles/projectile_id.dart';
import 'spell_id.dart';

class ProjectileSpellStats {
  const ProjectileSpellStats({
    required this.manaCost,
    required this.damage,
  });

  final double manaCost;
  final double damage;
}

class SpellDef {
  const SpellDef({
    required this.stats,
    required this.projectileId,
  });

  /// Spell-specific gameplay stats (resource cost, damage, etc).
  final ProjectileSpellStats stats;

  /// Optional projectile mapping. Non-projectile spells have `null`.
  final ProjectileId? projectileId;
}

class SpellCatalog {
  const SpellCatalog();

  SpellDef get(SpellId id) {
    switch (id) {
      case SpellId.iceBolt:
        return const SpellDef(
          stats: ProjectileSpellStats(manaCost: 10.0, damage: 25.0),
          projectileId: ProjectileId.iceBolt,
        );
      case SpellId.lightning:
        return const SpellDef(
          stats: ProjectileSpellStats(manaCost: 10.0, damage: 10.0),
          projectileId: ProjectileId.lightningBolt,
        );
    }
  }
}
