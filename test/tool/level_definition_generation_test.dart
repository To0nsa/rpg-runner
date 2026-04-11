import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:rpg_runner/ui/levels/level_id_ui.dart';

import '../../tool/level_definition_generation.dart';

void main() {
  test(
    'repo level_defs bootstrap matches current runtime metadata and enum order',
    () async {
      final result = await loadLevelDefinitions(
        defsPath: 'assets/authoring/level/level_defs.json',
      );

      expect(result.issues, isEmpty);
      expect(result.levels.length, LevelId.values.length);

      final byLevelId = <String, LevelDefinitionSource>{
        for (final level in result.levels) level.levelId: level,
      };

      for (final levelId in LevelId.values) {
        final authored = byLevelId[levelId.name];
        expect(authored, isNotNull);

        final runtime = LevelRegistry.byId(levelId);
        expect(authored!.displayName, levelId.displayName);
        expect(authored.themeId, runtime.themeId);
        expect(authored.cameraCenterY, runtime.cameraCenterY);
        expect(authored.groundTopY, runtime.groundTopY);
        expect(authored.earlyPatternChunks, runtime.earlyPatternChunks);
        expect(authored.easyPatternChunks, runtime.easyPatternChunks);
        expect(authored.normalPatternChunks, runtime.normalPatternChunks);
        expect(authored.noEnemyChunks, runtime.noEnemyChunks);
      }

      final authoredEnumOrder = result.levels.toList(growable: false)
        ..sort((a, b) => a.enumOrdinal.compareTo(b.enumOrdinal));
      expect(
        authoredEnumOrder.map((level) => level.levelId).toList(growable: false),
        LevelId.values.map((levelId) => levelId.name).toList(growable: false),
      );
    },
  );

  test(
    'loadLevelDefinitions reports canonicalization failures deterministically',
    () async {
      final fixtureRoot = await Directory.systemTemp.createTemp('level_defs_');
      try {
        final defsFile = File(
          _joinPath(<String>[
            fixtureRoot.path,
            'assets',
            'authoring',
            'level',
            'level_defs.json',
          ]),
        );
        defsFile.parent.createSync(recursive: true);
        defsFile.writeAsStringSync(r'''
{
  "schemaVersion": 1,
  "levels": [
    {
      "levelId": "forest",
      "revision": 1,
      "displayName": "Forest",
      "themeId": "forest",
      "cameraCenterY": 135,
      "groundTopY": 224,
      "earlyPatternChunks": 3,
      "easyPatternChunks": 0,
      "normalPatternChunks": 0,
      "noEnemyChunks": 3,
      "enumOrdinal": 10,
      "status": "active"
    },
    {
      "levelId": "field",
      "revision": 1,
      "displayName": "Field",
      "themeId": "field",
      "cameraCenterY": 135,
      "groundTopY": 224,
      "earlyPatternChunks": 3,
      "easyPatternChunks": 0,
      "normalPatternChunks": 0,
      "noEnemyChunks": 3,
      "enumOrdinal": 20,
      "status": "active"
    }
  ]
}
''');

        final result = await loadLevelDefinitions(defsPath: defsFile.path);
        expect(
          result.issues.map((issue) => issue.code).toList(growable: false),
          contains('non_canonical_level_defs'),
        );
      } finally {
        fixtureRoot.deleteSync(recursive: true);
      }
    },
  );

  test('renderLevelUiMetadataDartOutput excludes deprecated levels from '
      'generated selectable ids', () async {
    final fixtureRoot = await Directory.systemTemp.createTemp(
      'level_defs_ui_metadata_',
    );
    try {
      final defsFile = File(
        _joinPath(<String>[
          fixtureRoot.path,
          'assets',
          'authoring',
          'level',
          'level_defs.json',
        ]),
      );
      defsFile.parent.createSync(recursive: true);
      defsFile.writeAsStringSync(r'''
{
  "schemaVersion": 1,
  "levels": [
    {
      "levelId": "field",
      "revision": 1,
      "displayName": "Field",
      "themeId": "field",
      "cameraCenterY": 135,
      "groundTopY": 224,
      "earlyPatternChunks": 3,
      "easyPatternChunks": 0,
      "normalPatternChunks": 0,
      "noEnemyChunks": 3,
      "enumOrdinal": 20,
      "status": "active"
    },
    {
      "levelId": "forest",
      "revision": 1,
      "displayName": "Forest",
      "themeId": "forest",
      "cameraCenterY": 135,
      "groundTopY": 224,
      "earlyPatternChunks": 3,
      "easyPatternChunks": 0,
      "normalPatternChunks": 0,
      "noEnemyChunks": 3,
      "enumOrdinal": 10,
      "status": "deprecated"
    }
  ]
}
''');

      final result = await loadLevelDefinitions(defsPath: defsFile.path);
      expect(result.issues, isEmpty);

      final generated = renderLevelUiMetadataDartOutput(result.levels);
      expect(generated, contains('LevelUiStatus.deprecated'));

      final listMatch = RegExp(
        r'const List<LevelId> generatedSelectableLevelIds = <LevelId>\[(.*?)\];',
        dotAll: true,
      ).firstMatch(generated);
      expect(listMatch, isNotNull);
      final listBody = listMatch!.group(1)!;
      expect(listBody, contains('LevelId.field'));
      expect(listBody, isNot(contains('LevelId.forest')));
    } finally {
      fixtureRoot.deleteSync(recursive: true);
    }
  });

  test('renderLevelIdDartOutput matches checked-in generated file', () async {
    final result = await loadLevelDefinitions(
      defsPath: 'assets/authoring/level/level_defs.json',
    );

    expect(result.issues, isEmpty);

    final generated = renderLevelIdDartOutput(result.levels);
    final checkedIn = File(
      'packages/runner_core/lib/levels/level_id.dart',
    ).readAsStringSync();

    expect(generated, checkedIn);
  });

  test(
    'renderLevelRegistryDartOutput matches checked-in generated file',
    () async {
      final result = await loadLevelDefinitions(
        defsPath: 'assets/authoring/level/level_defs.json',
      );

      expect(result.issues, isEmpty);

      final generated = renderLevelRegistryDartOutput(result.levels);
      final checkedIn = File(
        'packages/runner_core/lib/levels/level_registry.dart',
      ).readAsStringSync();

      expect(generated, checkedIn);
    },
  );

  test(
    'renderLevelUiMetadataDartOutput matches checked-in generated file',
    () async {
      final result = await loadLevelDefinitions(
        defsPath: 'assets/authoring/level/level_defs.json',
      );

      expect(result.issues, isEmpty);

      final generated = renderLevelUiMetadataDartOutput(result.levels);
      final checkedIn = File(
        'lib/ui/levels/generated_level_ui_metadata.dart',
      ).readAsStringSync();

      expect(generated, checkedIn);
    },
  );
}

String _joinPath(List<String> parts) {
  return parts.join(Platform.pathSeparator);
}
