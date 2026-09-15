import 'package:flutter_test/flutter_test.dart';

import '../../tool/level_definition_generation.dart';
import '../../tool/migrate_level_build_inclusion.dart';

void main() {
  test(
    'v2 migration adds guides without changing inclusion or geometry settings',
    () {
      final v2 = _legacy
          .replaceFirst('"schemaVersion": 1', '"schemaVersion": 2')
          .replaceFirst(
            '"enumOrdinal": 17,',
            '"enumOrdinal": 17,\n      "includeInBuild": false,',
          );
      final migrated = migrateLevelBuildInclusionSource(
        v2,
        sourcePath: 'level_defs.json',
      );
      final decoded = decodeLevelDefinitions(
        migrated,
        defsPath: 'level_defs.json',
      );
      expect(decoded.issues, isEmpty);
      expect(decoded.levels.single.includeInBuild, isFalse);
      expect(decoded.levels.single.terrainHeightStepPx, 24);
      expect(decoded.levels.single.groundTopY, 224);
      for (final invalid in ['null', '0', '33', '1.5', '"24"']) {
        expect(
          decodeLevelDefinitions(
            migrated.replaceFirst(
              '"terrainHeightStepPx": 24',
              '"terrainHeightStepPx": $invalid',
            ),
            defsPath: 'level_defs.json',
          ).issues,
          isNotEmpty,
        );
      }
    },
  );
  test('explicit v1 migration preserves identities, ordinals, revisions and design', () {
    final migrated = migrateLevelBuildInclusionSource(
      _legacy,
      sourcePath: 'level_defs.json',
    );
    final decoded = decodeLevelDefinitions(
      migrated,
      defsPath: 'level_defs.json',
    );
    expect(decoded.issues, isEmpty);
    final level = decoded.levels.single;
    expect(level.levelId, 'archived');
    expect(level.enumOrdinal, 17);
    expect(level.revision, 9);
    expect(level.status, deprecatedLevelStatus);
    expect(level.includeInBuild, isTrue);
    expect(level.chunkThemeGroups, <String>['default', 'woods']);
    expect(level.assembly!.segments.single.requireDistinctChunks, isTrue);
    expect(level.assembly!.segments.single.maxChunkCount, 8);
    expect(
      migrateLevelBuildInclusionSource(migrated, sourcePath: 'level_defs.json'),
      migrated,
    );
  });

  test('normal decoder rejects v1 and missing or nonboolean v2 inclusion', () {
    expect(
      decodeLevelDefinitions(
        _legacy,
        defsPath: 'level_defs.json',
      ).issues.map((issue) => issue.code),
      contains('invalid_schema_version'),
    );
    final migrated = migrateLevelBuildInclusionSource(
      _legacy,
      sourcePath: 'level_defs.json',
    );
    for (final value in <String>['"true"', 'null', '1']) {
      expect(
        decodeLevelDefinitions(
          migrated.replaceFirst(
            '"includeInBuild": true',
            '"includeInBuild": $value',
          ),
          defsPath: 'level_defs.json',
        ).issues.map((issue) => issue.code),
        contains('invalid_include_in_build'),
      );
    }
  });

  test(
    'migration fails on malformed, unknown or noncanonical historical fields',
    () {
      for (final source in <String>[
        _legacy.replaceFirst('"revision": 9', '"revision": 0'),
        _legacy.replaceFirst(
          '"enumOrdinal": 17,',
          '"enumOrdinal": 17,\n      "extra": true,',
        ),
        _legacy.replaceFirst(
          '"enumOrdinal": 17,',
          '"enumOrdinal": 17,\n      "includeInBuild": false,',
        ),
        _legacy.replaceFirst('"schemaVersion": 1', '"schemaVersion": 0'),
        _legacy.replaceFirst('"cameraCenterY": 135', '"cameraCenterY": 135.0'),
      ]) {
        expect(
          () => migrateLevelBuildInclusionSource(
            source,
            sourcePath: 'level_defs.json',
          ),
          throwsFormatException,
        );
      }
    },
  );
}

const _legacy = '''
{
  "schemaVersion": 1,
  "levels": [
    {
      "levelId": "archived",
      "revision": 9,
      "displayName": "Archived",
      "visualThemeId": "forest",
      "chunkThemeGroups": ["default", "woods"],
      "cameraCenterY": 135,
      "groundTopY": 224,
      "earlyPatternChunks": 3,
      "easyPatternChunks": 0,
      "normalPatternChunks": 0,
      "noEnemyChunks": 3,
      "enumOrdinal": 17,
      "status": "deprecated",
      "assembly": {
        "loopSegments": true,
        "segments": [
          {
            "segmentId": "opening",
            "groupId": "woods",
            "minChunkCount": 2,
            "maxChunkCount": 8,
            "requireDistinctChunks": true
          }
        ]
      }
    }
  ]
}
''';
