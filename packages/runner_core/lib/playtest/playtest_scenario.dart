import '../players/player_character_definition.dart';

/// Shared read-only host inputs for the two validated tooling scenarios.
abstract interface class PlaytestScenario {
  int get tickHz;
  PlayerCharacterDefinition get playerCharacter;
}
