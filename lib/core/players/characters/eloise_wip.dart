library;

import 'eloise.dart';
import '../player_character_definition.dart';

const PlayerCharacterDefinition eloiseWipCharacter = PlayerCharacterDefinition(
  id: PlayerCharacterId.eloiseWip,
  displayName: 'Éloïse (WIP)',
  renderAnim: eloiseRenderAnim,
  catalog: eloiseCatalog,
  tuning: eloiseTuning,
);
