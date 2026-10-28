import 'package:flutter/widgets.dart';
import 'package:runner_core/abilities/ability_catalog.dart';
import 'package:runner_core/accessories/accessory_id.dart';
import 'package:runner_core/meta/gear_slot.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/spellBook/spell_book_id.dart';
import 'package:runner_core/weapons/weapon_id.dart';

import 'ability_text.dart';
import 'game_icon.dart';
import 'gear_text.dart';

/// Presentation of an existing catalog entry. This never grants ownership.
/// Server catalog validation remains authoritative for environment availability.
class GameCatalogItem {
  const GameCatalogItem._(this.kind, this.slot, this.itemId);
  final String kind, slot, itemId;
  String get key => '$kind/$slot/$itemId';

  factory GameCatalogItem.fromJson(Map<String, dynamic> json) {
    final kind = json['kind'];
    final slot = json['slot'];
    final id = json['itemId'];
    if (kind is! String || slot is! String || id is! String) {
      throw const FormatException('Invalid catalog entry.');
    }
    final item = GameCatalogItem._(kind, slot, id);
    final supported = switch (kind) {
      'gear' => item.gearSlot != null && item.gearId != null,
      'ability' =>
        (AbilityCatalog.abilities[id]?.allowedSlots.any(
              (value) => value.name == slot,
            ) ??
            false),
      'projectileSpell' => slot == 'projectile' && item.projectileId != null,
      _ => false,
    };
    if (!supported) {
      throw FormatException('Unsupported catalog entry: ${item.key}');
    }
    return item;
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
  String get displayName => switch (kind) {
    'gear' => gearDisplayNameForSlot(gearSlot!, gearId!),
    'ability' => abilityDisplayName(itemId),
    _ => projectileDisplayName(projectileId!),
  };

  /// Uses the same icon renderers and asset keys as the game loadout/store.
  Widget icon({double size = 40}) => switch (kind) {
    'gear' => GameIcon.gear(slot: gearSlot!, id: gearId!, size: size),
    'ability' => GameIcon.ability(abilityId: itemId, size: size),
    _ => GameIcon.projectile(projectileId: projectileId!, size: size),
  };
  Map<String, Object> toJson() => {
    'kind': kind,
    'slot': slot,
    'itemId': itemId,
  };
}
