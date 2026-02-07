import '../abilities/ability_def.dart' show WeaponType;
import '../combat/damage_type.dart';
import '../projectiles/projectile_item_id.dart';
import '../weapons/weapon_proc.dart';
import '../stats/gear_stat_bonuses.dart';
import 'spell_book_id.dart';

/// Data definition for spell books (spell payload providers).
class SpellBookDef {
  const SpellBookDef({
    required this.id,
    required this.displayName,
    required this.description,
    this.weaponType = WeaponType.projectileSpell,
    this.projectileSpellIds = const <ProjectileItemId>[],
    this.stats = const GearStatBonuses(),
    this.damageType,
    this.procs = const <WeaponProc>[],
  });

  final SpellBookId id;
  final String displayName;
  final String description;
  final WeaponType weaponType;
  final List<ProjectileItemId> projectileSpellIds;
  final GearStatBonuses stats;
  final DamageType? damageType;
  final List<WeaponProc> procs;

  /// True when this spellbook grants access to the requested projectile spell.
  bool containsProjectileSpell(ProjectileItemId id) {
    return projectileSpellIds.contains(id);
  }
}
