import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/accessories/accessory_id.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:rpg_runner/ui/state/ownership/selection_state.dart';

void main() {
  group('SelectionState per-character loadouts', () {
    test('defaults seed character-authored loadout masks', () {
      for (final id in PlayerCharacterId.values) {
        final expectedMask = PlayerCharacterRegistry.resolve(
          id,
        ).catalog.loadoutSlotMask;
        expect(SelectionState.defaults.loadoutFor(id).mask, expectedMask);
      }
    });

    test('fromJson without current schema falls back to defaults', () {
      final state = SelectionState.fromJson(<String, dynamic>{
        'levelId': LevelId.field.name,
        'runType': RunMode.practice.name,
        'characterId': PlayerCharacterId.eloiseWip.name,
        'loadout': <String, Object?>{'abilityJumpId': 'migration.jump'},
        'buildName': 'Legacy',
      });

      expect(state.selectedLevelId, SelectionState.defaults.selectedLevelId);
      expect(state.selectedRunMode, SelectionState.defaults.selectedRunMode);
      expect(
        state.selectedCharacterId,
        SelectionState.defaults.selectedCharacterId,
      );
      expect(state.buildName, SelectionState.defaults.buildName);
    });

    test('fromJson with mismatched schema falls back to defaults', () {
      final state = SelectionState.fromJson(<String, dynamic>{
        'schemaVersion': SelectionState.schemaVersion + 1,
        'loadoutsByCharacter': <String, Object?>{},
      });

      expect(state.selectedLevelId, SelectionState.defaults.selectedLevelId);
      expect(state.selectedRunMode, SelectionState.defaults.selectedRunMode);
      expect(
        state.selectedCharacterId,
        SelectionState.defaults.selectedCharacterId,
      );
      expect(state.buildName, SelectionState.defaults.buildName);
    });

    test('fromJson reads current schema payload and fills missing entries', () {
      final state = SelectionState.fromJson(<String, dynamic>{
        'schemaVersion': SelectionState.schemaVersion,
        'characterId': PlayerCharacterId.eloise.name,
        'loadoutsByCharacter': <String, Object?>{
          PlayerCharacterId.eloise.name: <String, Object?>{
            'abilityJumpId': 'eloise.custom_jump',
          },
        },
      });

      expect(state.selectedCharacterId, PlayerCharacterId.eloise);
      expect(
        state.loadoutFor(PlayerCharacterId.eloise).abilityJumpId,
        'eloise.custom_jump',
      );
      for (final id in PlayerCharacterId.values) {
        if (id == PlayerCharacterId.eloise) {
          continue;
        }
        expect(
          state.loadoutFor(id).abilityJumpId,
          SelectionState.defaults.loadoutFor(id).abilityJumpId,
        );
      }
    });

    test('fromJson missing mask falls back to character-authored mask', () {
      final state = SelectionState.fromJson(<String, dynamic>{
        'schemaVersion': SelectionState.schemaVersion,
        'characterId': PlayerCharacterId.eloise.name,
        'loadoutsByCharacter': <String, Object?>{
          PlayerCharacterId.eloise.name: <String, Object?>{
            'abilityJumpId': 'eloise.custom_jump',
          },
        },
      });

      expect(
        state.loadoutFor(PlayerCharacterId.eloise).mask,
        PlayerCharacterRegistry.resolve(
          PlayerCharacterId.eloise,
        ).catalog.loadoutSlotMask,
      );
    });

    test('toJson writes loadoutsByCharacter only', () {
      final state = SelectionState.defaults.withLoadoutFor(
        PlayerCharacterId.eloise,
        const EquippedLoadoutDef(abilityJumpId: 'eloise.custom_jump'),
      );

      final json = state.toJson();
      expect(json['schemaVersion'], SelectionState.schemaVersion);
      expect(json.containsKey('loadoutsByCharacter'), isTrue);
      expect(json.containsKey('loadout'), isFalse);
      final loadouts = json['loadoutsByCharacter']! as Map<String, Object?>;
      final eloise =
          loadouts[PlayerCharacterId.eloise.name]! as Map<String, Object?>;
      expect(eloise['abilityJumpId'], 'eloise.custom_jump');
    });

    test('fromJson unknown accessory id falls back to current default', () {
      final state = SelectionState.fromJson(<String, dynamic>{
        'schemaVersion': SelectionState.schemaVersion,
        'characterId': PlayerCharacterId.eloise.name,
        'loadoutsByCharacter': <String, Object?>{
          PlayerCharacterId.eloise.name: <String, Object?>{
            'accessoryId': 'ironBracers',
          },
        },
      });

      expect(
        state.loadoutFor(PlayerCharacterId.eloise).accessoryId,
        AccessoryId.strengthBelt,
      );
    });
  });
}
