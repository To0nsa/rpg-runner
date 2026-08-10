import 'package:flutter_test/flutter_test.dart';

import '../../tool/level_definition_generation.dart';
import '../../tool/polygon_terrain_repository_generation.dart';

void main() {
  test(
    'builds one seam-validated batch and exact cleared legacy projection',
    () {
      final result = buildPolygonTerrainRepository(
        prefabSourcePath: 'assets/authoring/level/prefab_defs.json',
        prefabContents: _emptyPrefabs,
        chunkInputs: <PolygonTerrainRepositoryChunkInput>[
          const PolygonTerrainRepositoryChunkInput(
            sourcePath: 'assets/authoring/level/chunks/forest/empty.json',
            contents: _emptyChunk,
          ),
        ],
        levels: <LevelDefinitionSource>[_level()],
        schedulerSourcePath: 'assets/authoring/level/level_defs.json',
      );

      expect(result.issues, isEmpty);
      expect(result.validatedBatch, isNotNull);
      expect(result.chunks, hasLength(1));
      expect(result.chunks.single.compiled.geometry.polygons, isEmpty);
      expect(result.chunks.single.legacyProjection.rectangles, isEmpty);
      expect(
        result.chunks.single.legacyProjection.groundGaps.single.gapId,
        'collision_cleared',
      );
      expect(
        result.validatedBatch!.seamSignature.canonicalRecord,
        'authoring-seams-v1\nforest|steady-hard:tier=hard>hard|empty>empty',
      );
    },
  );

  test('blocks a scheduler-reachable compiled boundary mismatch', () {
    final result = buildPolygonTerrainRepository(
      prefabSourcePath: 'assets/authoring/level/prefab_defs.json',
      prefabContents: _emptyPrefabs,
      chunkInputs: <PolygonTerrainRepositoryChunkInput>[
        const PolygonTerrainRepositoryChunkInput(
          sourcePath: 'assets/authoring/level/chunks/forest/early.json',
          contents: _edgeChunk,
        ),
        const PolygonTerrainRepositoryChunkInput(
          sourcePath: 'assets/authoring/level/chunks/forest/easy.json',
          contents: _emptyEasyChunk,
        ),
      ],
      levels: <LevelDefinitionSource>[_level(earlyPatternChunks: 1)],
      schedulerSourcePath: 'assets/authoring/level/level_defs.json',
    );

    expect(result.validatedBatch, isNull);
    expect(result.chunks, isEmpty);
    expect(
      result.issues.map((issue) => issue.code),
      contains('staged_reachable_seam_mismatch'),
    );
  });

  test(
    'rejects a diagonal that the temporary legacy bridge cannot express',
    () {
      final result = buildPolygonTerrainRepository(
        prefabSourcePath: 'assets/authoring/level/prefab_defs.json',
        prefabContents: _emptyPrefabs,
        chunkInputs: <PolygonTerrainRepositoryChunkInput>[
          const PolygonTerrainRepositoryChunkInput(
            sourcePath: 'assets/authoring/level/chunks/forest/slope.json',
            contents: _internalSlopeChunk,
          ),
        ],
        levels: <LevelDefinitionSource>[_level()],
        schedulerSourcePath: 'assets/authoring/level/level_defs.json',
      );

      expect(result.validatedBatch, isNull);
      expect(result.chunks, isEmpty);
      expect(
        result.issues.map((issue) => issue.code),
      contains('legacy_diagonal_edge'),
      );
    },
  );
}

LevelDefinitionSource _level({int earlyPatternChunks = 0}) =>
    LevelDefinitionSource(
      levelId: 'forest',
      revision: 1,
      displayName: 'Forest',
      visualThemeId: 'forest',
      chunkThemeGroups: const <String>['default'],
      cameraCenterY: 50,
      groundTopY: 80,
      earlyPatternChunks: earlyPatternChunks,
      easyPatternChunks: 0,
      normalPatternChunks: 0,
      noEnemyChunks: 0,
      enumOrdinal: 0,
      status: activeLevelStatus,
    );

const String _emptyPrefabs = '''
{
  "schemaVersion": 3,
  "slices": [],
  "prefabs": []
}
''';

const String _emptyChunk = '''
{
  "schemaVersion": 2,
  "chunkKey": "empty",
  "id": "empty",
  "revision": 1,
  "status": "active",
  "levelId": "forest",
  "tileSize": 16,
  "width": 100,
  "height": 100,
  "difficulty": "normal",
  "assemblyGroupId": "default",
  "tags": [],
  "tileLayers": [],
  "prefabs": [],
  "markers": [],
  "collisionShapes": []
}
''';

const String _emptyEasyChunk = '''
{
  "schemaVersion": 2,
  "chunkKey": "easy",
  "id": "easy",
  "revision": 1,
  "status": "active",
  "levelId": "forest",
  "tileSize": 16,
  "width": 100,
  "height": 100,
  "difficulty": "easy",
  "assemblyGroupId": "default",
  "tags": [],
  "tileLayers": [],
  "prefabs": [],
  "markers": [],
  "collisionShapes": []
}
''';

const String _edgeChunk = '''
{
  "schemaVersion": 2,
  "chunkKey": "early",
  "id": "early",
  "revision": 1,
  "status": "active",
  "levelId": "forest",
  "tileSize": 16,
  "width": 100,
  "height": 100,
  "difficulty": "early",
  "assemblyGroupId": "default",
  "tags": [],
  "tileLayers": [],
  "prefabs": [],
  "markers": [],
  "collisionShapes": [
    {
      "shapeId": "edge",
      "vertices": [
        {"x": 80, "y": 40},
        {"x": 100, "y": 40},
        {"x": 100, "y": 80},
        {"x": 80, "y": 80}
      ],
      "collisionMode": "solid"
    }
  ]
}
''';

const String _internalSlopeChunk = '''
{
  "schemaVersion": 2,
  "chunkKey": "slope",
  "id": "slope",
  "revision": 1,
  "status": "active",
  "levelId": "forest",
  "tileSize": 16,
  "width": 100,
  "height": 100,
  "difficulty": "normal",
  "assemblyGroupId": "default",
  "tags": [],
  "tileLayers": [],
  "prefabs": [],
  "markers": [],
  "collisionShapes": [
    {
      "shapeId": "slope",
      "vertices": [
        {"x": 20, "y": 40},
        {"x": 60, "y": 60},
        {"x": 60, "y": 80},
        {"x": 20, "y": 80}
      ],
      "collisionMode": "solid"
    }
  ]
}
''';
