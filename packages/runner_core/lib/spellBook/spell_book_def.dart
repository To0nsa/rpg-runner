import '../abilities/ability_def.dart' show WeaponType;
import '../combat/damage_type.dart';
import '../weapons/weapon_proc.dart';
import '../stats/gear_stat_bonuses.dart';
import 'spell_book_id.dart';

/// Data definition for spell books (gear stats + spell payload context).
class SpellBookDef {
  const SpellBookDef({
    required this.id,
    this.weaponType = WeaponType.spell,
    this.stats = const GearStatBonuses(),
    this.damageType,
    this.procs = const <WeaponProc>[],
  });

  final SpellBookId id;
  final WeaponType weaponType;
  final GearStatBonuses stats;
  final DamageType? damageType;
  final List<WeaponProc> procs;
}
