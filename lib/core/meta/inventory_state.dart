import '../accessories/accessory_id.dart';
import '../projectiles/projectile_item_id.dart';
import '../spells/spell_book_id.dart';
import '../weapons/weapon_id.dart';

class InventoryState {
  const InventoryState({
    required this.unlockedWeaponIds,
    required this.unlockedThrowingWeaponIds,
    required this.unlockedSpellBookIds,
    required this.unlockedAccessoryIds,
  });

  final Set<WeaponId> unlockedWeaponIds;
  final Set<ProjectileItemId> unlockedThrowingWeaponIds;
  final Set<SpellBookId> unlockedSpellBookIds;
  final Set<AccessoryId> unlockedAccessoryIds;

  InventoryState copyWith({
    Set<WeaponId>? unlockedWeaponIds,
    Set<ProjectileItemId>? unlockedThrowingWeaponIds,
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
        ProjectileItemId.values,
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
