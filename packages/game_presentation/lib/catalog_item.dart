import 'package:flutter/widgets.dart';
import 'package:runner_core/meta/catalog_unlock.dart';
import 'package:runner_core/meta/gear_slot.dart';
import 'package:runner_core/projectiles/projectile_id.dart';

import 'ability_text.dart';
import 'game_icon.dart';
import 'gear_text.dart';
import 'game_localization.dart';

/// Shared names and icons for validated Core catalog identities. This never
/// grants ownership; the backend remains authoritative for unlocks.
class GameCatalogItem {
  const GameCatalogItem.fromIdentity(this.identity);
  factory GameCatalogItem.fromJson(Map<String, dynamic> json) =>
      GameCatalogItem.fromIdentity(CatalogItemId.fromJson(json));

  final CatalogItemId identity;
  static final values = List<GameCatalogItem>.unmodifiable(
    CatalogItemId.values.map(GameCatalogItem.fromIdentity),
  );
  String get kind => identity.kind;
  String get slot => identity.slot;
  String get itemId => identity.itemId;
  String get key => identity.key;
  GearSlot? get gearSlot => identity.gearSlot;
  Object? get gearId => identity.gearId;
  ProjectileId? get projectileId => identity.projectileId;
  bool supportsCharacter(String character) =>
      identity.supportsCharacter(character);
  String displayName(GameLocalizations strings) => switch (kind) {
    'gear' => gearDisplayNameForSlot(gearSlot!, gearId!, strings: strings),
    'ability' => abilityDisplayName(itemId, strings: strings),
    _ => projectileDisplayName(projectileId!, strings: strings),
  };

  /// Uses the same icon renderers and asset keys as the game loadout/store.
  Widget icon({double size = 40}) => switch (kind) {
    'gear' => GameIcon.gear(slot: gearSlot!, id: gearId!, size: size),
    'ability' => GameIcon.ability(abilityId: itemId, size: size),
    _ => GameIcon.projectile(projectileId: projectileId!, size: size),
  };
  Map<String, Object> toJson() => identity.toJson();
}
