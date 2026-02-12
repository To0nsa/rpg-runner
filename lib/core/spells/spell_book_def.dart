import '../abilities/ability_def.dart' show AbilityKey, WeaponType;
import '../combat/damage_type.dart';
import '../projectiles/projectile_id.dart';
import '../weapons/weapon_proc.dart';
import '../stats/gear_stat_bonuses.dart';
import 'spell_book_id.dart';

/// Data definition for spell books (spell payload providers).
class SpellBookDef {
  const SpellBookDef({
    required this.id,
    this.weaponType = WeaponType.projectileSpell,
    this.projectileSpellIds = const <ProjectileId>[],
    this.spellAbilityIds = const <AbilityKey>[],
    this.stats = const GearStatBonuses(),
    this.damageType,
    this.procs = const <WeaponProc>[],
  });

  final SpellBookId id;
  final WeaponType weaponType;
  final List<ProjectileId> projectileSpellIds;
  final List<AbilityKey> spellAbilityIds;
  final GearStatBonuses stats;
  final DamageType? damageType;
  final List<WeaponProc> procs;

  /// True when this spellbook grants access to the requested projectile spell.
  bool containsProjectileSpell(ProjectileId id) {
    return projectileSpellIds.contains(id);
  }

  /// True when this spellbook grants access to the requested spell-slot spell.
  bool containsSpellAbility(AbilityKey id) {
    return spellAbilityIds.contains(id);
  }
}
