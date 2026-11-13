import 'package:runner_core/players/player_character_definition.dart';

import '../../state/ownership/progression_state.dart';

/// Opens Equipment at a builder's browsing context without selecting or editing
/// that character/build. Invalid build indices fall back to the saved selection.
class TownEquipmentArgs {
  const TownEquipmentArgs({
    required this.characterId,
    required this.slot,
    this.buildIndex,
  });

  final PlayerCharacterId characterId;
  final StoreSlot slot;
  final int? buildIndex;
}
