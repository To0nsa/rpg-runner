import 'package:runner_core/meta/catalog_unlock.dart';
import 'package:runner_core/players/player_character_definition.dart';

import 'catalog_item.dart';
import 'game_localization.dart';
import 'character_text.dart';

/// A catalog attachment's display identity, including its explicit skill recipient.
/// This value describes a gift; ownership and supported destinations are server-owned.
class CatalogGift {
  CatalogGift({required this.item, this.characterId})
    : identity = CatalogUnlock(item: item.identity, characterId: characterId);
  final CatalogUnlock identity;
  final GameCatalogItem item;
  final String? characterId;
  String get key => identity.key;
  String label(GameLocalizations strings) => characterId == null
      ? item.displayName(strings)
      : strings.giftCharacterLabel(
          item: item.displayName(strings),
          character: characterDisplayName(
            PlayerCharacterId.values.byName(characterId!),
            strings: strings,
          ),
        );
  factory CatalogGift.fromJson(Map<String, dynamic> raw) {
    final unlock = CatalogUnlock.fromJson(raw);
    return CatalogGift(
      item: GameCatalogItem.fromIdentity(unlock.item),
      characterId: unlock.characterId,
    );
  }
  Map<String, Object> toJson() => identity.toJson();
}
