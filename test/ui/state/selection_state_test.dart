import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/accessories/accessory_id.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:rpg_runner/ui/levels/level_id_ui.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:rpg_runner/ui/state/ownership/selection_state.dart';

void main() {
  test(
    'persisted unavailable choices restore the generated selectable default',
    () {
      expect(
        SelectionState.defaults.selectedLevelId,
        LevelRegistry.defaultLevelId,
      );
      expect(LevelRegistry.defaultLevelId.isSelectableInStandardUi, isTrue);
      for (final name in [
        'removed_level',
        ...LevelId.values.map((id) => id.name),
      ]) {
        final stored = Map<String, dynamic>.from(
          SelectionState.defaults.toJson(),
        )..['levelId'] = name;
        final restored = SelectionState.fromJson(stored);
        final selectable = selectableLevelIdsForUi()
            .where((id) => id.name == name)
            .firstOrNull;
        expect(
          restored.selectedLevelId,
          selectable ?? LevelRegistry.defaultLevelId,
        );
      }
    },
  );
  group('SelectionState per-character loadouts', () {
    test('defaults seed character-authored loadout masks', () {
      for (final id in PlayerCharacterId.values) {
        final expectedMask = PlayerCharacterRegistry.resolve(id)
            .catalog
            .loadoutSlotMask;
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

    test('all three named builds round trip without sharing edits', () {
      const id = PlayerCharacterId.bountyHunter;
      var state = SelectionState.defaults
          .selectBuild(id, 1)
          .copyWith(buildName: 'Crossbow')
          .withLoadoutFor(
            id,
            const EquippedLoadoutDef(abilityJumpId: 'custom.jump'),
          );
      state = state.selectBuild(id, 2).copyWith(buildName: 'Shotgun');
      final restored = SelectionState.fromJson(state.toJson());
      expect(restored.buildName, 'Shotgun');
      expect(restored.buildsFor(id).builds.map((b) => b.name), [
        'Build 1',
        'Crossbow',
        'Shotgun',
      ]);
      expect(
        restored.loadoutFor(id, buildIndex: 1).abilityJumpId,
        'custom.jump',
      );
      expect(
        restored.loadoutFor(id).abilityJumpId,
        SelectionState.defaults.loadoutFor(id).abilityJumpId,
      );
      expect(
        restored.loadoutFor(PlayerCharacterId.eloise).abilityJumpId,
        'eloise.jump',
      );
      expect(restored.toJson().containsKey('loadoutsByCharacter'), isFalse);
      expect(restored.toJson().containsKey('buildName'), isFalse);
    });

    test(
      'malformed slots and unavailable equipment restore character defaults',
      () {
        final json = SelectionState.defaults.toJson();
        final branches = json['buildsByCharacter'] as Map;
        final eloise = branches['eloise'] as Map;
        eloise['selectedBuildIndex'] = 30;
        final build = (eloise['builds'] as List).first as Map;
        build['loadout'] = {
          'accessoryId': 'removed',
          'abilityJumpId': 'custom.jump',
        };
        branches.remove('bountyHunter');
        final restored = SelectionState.fromJson(json);
        expect(restored.selectedBuildIndexFor(PlayerCharacterId.eloise), 0);
        expect(
          restored.loadoutFor(PlayerCharacterId.eloise).mask,
          PlayerCharacterRegistry.eloise.catalog.loadoutSlotMask,
        );
        expect(
          restored.loadoutFor(PlayerCharacterId.eloise).abilityJumpId,
          'custom.jump',
        );
        expect(
          restored.loadoutFor(PlayerCharacterId.eloise).accessoryId,
          AccessoryId.strengthBelt,
        );
        expect(
          restored.loadoutFor(PlayerCharacterId.bountyHunter).abilityJumpId,
          'bounty_hunter.jump',
        );
      },
    );

    test(
      'locked persisted selections fall back without destroying saved builds',
      () {
        const id = PlayerCharacterId.eloise;
        final state = SelectionState.defaults
            .selectBuild(id, 2)
            .copyWith(buildName: 'Third');
        expect(state.atPlayerLevel(11).selectedBuildIndexFor(id), 0);
        expect(state.atPlayerLevel(12).selectedBuildIndexFor(id), 2);
        expect(state.atPlayerLevel(1).buildsFor(id).builds[2].name, 'Third');
        for (final (level, count) in [
          (1, 1),
          (4, 1),
          (5, 2),
          (11, 2),
          (12, 3),
        ]) {
          for (var i = 0; i < 3; i++) {
            expect(SelectionState.isBuildUnlocked(i, level), i < count);
          }
        }
        expect(SelectionState.isBuildUnlocked(-1, 30), isFalse);
        expect(SelectionState.isBuildUnlocked(3, 30), isFalse);
        expect(() => state.selectBuild(id, 3), throwsRangeError);
      },
    );

    test(
      'names count visible characters and preserve a slot-specific default',
      () {
        final emoji = String.fromCharCodes([0x1f469, 0x1f3fd, 0x200d, 0x1f680]);
        expect(SelectionState.normalizeBuildName(emoji * 29), emoji * 28);
        expect(
          SelectionState.normalizeBuildName('  ', buildIndex: 2),
          'Build 3',
        );
        expect(SelectionState.normalizeBuildName('  My build  '), 'My build');
      },
    );
  });
}
