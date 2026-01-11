library;

import '../player_character_definition.dart';
import '../player_catalog.dart';
import '../player_tuning.dart';

/// Baseline character definition: Éloïse.
///
/// All current "default player" values in v0 are treated as belonging to Éloïse.
const PlayerCharacterDefinition eloiseCharacter = PlayerCharacterDefinition(
  id: PlayerCharacterId.eloise,
  displayName: 'Éloïse',
  catalog: PlayerCatalog(),
  tuning: PlayerTuning(),
);

