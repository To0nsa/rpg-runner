import 'package:runner_core/meta/catalog_unlock.dart';
import 'package:runner_core/players/player_character_definition.dart';

import 'catalog_item.dart';
import 'game_localization.dart';
import 'character_text.dart';

/// A catalog attachment's display identity, including its explicit skill recipient.
/// This value describes a gift; ownership and supported destinations are server-owned.
class CatalogGift {
  CatalogGift({required this.item, this.characterId})
    : identity = CatalogUnlock(
        item: item.identity,
        characterId: characterId == 'eloiseWip' ? 'eloise' : characterId,
      );
  final CatalogUnlock identity;
  final GameCatalogItem item;
  final String? characterId;
  // Issued gifts and uncertain Admin retries retain their original wire identity.
  String get key => '${item.identity.key}/${characterId ?? ''}';
  String label(GameLocalizations strings) => characterId == null
      ? item.displayName(strings)
      : strings.giftCharacterLabel(
          item: item.displayName(strings),
          character: characterDisplayName(
            PlayerCharacterId.values.byName(identity.characterId!),
            strings: strings,
          ),
        );
  factory CatalogGift.fromJson(Map<String, dynamic> raw) {
    final unlock = CatalogUnlock.fromJson({
      ...raw,
      if (raw['characterId'] == 'eloiseWip') 'characterId': 'eloise',
    });
    return CatalogGift(
      item: GameCatalogItem.fromIdentity(unlock.item),
      characterId: raw['characterId'] as String?,
    );
  }
  Map<String, Object> toJson() => {
    ...item.identity.toJson(),
    'characterId': ?characterId,
  };
}
