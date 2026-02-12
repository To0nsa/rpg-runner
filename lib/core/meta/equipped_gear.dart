import '../accessories/accessory_id.dart';
import '../projectiles/projectile_id.dart';
import '../spells/spell_book_id.dart';
import '../weapons/weapon_id.dart';

/// Canonical equipped gear set for one character profile.
///
/// This object is intentionally complete (all slots required) so consumers
/// never have to handle "missing slot" states during gameplay setup.
class EquippedGear {
  const EquippedGear({
    required this.mainWeaponId,
    required this.offhandWeaponId,
    required this.throwingWeaponId,
    required this.spellBookId,
    required this.accessoryId,
  });

  /// Equipped main-hand weapon.
  final WeaponId mainWeaponId;

  /// Equipped off-hand weapon.
  final WeaponId offhandWeaponId;

  /// Equipped throwing weapon.
  final ProjectileId throwingWeaponId;

  /// Equipped spellbook.
  final SpellBookId spellBookId;

  /// Equipped accessory.
  final AccessoryId accessoryId;

  /// Returns a copy with selected fields replaced.
  EquippedGear copyWith({
    WeaponId? mainWeaponId,
    WeaponId? offhandWeaponId,
    ProjectileId? throwingWeaponId,
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

  /// Serializes equipped IDs using enum names for stable storage.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'mainWeaponId': mainWeaponId.name,
      'offhandWeaponId': offhandWeaponId.name,
      'throwingWeaponId': throwingWeaponId.name,
      'spellBookId': spellBookId.name,
      'accessoryId': accessoryId.name,
    };
  }

  /// Deserializes from persisted JSON with per-field fallback safety.
  ///
  /// Unknown/missing enum names keep the corresponding fallback value.
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
        ProjectileId.values,
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

/// Safe enum lookup helper used by meta deserialization.
T _enumFromName<T extends Enum>(List<T> values, String? name, T fallback) {
  if (name == null) return fallback;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}
