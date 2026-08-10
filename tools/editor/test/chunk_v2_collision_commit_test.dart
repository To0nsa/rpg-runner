import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/collision/terrain/terrain_authoring_capacity.dart';
import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/chunks/chunk_v2_collision_commit.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_data.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_polygon_interaction.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';

void main() {
  const policy = ChunkV2CollisionCommitPolicy();

  test('accepted owner-valid commit replaces geometry and bumps once', () {
    final before = <TerrainSourceShapeDef>[
      _rectangle('ground', left: 0, top: 20, right: 200, bottom: 100),
    ];
    final after = <TerrainSourceShapeDef>[
      _rectangle('ground', left: 0, top: 18, right: 200, bottom: 100),
    ];
    final chunk = _chunk(before);

    final result = policy.apply(
      chunk: chunk,
      commit: _commit(before: before, after: after),
      sourcePath: 'chunks/target.json',
    );

    expect(result.accepted, isTrue);
    expect(result.changed, isTrue);
    expect(result.issues, isEmpty);
    expect(result.chunk, isNot(same(chunk)));
    expect(result.chunk.chunkKey, chunk.chunkKey);
    expect(result.chunk.revision, 8);
    expect(result.chunk.collisionShapes, after);
    expect(result.chunk.tags, chunk.tags);
  });

  test('no-op commit preserves owner identity and revision', () {
    final shapes = <TerrainSourceShapeDef>[
      _rectangle('ground', left: 0, top: 20, right: 200, bottom: 100),
    ];
    final chunk = _chunk(shapes);

    final result = policy.apply(
      chunk: chunk,
      commit: _commit(before: shapes, after: shapes),
    );

    expect(result.accepted, isTrue);
    expect(result.changed, isFalse);
    expect(result.chunk, same(chunk));
    expect(result.chunk.revision, 7);
  });

  test('stale commit rejects without changing owner', () {
    final current = <TerrainSourceShapeDef>[
      _rectangle('ground', left: 0, top: 20, right: 200, bottom: 100),
    ];
    final stale = <TerrainSourceShapeDef>[
      _rectangle('ground', left: 0, top: 22, right: 200, bottom: 100),
    ];
    final chunk = _chunk(current);

    final result = policy.apply(
      chunk: chunk,
      commit: _commit(before: stale, after: current),
    );

    expect(result.accepted, isFalse);
    expect(result.changed, isFalse);
    expect(result.chunk, same(chunk));
    expect(result.issues.single.code, 'chunk_polygon_commit_stale');
  });

  test('closed owner bounds reject without changing owner', () {
    final before = <TerrainSourceShapeDef>[
      _rectangle('ground', left: 0, top: 20, right: 200, bottom: 100),
    ];
    final outside = <TerrainSourceShapeDef>[
      _rectangle('ground', left: -2, top: 20, right: 200, bottom: 100),
    ];
    final chunk = _chunk(before);

    final result = policy.apply(
      chunk: chunk,
      commit: _commit(before: before, after: outside),
    );

    expect(result.accepted, isFalse);
    expect(result.chunk, same(chunk));
    expect(
      result.issues.map((issue) => issue.code),
      contains('chunk_collision_shape_out_of_bounds'),
    );
  });

  test('Core occupied-area overlap rejects without changing owner', () {
    final before = <TerrainSourceShapeDef>[
      _rectangle('ground', left: 0, top: 20, right: 200, bottom: 100),
    ];
    final overlap = <TerrainSourceShapeDef>[
      _rectangle('ground_a', left: 0, top: 20, right: 120, bottom: 100),
      _rectangle('ground_b', left: 80, top: 20, right: 200, bottom: 100),
    ];
    final chunk = _chunk(before);

    final result = policy.apply(
      chunk: chunk,
      commit: _commit(before: before, after: overlap),
    );

    expect(result.accepted, isFalse);
    expect(result.chunk, same(chunk));
    expect(
      result.issues.map((issue) => issue.code),
      contains('polygon_area_overlap'),
    );
  });

  test('vertex soft-target warning does not reject a chunk commit', () {
    final before = <TerrainSourceShapeDef>[
      _rectangle('ground', left: 0, top: 20, right: 200, bottom: 100),
    ];
    final after = <TerrainSourceShapeDef>[
      _strip(
        'ground',
        vertexCount: TerrainAuthoringCapacityTargets.verticesPerShape + 1,
      ),
    ];

    final result = policy.apply(
      chunk: _chunk(before),
      commit: _commit(before: before, after: after),
      sourcePath: 'chunks/target.json',
    );

    expect(result.accepted, isTrue);
    expect(result.changed, isTrue);
    final warning = result.issues.singleWhere(
      (issue) => issue.code == 'polygon_vertex_soft_target_exceeded',
    );
    expect(warning.severity, ValidationSeverity.warning);
    expect(warning.ownerKey, 'forest_target');
    expect(warning.shapeId, 'ground');
    expect(warning.message, contains('25 vertices'));
  });

  test('invalid identity and noncanonical order reject deterministically', () {
    final before = <TerrainSourceShapeDef>[
      _rectangle('ground', left: 0, top: 20, right: 200, bottom: 100),
    ];
    final chunk = _chunk(before);
    final duplicate = <TerrainSourceShapeDef>[
      _rectangle('ground', left: 0, top: 20, right: 100, bottom: 100),
      _rectangle('ground', left: 100, top: 20, right: 200, bottom: 100),
    ];
    final unordered = <TerrainSourceShapeDef>[
      _rectangle('ground_b', left: 100, top: 20, right: 200, bottom: 100),
      _rectangle('ground_a', left: 0, top: 20, right: 100, bottom: 100),
    ];

    final duplicateResult = policy.apply(
      chunk: chunk,
      commit: _commit(before: before, after: duplicate),
    );
    final unorderedResult = policy.apply(
      chunk: chunk,
      commit: _commit(before: before, after: unordered),
    );

    expect(duplicateResult.chunk, same(chunk));
    expect(
      duplicateResult.issues.single.code,
      'chunk_collision_shape_identity_invalid',
    );
    expect(unorderedResult.chunk, same(chunk));
    expect(
      unorderedResult.issues.single.code,
      'chunk_collision_shape_order_noncanonical',
    );
  });
}

ChunkV2FileData _chunk(Iterable<TerrainSourceShapeDef> collisionShapes) =>
    ChunkV2FileData(
      chunkKey: 'forest_target',
      id: 'forest_target',
      revision: 7,
      status: chunkStatusActive,
      levelId: 'forest',
      tileSize: 16,
      width: 100,
      height: 50,
      difficulty: chunkDifficultyNormal,
      assemblyGroupId: defaultChunkAssemblyGroupId,
      tags: const <String>['forest'],
      tileLayers: const <TileLayerDef>[],
      prefabs: const <PlacedPrefabDef>[],
      markers: const <PlacedMarkerDef>[],
      groundBandZIndex: 0,
      collisionShapes: collisionShapes,
    );

TerrainPolygonInteractionCommit _commit({
  required Iterable<TerrainSourceShapeDef> before,
  required Iterable<TerrainSourceShapeDef> after,
}) => TerrainPolygonInteractionCommit(
  beforeShapes: before,
  afterShapes: after,
  beforeSelection: null,
  afterSelection: null,
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

TerrainSourceShapeDef _strip(String shapeId, {required int vertexCount}) {
  final topCount = (vertexCount + 1) ~/ 2;
  final bottomCount = vertexCount - topCount;
  return TerrainSourceShapeDef(
    shapeId: shapeId,
    vertices: <TerrainSourceVertexDef>[
      for (var x = 0; x < topCount; x += 1)
        TerrainSourceVertexDef(
          xHalfPixels: x * 2,
          yHalfPixels: 20 + (x.isEven ? 0 : 2),
        ),
      for (var x = bottomCount - 1; x >= 0; x -= 1)
        TerrainSourceVertexDef(
          xHalfPixels: x * 2,
          yHalfPixels: 40 + (x.isEven ? 0 : 2),
        ),
    ],
  );
}
