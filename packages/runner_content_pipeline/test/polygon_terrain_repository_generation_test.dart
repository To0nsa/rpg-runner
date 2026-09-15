import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:test/test.dart';

void main() {
  test('builds one seam-validated polygon batch', () {
    final result = buildPolygonTerrainRepository(
      prefabSourcePath: 'assets/authoring/level/prefab_defs.json',
      prefabContents: _emptyPrefabs,
      chunkInputs: <PolygonTerrainRepositoryChunkInput>[
        const PolygonTerrainRepositoryChunkInput(
          sourcePath: 'assets/authoring/level/chunks/forest/empty.json',
          contents: _flatChunk,
        ),
      ],
      levels: <PolygonTerrainSchedulerLevelSource>[_level()],
      schedulerSourcePath: 'assets/authoring/level/level_defs.json',
    );

    expect(result.issues, isEmpty);
    expect(result.validatedBatch, isNotNull);
    expect(result.chunks, hasLength(1));
    expect(result.chunks.single.compiled.geometry.polygons, hasLength(1));
    expect(
      result.validatedBatch!.seamSignature.canonicalRecord,
      contains('connections-v1:automatic:'),
    );
  });

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
      levels: <PolygonTerrainSchedulerLevelSource>[
        _level(earlyPatternChunks: 1),
      ],
      schedulerSourcePath: 'assets/authoring/level/level_defs.json',
    );

    expect(result.validatedBatch, isNull);
    expect(result.chunks, hasLength(2));
    expect(
      result.issues.map((issue) => issue.code),
      contains('terrain_connection_schedule_dead_end'),
    );
  });

  test('accepts polygon terrain without a rectangle projection', () {
    final result = buildPolygonTerrainRepository(
      prefabSourcePath: 'assets/authoring/level/prefab_defs.json',
      prefabContents: _emptyPrefabs,
      chunkInputs: <PolygonTerrainRepositoryChunkInput>[
        const PolygonTerrainRepositoryChunkInput(
          sourcePath: 'assets/authoring/level/chunks/forest/slope.json',
          contents: _internalSlopeChunk,
        ),
      ],
      levels: <PolygonTerrainSchedulerLevelSource>[_level()],
      schedulerSourcePath: 'assets/authoring/level/level_defs.json',
    );

    expect(result.issues, isEmpty);
    expect(result.validatedBatch, isNotNull);
    expect(result.chunks, hasLength(1));
    expect(result.chunks.single.compiled.geometry.polygons, hasLength(2));
  });

  test(
    'excluded unfinished seams are validated individually but not published',
    () {
      final excluded = _experiment(included: false);
      expect(excluded.issues, isEmpty);
      expect(excluded.chunks, hasLength(3));
      expect(
        excluded.validatedBatch!.chunks.map((chunk) => chunk.chunk.levelId),
        <String>['field'],
      );
      expect(
        excluded.validatedBatch!.seamSignature.canonicalRecord,
        isNot(contains('forest')),
      );

      final included = _experiment(included: true);
      expect(included.validatedBatch, isNull);
      expect(
        included.issues.map((issue) => issue.code),
        contains('terrain_connection_schedule_dead_end'),
      );
    },
  );

  test(
    'excluded invalid geometry and duplicate identities still block the batch',
    () {
      final invalid = _experiment(
        included: false,
        experimentChunk: _edgeChunk.replaceFirst(
          '"x": 80, "y": 40',
          '"x": -2, "y": 40',
        ),
      );
      expect(invalid.issues, isNotEmpty);
      expect(invalid.validatedBatch, isNull);
      final duplicate = _experiment(
        included: false,
        experimentChunk: _emptyEasyChunk,
      );
      expect(
        duplicate.issues.map((issue) => issue.code),
        contains('staged_seam_chunk_duplicate'),
      );
      expect(duplicate.validatedBatch, isNull);
    },
  );

  test(
    'deprecated chunks cannot satisfy capacity or enter generated terrain',
    () {
      final result = _experiment(
        included: false,
        extraChunk: _flatChunk
            .replaceAll('"empty"', '"deprecated"')
            .replaceFirst('"forest"', '"field"')
            .replaceFirst('"active"', '"deprecated"'),
      );
      expect(result.issues, isEmpty);
      expect(result.chunks, hasLength(4));
      expect(result.validatedBatch!.chunks, hasLength(1));

      final empty = buildPolygonTerrainRepository(
        prefabSourcePath: 'assets/authoring/level/prefab_defs.json',
        prefabContents: _emptyPrefabs,
        chunkInputs: <PolygonTerrainRepositoryChunkInput>[
          PolygonTerrainRepositoryChunkInput(
            sourcePath: 'assets/authoring/level/chunks/forest/empty.json',
            contents: _flatChunk.replaceFirst('"active"', '"deprecated"'),
          ),
        ],
        levels: <PolygonTerrainSchedulerLevelSource>[_level()],
        schedulerSourcePath: 'assets/authoring/level/level_defs.json',
      );
      expect(
        empty.issues.map((issue) => issue.code),
        contains('terrain_connection_schedule_dead_end'),
      );
      expect(empty.chunks, hasLength(1));
      expect(empty.validatedBatch, isNull);
    },
  );
}

PolygonTerrainRepositoryGenerationResult _experiment({
  required bool included,
  String experimentChunk = _edgeChunk,
  String? extraChunk,
}) => buildPolygonTerrainRepository(
  prefabSourcePath: 'assets/authoring/level/prefab_defs.json',
  prefabContents: _emptyPrefabs,
  chunkInputs: <PolygonTerrainRepositoryChunkInput>[
    PolygonTerrainRepositoryChunkInput(
      sourcePath: 'assets/authoring/level/chunks/field/empty.json',
      contents: _flatChunk.replaceFirst('"forest"', '"field"'),
    ),
    PolygonTerrainRepositoryChunkInput(
      sourcePath: 'assets/authoring/level/chunks/forest/early.json',
      contents: experimentChunk,
    ),
    const PolygonTerrainRepositoryChunkInput(
      sourcePath: 'assets/authoring/level/chunks/forest/easy.json',
      contents: _emptyEasyChunk,
    ),
    if (extraChunk != null)
      PolygonTerrainRepositoryChunkInput(
        sourcePath: 'assets/authoring/level/chunks/field/deprecated.json',
        contents: extraChunk,
      ),
  ],
  levels: <PolygonTerrainSchedulerLevelSource>[
    const PolygonTerrainSchedulerLevelSource(
      levelId: 'field',
      groundTopY: 40,
      spawnX: 80,
      earlyPatternChunks: 0,
      easyPatternChunks: 0,
      normalPatternChunks: 0,
    ),
    PolygonTerrainSchedulerLevelSource(
      levelId: 'forest',
      groundTopY: 40,
      spawnX: 80,
      earlyPatternChunks: 1,
      easyPatternChunks: 1,
      normalPatternChunks: 0,
      includeInBuild: included,
    ),
  ],
  schedulerSourcePath: 'assets/authoring/level/level_defs.json',
);

PolygonTerrainSchedulerLevelSource _level({int earlyPatternChunks = 0}) =>
    PolygonTerrainSchedulerLevelSource(
      levelId: 'forest',
      groundTopY: 40,
      spawnX: 80,
      earlyPatternChunks: earlyPatternChunks,
      easyPatternChunks: 0,
      normalPatternChunks: 0,
    );

const String _emptyPrefabs = '''
{
  "schemaVersion": 3,
  "slices": [],
  "prefabs": []
}
''';

const String _flatChunk = '''
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
  "collisionShapes": [{"shapeId":"ground", "collisionMode":"solid", "vertices":[{"x":0,"y":40},{"x":100,"y":40},{"x":100,"y":100},{"x":0,"y":100}]}]
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
  "collisionShapes": [{"shapeId":"ground", "collisionMode":"solid", "vertices":[{"x":0,"y":40},{"x":100,"y":40},{"x":100,"y":100},{"x":0,"y":100}]},
    {
      "shapeId": "slope",
      "vertices": [
        {"x": 20, "y": 20},
        {"x": 60, "y": 30},
        {"x": 60, "y": 40},
        {"x": 20, "y": 40}
      ],
      "collisionMode": "solid"
    }
  ]
}
''';
