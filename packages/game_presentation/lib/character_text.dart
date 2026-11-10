import 'package:runner_core/players/player_character_definition.dart';

import 'game_localization.dart';

/// Canonical character names are translated resources, never raw profile IDs.
String characterDisplayName(
  PlayerCharacterId id, {
  required GameLocalizations strings,
}) => switch (id) {
  PlayerCharacterId.eloise ||
  PlayerCharacterId.eloiseWip => strings.characterEloiseName,
  PlayerCharacterId.bountyHunter => strings.characterWillowName,
};
