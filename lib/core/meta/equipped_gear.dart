import '../accessories/accessory_id.dart';
import '../projectiles/projectile_item_id.dart';
import '../spells/spell_book_id.dart';
import '../weapons/weapon_id.dart';

class EquippedGear {
  const EquippedGear({
    required this.mainWeaponId,
    required this.offhandWeaponId,
    required this.throwingWeaponId,
    required this.spellBookId,
    required this.accessoryId,
  });

  final WeaponId mainWeaponId;
  final WeaponId offhandWeaponId;
  final ProjectileItemId throwingWeaponId;
  final SpellBookId spellBookId;
  final AccessoryId accessoryId;

  EquippedGear copyWith({
    WeaponId? mainWeaponId,
    WeaponId? offhandWeaponId,
    ProjectileItemId? throwingWeaponId,
    SpellBookId? spellBookId,
    AccessoryId? accessoryId,
  }) {
    return EquippedGear(
      mainWeaponId: mainWeaponId ?? this.mainWeaponId,
      offhandWeaponId: offhandWeaponId ?? this.offhandWeaponId,
      throwingWeaponId: throwingWeaponId ?? this.throwingWeaponId,
      spellBookId: spellBookId ?? this.spellBookId,
      accessoryId: accessoryId ?? this.accessoryId,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'mainWeaponId': mainWeaponId.name,
      'offhandWeaponId': offhandWeaponId.name,
      'throwingWeaponId': throwingWeaponId.name,
      'spellBookId': spellBookId.name,
      'accessoryId': accessoryId.name,
    };
  }

  static EquippedGear fromJson(
    Map<String, dynamic> json, {
    required EquippedGear fallback,
  }) {
    return EquippedGear(
      mainWeaponId: _enumFromName(
        WeaponId.values,
        json['mainWeaponId'] as String?,
        fallback.mainWeaponId,
      ),
      offhandWeaponId: _enumFromName(
        WeaponId.values,
        json['offhandWeaponId'] as String?,
        fallback.offhandWeaponId,
      ),
      throwingWeaponId: _enumFromName(
        ProjectileItemId.values,
        json['throwingWeaponId'] as String?,
        fallback.throwingWeaponId,
      ),
      spellBookId: _enumFromName(
        SpellBookId.values,
        json['spellBookId'] as String?,
        fallback.spellBookId,
      ),
      accessoryId: _enumFromName(
        AccessoryId.values,
        json['accessoryId'] as String?,
        fallback.accessoryId,
      ),
    );
  }
}

T _enumFromName<T extends Enum>(List<T> values, String? name, T fallback) {
  if (name == null) return fallback;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}
