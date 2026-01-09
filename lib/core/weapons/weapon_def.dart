import '../combat/damage_type.dart';
import '../combat/status/status.dart';
import 'weapon_id.dart';

/// Static, data-first definition for a weapon.
///
/// Weapon definitions are queried by [WeaponId] and used by intent writers
/// (e.g. [PlayerMeleeSystem]) to fill combat metadata like damage type and
/// on-hit status profiles.
class WeaponDef {
  const WeaponDef({
    required this.id,
    this.damageType = DamageType.physical,
    this.statusProfileId = StatusProfileId.none,
  });

  final WeaponId id;
  final DamageType damageType;
  final StatusProfileId statusProfileId;
}

