import '../abilities/ability_catalog.dart';
import '../accessories/accessory_id.dart';
import '../players/character_ability_namespace.dart';
import '../players/character_equipment_policy.dart';
import '../players/player_character_definition.dart';
import '../projectiles/projectile_id.dart';
import '../spellBook/spell_book_id.dart';
import '../weapons/weapon_id.dart';
import 'gear_slot.dart';

/// An existing player catalog identity shared by authored rewards and display
/// adapters. Availability and ownership grants remain backend authority.
final class CatalogItemId {
  const CatalogItemId._(this.kind, this.slot, this.itemId);
  final String kind, slot, itemId;
  String get key => '$kind/$slot/$itemId';

  factory CatalogItemId.fromJson(Map<String, dynamic> json) {
    if (json['kind'] is! String ||
        json['slot'] is! String ||
        json['itemId'] is! String) {
      throw const FormatException('Catalog identities require string fields.');
    }
    final key = '${json['kind']}/${json['slot']}/${json['itemId']}';
    final item = _byKey[key];
    if (item == null) throw FormatException('Unsupported catalog entry: $key');
    return item;
  }

  static final values = List<CatalogItemId>.unmodifiable(_buildValues());
  static final _byKey = {for (final item in values) item.key: item};

  static Iterable<CatalogItemId> _buildValues() sync* {
    for (final slot in GearSlot.values) {
      final ids = switch (slot) {
        GearSlot.mainWeapon || GearSlot.offhandWeapon => WeaponId.values,
        GearSlot.spellBook => SpellBookId.values,
        GearSlot.accessory => AccessoryId.values,
      };
      for (final id in ids) {
        if (PlayerCharacterId.values.any(
          (c) => CharacterEquipmentPolicy.allowsGear(c, slot, id),
        )) {
          yield CatalogItemId._('gear', slot.name, id.name);
        }
      }
    }
    for (final id in playerEquippableProjectileIds) {
      yield CatalogItemId._('projectileSpell', 'projectile', id.name);
    }
    for (final ability in AbilityCatalog.abilities.values) {
      for (final slot in ability.allowedSlots) {
        final item = CatalogItemId._('ability', slot.name, ability.id);
        if (PlayerCharacterId.values.any(
          (c) => item.supportsCharacter(c.name),
        )) {
          yield item;
        }
      }
    }
  }

  bool supportsCharacter(String character) {
    if (kind == 'gear') return true;
    final id = PlayerCharacterId.values
        .where((id) => id.name == character)
        .firstOrNull;
    if (id == null) return false;
    if (kind == 'projectileSpell') {
      return CharacterEquipmentPolicy.allowsProjectile(id, projectileId!);
    }
    return itemId.startsWith('${characterAbilityNamespace(id)}.') ||
        (itemId.startsWith('common.') && !itemId.startsWith('common.enemy_'));
  }

  GearSlot? get gearSlot =>
      GearSlot.values.where((s) => s.name == slot).firstOrNull;
  Object? get gearId => switch (slot) {
    'mainWeapon' || 'offhandWeapon' =>
      WeaponId.values.where((id) => id.name == itemId).firstOrNull,
    'spellBook' =>
      SpellBookId.values.where((id) => id.name == itemId).firstOrNull,
    'accessory' =>
      AccessoryId.values.where((id) => id.name == itemId).firstOrNull,
    _ => null,
  };
  ProjectileId? get projectileId => playerEquippableProjectileIds
      .where((id) => id.name == itemId)
      .firstOrNull;
  Map<String, Object> toJson() => {
    'kind': kind,
    'slot': slot,
    'itemId': itemId,
  };
}

/// Gear unlocks are account-wide; abilities and spells name their recipient.
/// No quantities, invented catalog IDs or automatic equipment changes.
final class CatalogUnlock {
  CatalogUnlock({required this.item, this.characterId}) {
    if (item.kind == 'gear'
        ? characterId != null
        : characterId == null || !item.supportsCharacter(characterId!)) {
      throw const FormatException('Invalid catalog unlock recipient.');
    }
  }
  final CatalogItemId item;
  final String? characterId;
  String get key => '${item.key}/${characterId ?? ''}';

  factory CatalogUnlock.fromJson(Map<String, dynamic> raw) {
    final allowed = {
      'kind',
      'slot',
      'itemId',
      if (raw['kind'] != 'gear') 'characterId',
    };
    if (raw.keys.any((key) => !allowed.contains(key)) ||
        (raw['characterId'] != null && raw['characterId'] is! String)) {
      throw const FormatException('Invalid catalog unlock fields.');
    }
    return CatalogUnlock(
      item: CatalogItemId.fromJson(raw),
      characterId: raw['characterId'] as String?,
    );
  }
  Map<String, Object> toJson() => {
    ...item.toJson(),
    'characterId': ?characterId,
  };
}
