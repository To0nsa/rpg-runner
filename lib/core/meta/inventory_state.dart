import '../accessories/accessory_id.dart';
import '../projectiles/projectile_id.dart';
import '../spellBook/spell_book_id.dart';
import '../weapons/weapon_id.dart';

/// Unlocked gear inventory tracked by meta progression.
///
/// Sets are modeled per gear domain so slot/category validation can remain
/// explicit in [MetaService].
class InventoryState {
  const InventoryState({
    required this.unlockedWeaponIds,
    required this.unlockedThrowingWeaponIds,
    required this.unlockedSpellBookIds,
    required this.unlockedAccessoryIds,
  });

  /// Unlocked melee/off-hand weapon IDs.
  final Set<WeaponId> unlockedWeaponIds;

  /// Unlocked throwing-weapon IDs.
  final Set<ProjectileId> unlockedThrowingWeaponIds;

  /// Unlocked spellbook IDs.
  final Set<SpellBookId> unlockedSpellBookIds;

  /// Unlocked accessory IDs.
  final Set<AccessoryId> unlockedAccessoryIds;

  /// Returns a copy with optional unlocked-set replacements.
  InventoryState copyWith({
    Set<WeaponId>? unlockedWeaponIds,
    Set<ProjectileId>? unlockedThrowingWeaponIds,
    Set<SpellBookId>? unlockedSpellBookIds,
    Set<AccessoryId>? unlockedAccessoryIds,
  }) {
    return InventoryState(
      unlockedWeaponIds: unlockedWeaponIds ?? this.unlockedWeaponIds,
      unlockedThrowingWeaponIds:
          unlockedThrowingWeaponIds ?? this.unlockedThrowingWeaponIds,
      unlockedSpellBookIds: unlockedSpellBookIds ?? this.unlockedSpellBookIds,
      unlockedAccessoryIds: unlockedAccessoryIds ?? this.unlockedAccessoryIds,
    );
  }

  /// Serializes unlocked sets as enum-name arrays.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'weapons': unlockedWeaponIds.map((e) => e.name).toList(growable: false),
      'throwingWeapons': unlockedThrowingWeaponIds
          .map((e) => e.name)
          .toList(growable: false),
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
      unlockedThrowingWeaponIds: _readEnumSet(
        json['throwingWeapons'],
        ProjectileId.values,
        fallback.unlockedThrowingWeaponIds,
      ),
      unlockedSpellBookIds: _readEnumSet(
        json['spellBooks'],
        SpellBookId.values,
        fallback.unlockedSpellBookIds,
      ),
      unlockedAccessoryIds: _readEnumSet(
        json['accessories'],
        AccessoryId.values,
        fallback.unlockedAccessoryIds,
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
