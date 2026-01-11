library;

import 'characters/eloise.dart';
import 'player_character_definition.dart';

class PlayerCharacterRegistry {
  static const PlayerCharacterDefinition eloise = eloiseCharacter;

  static const PlayerCharacterDefinition defaultCharacter = eloise;

  static const List<PlayerCharacterDefinition> all = [eloise];

  static const Map<PlayerCharacterId, PlayerCharacterDefinition> byId = {
    PlayerCharacterId.eloise: eloise,
  };
}

