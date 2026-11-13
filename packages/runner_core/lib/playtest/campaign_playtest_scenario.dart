import '../campaign/campaign_mission_definition.dart';
import '../ecs/stores/combat/equipped_loadout_store.dart';
import '../players/player_character_definition.dart';
import 'playtest_scenario.dart';

/// Frozen authored mission. It carries no ticket, ownership or reward authority.
final class CampaignPlaytestScenario implements PlaytestScenario {
  CampaignPlaytestScenario({
    required this.mission,
    required this.playerCharacter,
    this.equippedLoadout,
    this.seed = 4401,
    this.tickHz = 60,
  }) {
    if (seed <= 0 || tickHz <= 0) {
      throw ArgumentError('Positive seed and tick rate required.');
    }
  }
  final CampaignMissionDefinition mission;
  @override
  final PlayerCharacterDefinition playerCharacter;

  /// Null uses the character catalog's starter equipment and enabled slots.
  /// An explicit override is preserved exactly, including disabled slots.
  final EquippedLoadoutDef? equippedLoadout;
  final int seed;
  @override
  final int tickHz;
}
