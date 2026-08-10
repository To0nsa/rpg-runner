import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/chunks/chunk_v2_collision_expansion.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_data.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';

void main() {
  test('expands anchor-relative prefab source through Core exactly once', () {
    final prefab = _prefab(
      anchorXPx: 8,
      anchorYPx: 12,
      shapes: <TerrainSourceShapeDef>[
        _rectangle('collision_001', left: -2, top: -4, right: 2, bottom: 0),
      ],
    );
    final chunk = _chunk(
      width: 100,
      height: 100,
      placements: const <PlacedPrefabDef>[
        PlacedPrefabDef(
          prefabId: 'rock',
          prefabKey: 'prefab_rock',
          x: 20,
          y: 30,
          scale: 0.5,
          flipX: true,
        ),
      ],
    );

    final result = expandChunkV2Collision(
      chunk: chunk,
      prefabs: <PrefabV3Def>[prefab],
      sourcePath: 'chunks/forest/test.json',
    );

    expect(result.issues, isEmpty);
    final expansion = result.expansion!;
    expect(expansion.directShapeCount, 0);
    expect(expansion.expandedPrefabShapeCount, 1);
    final shape = expansion.expandedPrefabShapes.single;
    expect(shape.prefabKey, 'prefab_rock');
    expect(shape.prefabRevision, 7);
    expect(shape.placementKey, 'prefab_rock|20|30|0');
    expect(shape.scaleTenths, 5);
    expect(
      shape.vertices.map((point) => (point.xTicks, point.yTicks)).toSet(),
      <(int, int)>{
        (19 * terrainPhysicsTicksPerWorldUnit + 512, 29 * 1024),
        (20 * terrainPhysicsTicksPerWorldUnit + 512, 29 * 1024),
        (20 * terrainPhysicsTicksPerWorldUnit + 512, 30 * 1024),
        (19 * terrainPhysicsTicksPerWorldUnit + 512, 30 * 1024),
      },
    );
  });

  test(
    'compiles direct and placed shapes together for overlap diagnostics',
    () {
      final result = expandChunkV2Collision(
        chunk: _chunk(
          directShapes: <TerrainSourceShapeDef>[
            _rectangle('ground', left: 0, top: 0, right: 40, bottom: 40),
          ],
          placements: const <PlacedPrefabDef>[
            PlacedPrefabDef(
              prefabId: 'rock',
              prefabKey: 'prefab_rock',
              x: 10,
              y: 10,
            ),
          ],
        ),
        prefabs: <PrefabV3Def>[
          _prefab(
            shapes: <TerrainSourceShapeDef>[
              _rectangle(
                'collision_001',
                left: 0,
                top: 0,
                right: 20,
                bottom: 20,
              ),
            ],
          ),
        ],
        sourcePath: 'chunks/forest/test.json',
      );

      expect(result.expansion, isNull);
      final overlap = result.issues.singleWhere(
        (issue) => issue.code == 'polygon_area_overlap',
      );
      expect(overlap.placementKey, 'prefab_rock|10|10|0');
      expect(overlap.ownerKey, 'prefab_rock');
      expect(overlap.shapeId, 'collision_001');
    },
  );

  test('retains quantized geometry while reporting exact bounds lineage', () {
    final result = expandChunkV2Collision(
      chunk: _chunk(
        width: 20,
        height: 20,
        placements: const <PlacedPrefabDef>[
          PlacedPrefabDef(
            prefabId: 'rock',
            prefabKey: 'prefab_rock',
            x: 19,
            y: 19,
            scale: 0.3,
          ),
        ],
      ),
      prefabs: <PrefabV3Def>[
        _prefab(
          shapes: <TerrainSourceShapeDef>[
            _rectangle('collision_001', left: 0, top: 0, right: 10, bottom: 10),
          ],
        ),
      ],
      sourcePath: 'chunks/forest/test.json',
    );

    expect(result.expansion, isNotNull);
    final outside = result.issues.where(
      (issue) => issue.code == 'expanded_prefab_vertex_out_of_bounds',
    );
    expect(outside, isNotEmpty);
    expect(
      outside.map((issue) => issue.message),
      contains(contains('(20.5, 19) px')),
    );
    expect(
      outside.every(
        (issue) =>
            issue.ownerKey == 'prefab_rock' &&
            issue.placementKey == 'prefab_rock|19|19|0' &&
            issue.shapeId == 'collision_001' &&
            issue.elementIndex != null,
      ),
      isTrue,
    );
  });

  test('rejects unresolved, ambiguous, and off-step placement source', () {
    final ambiguousA = _prefab(prefabKey: 'prefab_a', id: 'shared');
    final ambiguousB = _prefab(prefabKey: 'shared', id: 'other');
    final result = expandChunkV2Collision(
      chunk: _chunk(
        placements: const <PlacedPrefabDef>[
          PlacedPrefabDef(prefabId: 'missing', x: 10, y: 10),
          PlacedPrefabDef(prefabId: 'shared', x: 20, y: 20),
          PlacedPrefabDef(prefabId: 'prefab_a', x: 30, y: 30, scale: 0.35),
        ],
      ),
      prefabs: <PrefabV3Def>[ambiguousB, ambiguousA],
      sourcePath: 'chunks/forest/test.json',
    );

    expect(result.expansion, isNull);
    expect(result.issues.map((issue) => issue.code).toSet(), {
      'unknown_prefab_reference',
      'ambiguous_prefab_reference',
      'invalid_prefab_placement_scale',
    });
    expect(
      result.issues.every((issue) => issue.ownerKey == 'forest_test'),
      isTrue,
    );
  });

  test('delegates placed-prefab shape capacity to Core', () {
    final shapes = <TerrainSourceShapeDef>[
      for (var index = 0; index < 65; index += 1)
        _rectangle(
          'collision_${index.toString().padLeft(3, '0')}',
          left: index * 4,
          top: 0,
          right: index * 4 + 2,
          bottom: 2,
        ),
    ];
    final result = expandChunkV2Collision(
      chunk: _chunk(
        width: 300,
        placements: const <PlacedPrefabDef>[
          PlacedPrefabDef(
            prefabId: 'rock',
            prefabKey: 'prefab_rock',
            x: 0,
            y: 0,
          ),
        ],
      ),
      prefabs: <PrefabV3Def>[_prefab(shapes: shapes)],
      sourcePath: 'chunks/forest/test.json',
    );

    expect(result.expansion, isNull);
    expect(
      result.issues
          .singleWhere((issue) => issue.code == 'prefab_shape_limit')
          .ownerKey,
      'prefab_rock',
    );
  });

  test('assigns direct bounds findings to the chunk owner', () {
    final result = expandChunkV2Collision(
      chunk: _chunk(
        width: 10,
        height: 10,
        directShapes: <TerrainSourceShapeDef>[
          _rectangle('ground', left: 0, top: 0, right: 24, bottom: 16),
        ],
      ),
      prefabs: const <PrefabV3Def>[],
      sourcePath: 'chunks/forest/test.json',
    );

    expect(result.expansion, isNotNull);
    final outside = result.issues.where(
      (issue) => issue.code == 'chunk_collision_shape_out_of_bounds',
    );
    expect(outside, isNotEmpty);
    expect(
      outside.every(
        (issue) =>
            issue.ownerKey == 'forest_test' && issue.placementKey == null,
      ),
      isTrue,
    );
  });

  test('is deterministic when prefab and placement input order changes', () {
    final prefabA = _prefab(prefabKey: 'prefab_a', id: 'a');
    final prefabB = _prefab(prefabKey: 'prefab_b', id: 'b');
    const placements = <PlacedPrefabDef>[
      PlacedPrefabDef(prefabId: 'b', prefabKey: 'prefab_b', x: 40, y: 20),
      PlacedPrefabDef(prefabId: 'a', prefabKey: 'prefab_a', x: 10, y: 20),
    ];

    final forward = expandChunkV2Collision(
      chunk: _chunk(placements: placements),
      prefabs: <PrefabV3Def>[prefabA, prefabB],
      sourcePath: 'chunks/forest/test.json',
    );
    final reversed = expandChunkV2Collision(
      chunk: _chunk(placements: placements.reversed),
      prefabs: <PrefabV3Def>[prefabB, prefabA],
      sourcePath: 'chunks/forest/test.json',
    );

    expect(forward.issues, isEmpty);
    expect(reversed.issues, isEmpty);
    expect(
      forward.expansion!.geometry.edgeSignature(),
      reversed.expansion!.geometry.edgeSignature(),
    );
    expect(
      forward.expansion!.expandedPrefabShapes.map(
        (shape) => shape.placementKey,
      ),
      reversed.expansion!.expandedPrefabShapes.map(
        (shape) => shape.placementKey,
      ),
    );
  });
}

PrefabV3Def _prefab({
  String prefabKey = 'prefab_rock',
  String id = 'rock',
  int anchorXPx = 0,
  int anchorYPx = 0,
  Iterable<TerrainSourceShapeDef>? shapes,
}) => PrefabV3Def(
  prefabKey: prefabKey,
  id: id,
  revision: 7,
  status: PrefabStatus.active,
  kind: PrefabKind.obstacle,
  visualSource: const PrefabVisualSource.atlasSlice('rock_slice'),
  anchorXPx: anchorXPx,
  anchorYPx: anchorYPx,
  collisionShapes:
      shapes ??
      <TerrainSourceShapeDef>[
        _rectangle('collision_001', left: 0, top: 0, right: 4, bottom: 4),
      ],
  tags: const <String>[],
);

ChunkV2FileData _chunk({
  int width = 100,
  int height = 100,
  Iterable<PlacedPrefabDef> placements = const <PlacedPrefabDef>[],
  Iterable<TerrainSourceShapeDef> directShapes =
      const <TerrainSourceShapeDef>[],
}) => ChunkV2FileData(
  chunkKey: 'forest_test',
  id: 'forest_test',
  revision: 1,
  status: chunkStatusActive,
  levelId: 'forest',
  tileSize: 16,
  width: width,
  height: height,
  difficulty: chunkDifficultyNormal,
  assemblyGroupId: defaultChunkAssemblyGroupId,
  tags: const <String>[],
  tileLayers: const <TileLayerDef>[],
  prefabs: placements,
  markers: const <PlacedMarkerDef>[],
  groundBandZIndex: 0,
  collisionShapes: directShapes,
);

TerrainSourceShapeDef _rectangle(
  String shapeId, {
  required int left,
  required int top,
  required int right,
  required int bottom,
}) => TerrainSourceShapeDef(
  shapeId: shapeId,
  vertices: <TerrainSourceVertexDef>[
    TerrainSourceVertexDef(xHalfPixels: left, yHalfPixels: top),
    TerrainSourceVertexDef(xHalfPixels: right, yHalfPixels: top),
    TerrainSourceVertexDef(xHalfPixels: right, yHalfPixels: bottom),
    TerrainSourceVertexDef(xHalfPixels: left, yHalfPixels: bottom),
  ],
);
