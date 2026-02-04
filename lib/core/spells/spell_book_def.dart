import '../abilities/ability_def.dart' show WeaponType;
import '../combat/damage_type.dart';
import '../weapons/weapon_proc.dart';
import '../weapons/weapon_stats.dart';
import 'spell_book_id.dart';

/// Data definition for spell books (spell payload providers).
class SpellBookDef {
  const SpellBookDef({
    required this.id,
    this.weaponType = WeaponType.projectileSpell,
    this.stats = const WeaponStats(),
    this.damageType,
    this.procs = const <WeaponProc>[],
  });

  final SpellBookId id;
  final WeaponType weaponType;
  final WeaponStats stats;
  final DamageType? damageType;
  final List<WeaponProc> procs;
}
