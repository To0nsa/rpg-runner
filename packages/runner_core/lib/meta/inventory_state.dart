import '../accessories/accessory_id.dart';
import '../spellBook/spell_book_id.dart';
import '../weapons/weapon_id.dart';

/// Unlocked gear inventory tracked by meta progression.
///
/// Sets are modeled per gear domain so slot/category validation can remain
/// explicit in [MetaService].
class InventoryState {
  const InventoryState({
    required this.unlockedWeaponIds,
    required this.unlockedSpellBookIds,
    required this.unlockedAccessoryIds,
  });

  /// Unlocked melee/off-hand weapon IDs.
  final Set<WeaponId> unlockedWeaponIds;

  /// Unlocked spellbook IDs.
  final Set<SpellBookId> unlockedSpellBookIds;

  /// Unlocked accessory IDs.
  final Set<AccessoryId> unlockedAccessoryIds;

  /// Returns a copy with optional unlocked-set replacements.
  InventoryState copyWith({
    Set<WeaponId>? unlockedWeaponIds,
    Set<SpellBookId>? unlockedSpellBookIds,
    Set<AccessoryId>? unlockedAccessoryIds,
  }) {
    return InventoryState(
      unlockedWeaponIds: unlockedWeaponIds ?? this.unlockedWeaponIds,
      unlockedSpellBookIds: unlockedSpellBookIds ?? this.unlockedSpellBookIds,
      unlockedAccessoryIds: unlockedAccessoryIds ?? this.unlockedAccessoryIds,
    );
  }

  /// Serializes unlocked sets as enum-name arrays.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'weapons': unlockedWeaponIds.map((e) => e.name).toList(growable: false),
      'spellBooks': unlockedSpellBookIds
          .map((e) => e.name)
          .toList(growable: false),
      'accessories': unlockedAccessoryIds
          .map((e) => e.name)
          .toList(growable: false),
    };
  }

  /// Deserializes unlocked sets with per-domain fallback guards.
  static InventoryState fromJson(
    Map<String, dynamic> json, {
    required InventoryState fallback,
  }) {
    return InventoryState(
      unlockedWeaponIds: _readEnumSet(
        json['weapons'],
        WeaponId.values,
        fallback.unlockedWeaponIds,
      ),
      unlockedSpellBookIds: _readEnumSet(
        json['spellBooks'],
        SpellBookId.values,
        fallback.unlockedSpellBookIds,
      ),
      unlockedAccessoryIds: _readAccessoryIdSet(
        json['accessories'],
        fallback: fallback.unlockedAccessoryIds,
      ),
    );
  }
}

/// Reads a set of enum names from dynamic JSON payload.
///
/// Returns [fallback] when the payload is absent/invalid, or when parsing
/// yields an empty set (to avoid clearing inventory on malformed data).
Set<T> _readEnumSet<T extends Enum>(
  Object? raw,
  List<T> values,
  Set<T> fallback,
) {
  if (raw is! List) return fallback;
  final result = <T>{};
  for (final item in raw) {
    if (item is! String) continue;
    for (final value in values) {
      if (value.name == item) {
        result.add(value);
        break;
      }
    }
  }
  return result.isEmpty ? fallback : result;
}

Set<AccessoryId> _readAccessoryIdSet(
  Object? raw, {
  required Set<AccessoryId> fallback,
}) {
  if (raw is! List) return fallback;
  final migrated = <String>[];
  for (final item in raw) {
    if (item is! String) continue;
    migrated.add(item == 'ironBracers' ? 'ironBoots' : item);
  }
  return _readEnumSet(migrated, AccessoryId.values, fallback);
}
