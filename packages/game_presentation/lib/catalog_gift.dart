import 'package:runner_core/players/player_character_definition.dart';

import 'catalog_item.dart';

/// A catalog attachment's display identity, including its explicit skill recipient.
/// This value describes a gift; ownership and supported destinations are server-owned.
class CatalogGift {
  CatalogGift({required this.item, this.characterId}) {
    if (item.kind == 'gear'
        ? characterId != null
        : characterId == null || characterId!.isEmpty) {
      throw const FormatException(
        'Skills require a character; gear is account-wide.',
      );
    }
    if (characterId != null &&
        !PlayerCharacterId.values.any((id) => id.name == characterId)) {
      throw const FormatException('Unknown gift character.');
    }
  }
  final GameCatalogItem item;
  final String? characterId;
  String get key => '${item.key}/${characterId ?? ''}';
  String get label => characterId == null
      ? item.displayName
      : '${item.displayName} · $characterId';
  factory CatalogGift.fromJson(Map<String, dynamic> raw) {
    final allowed = {
      'kind',
      'slot',
      'itemId',
      if (raw['kind'] != 'gear') 'characterId',
    };
    if (raw.keys.any((key) => !allowed.contains(key))) {
      throw const FormatException('Unknown gift field.');
    }
    if (raw['characterId'] != null && raw['characterId'] is! String) {
      throw const FormatException('Invalid gift character.');
    }
    return CatalogGift(
      item: GameCatalogItem.fromJson(raw),
      characterId: raw['characterId'] as String?,
    );
  }
  Map<String, Object> toJson() => {
    ...item.toJson(),
    'characterId': ?characterId,
  };
}
