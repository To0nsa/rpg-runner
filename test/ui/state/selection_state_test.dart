import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:rpg_runner/core/levels/level_id.dart';
import 'package:rpg_runner/core/players/player_character_definition.dart';
import 'package:rpg_runner/ui/state/selection_state.dart';

void main() {
  group('SelectionState per-character loadouts', () {
    test('fromJson migrates legacy loadout to all character entries', () {
      final state = SelectionState.fromJson(<String, dynamic>{
        'levelId': LevelId.field.name,
        'runType': RunType.practice.name,
        'characterId': PlayerCharacterId.eloiseWip.name,
        'loadout': <String, Object?>{'abilityJumpId': 'migration.jump'},
        'buildName': 'Legacy',
      });

      expect(state.selectedCharacterId, PlayerCharacterId.eloiseWip);
      for (final id in PlayerCharacterId.values) {
        expect(state.loadoutFor(id).abilityJumpId, 'migration.jump');
      }
    });

    test('fromJson reads loadoutsByCharacter and fills missing entries', () {
      final state = SelectionState.fromJson(<String, dynamic>{
        'characterId': PlayerCharacterId.eloise.name,
        'loadoutsByCharacter': <String, Object?>{
          PlayerCharacterId.eloise.name: <String, Object?>{
            'abilityJumpId': 'eloise.custom_jump',
          },
        },
      });

      expect(
        state.loadoutFor(PlayerCharacterId.eloise).abilityJumpId,
        'eloise.custom_jump',
      );
      expect(
        state.loadoutFor(PlayerCharacterId.eloiseWip).abilityJumpId,
        const EquippedLoadoutDef().abilityJumpId,
      );
    });

    test('toJson writes loadoutsByCharacter only', () {
      final state = SelectionState.defaults.withLoadoutFor(
        PlayerCharacterId.eloise,
        const EquippedLoadoutDef(abilityJumpId: 'eloise.custom_jump'),
      );

      final json = state.toJson();
      expect(json.containsKey('loadoutsByCharacter'), isTrue);
      expect(json.containsKey('loadout'), isFalse);
      final loadouts = json['loadoutsByCharacter']! as Map<String, Object?>;
      final eloise =
          loadouts[PlayerCharacterId.eloise.name]! as Map<String, Object?>;
      expect(eloise['abilityJumpId'], 'eloise.custom_jump');
    });
  });
}
