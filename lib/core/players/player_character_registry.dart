library;

import 'characters/eloise.dart';
import 'characters/eloise_wip.dart';
import 'player_character_definition.dart';

class PlayerCharacterRegistry {
  const PlayerCharacterRegistry._();

  static const PlayerCharacterDefinition eloise = eloiseCharacter;
  static const PlayerCharacterDefinition eloiseWip = eloiseWipCharacter;

  static const PlayerCharacterDefinition defaultCharacter = eloise;

  static const List<PlayerCharacterDefinition> all = [eloise, eloiseWip];

  static final Map<PlayerCharacterId, PlayerCharacterDefinition> byId =
      _buildById(all);

  static Map<PlayerCharacterId, PlayerCharacterDefinition> _buildById(
    List<PlayerCharacterDefinition> defs,
  ) {
    assert(() {
      for (final d in defs) {
        d.assertValid();
      }
      return true;
    }());

    final map = <PlayerCharacterId, PlayerCharacterDefinition>{};
    for (final d in defs) {
      final existing = map[d.id];
      if (existing != null) {
        throw StateError('Duplicate PlayerCharacterId ${d.id} in registry');
      }
      map[d.id] = d;
    }
    return map;
  }
}
