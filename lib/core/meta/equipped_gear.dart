import '../accessories/accessory_id.dart';
import '../spellBook/spell_book_id.dart';
import '../weapons/weapon_id.dart';

/// Canonical equipped gear set for one character profile.
///
/// This object is intentionally complete (all slots required) so consumers
/// never have to handle "missing slot" states during gameplay setup.
class EquippedGear {
  const EquippedGear({
    required this.mainWeaponId,
    required this.offhandWeaponId,
    required this.spellBookId,
    required this.accessoryId,
  });

  /// Equipped main-hand weapon.
  final WeaponId mainWeaponId;

  /// Equipped off-hand weapon.
  final WeaponId offhandWeaponId;

  /// Equipped spellbook.
  final SpellBookId spellBookId;

  /// Equipped accessory.
  final AccessoryId accessoryId;

  /// Returns a copy with selected fields replaced.
  EquippedGear copyWith({
    WeaponId? mainWeaponId,
    WeaponId? offhandWeaponId,
    SpellBookId? spellBookId,
    AccessoryId? accessoryId,
  }) {
    return EquippedGear(
      mainWeaponId: mainWeaponId ?? this.mainWeaponId,
      offhandWeaponId: offhandWeaponId ?? this.offhandWeaponId,
      spellBookId: spellBookId ?? this.spellBookId,
      accessoryId: accessoryId ?? this.accessoryId,
    );
  }

  /// Serializes equipped IDs using enum names for stable storage.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'mainWeaponId': mainWeaponId.name,
      'offhandWeaponId': offhandWeaponId.name,
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
      spellBookId: _enumFromName(
        SpellBookId.values,
        json['spellBookId'] as String?,
        fallback.spellBookId,
      ),
      accessoryId: _accessoryIdFromName(
        json['accessoryId'] as String?,
        fallback: fallback.accessoryId,
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

AccessoryId _accessoryIdFromName(
  String? name, {
  required AccessoryId fallback,
}) {
  if (name == null) return fallback;
  if (name == 'ironBracers') {
    // Save-data migration: old runtime ID renamed to ironBoots.
    return AccessoryId.ironBoots;
  }
  return _enumFromName(AccessoryId.values, name, fallback);
}
