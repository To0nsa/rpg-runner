import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/collision/terrain/terrain_polygon_overlap.dart';
import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/chunks/chunk_prefab_surface_snap.dart';
import 'package:runner_editor/src/chunks/chunk_v2_collision_expansion.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_data.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';

void main() {
  test(
    'snaps a whole-pixel support edge to direct terrain without overlap',
    () {
      final prefab = _prefab();
      final chunk = _chunk();
      final context = _context(chunk, prefab);

      final result = ChunkPrefabSurfaceSnap.resolve(
        placement: const PlacedPrefabDef(
          prefabId: 'crate',
          prefabKey: 'crate',
          x: 50,
          y: 96,
          snapToGrid: false,
        ),
        prefab: prefab,
        context: context,
        snapRadiusWorld: 8,
        chunkWidth: chunk.width,
        chunkHeight: chunk.height,
      );

      expect(result.snapped, isTrue);
      expect(result.placement.y, 100);
      expect(result.targetEdge, isNotNull);

      final accepted = expandChunkV2Collision(
        chunk: chunk.copyWith(prefabs: <PlacedPrefabDef>[result.placement]),
        prefabs: <PrefabV3Def>[prefab],
        sourcePath: 'chunk.json',
      );
      expect(accepted.expansion, isNotNull);
      expect(
        accepted.issues.where((issue) => issue.code == 'polygon_area_overlap'),
        isEmpty,
      );

      final penetrating = expandChunkV2Collision(
        chunk: chunk.copyWith(
          prefabs: <PlacedPrefabDef>[result.placement.copyWith(y: 101)],
        ),
        prefabs: <PrefabV3Def>[prefab],
        sourcePath: 'chunk.json',
      );
      expect(
        penetrating.issues.any((issue) => issue.code == 'polygon_area_overlap'),
        isTrue,
      );
    },
  );

  test('rejects a contact proposal that overlaps another collision loop', () {
    final prefab = _prefab();
    final chunk = _chunk(
      collisionShapes: <TerrainSourceShapeDef>[
        _rectangle('ground', 0, 100, 320, 180),
        _rectangle('blocker', 42, 70, 58, 95),
      ],
    );

    final context = _context(chunk, prefab);
    final result = ChunkPrefabSurfaceSnap.resolve(
      placement: const PlacedPrefabDef(
        prefabId: 'crate',
        prefabKey: 'crate',
        x: 50,
        y: 96,
        snapToGrid: false,
      ),
      prefab: prefab,
      context: context,
      snapRadiusWorld: 8,
      chunkWidth: chunk.width,
      chunkHeight: chunk.height,
    );

    expect(
      context.obstacles.map((polygon) => polygon.identity.shapeId),
      containsAll(<String>['ground', 'blocker']),
    );
    expect(
      TerrainPolygonOverlap.physicsLoops(
        result.collisionLoops.single,
        context.obstacles
            .singleWhere((polygon) => polygon.identity.shapeId == 'blocker')
            .vertices,
      ),
      isTrue,
    );
    expect(result.snapped, isFalse);
    expect(result.status, ChunkPrefabSurfaceSnapStatus.noNearbyValidContact);
    expect(result.placement.y, 96);
  });

  test('move snapshot excludes only the captured source placement', () {
    final prefab = _prefab();
    final original = const PlacedPrefabDef(
      prefabId: 'crate',
      prefabKey: 'crate',
      x: 50,
      y: 100,
      snapToGrid: false,
    );
    final chunk = _chunk().copyWith(prefabs: <PlacedPrefabDef>[original]);
    final selection = buildChunkPlacedPrefabSelections(chunk.prefabs).single;
    final expansion = expandChunkV2Collision(
      chunk: chunk,
      prefabs: <PrefabV3Def>[prefab],
      sourcePath: 'chunk.json',
    ).expansion!;
    final context = ChunkPrefabSurfaceSnapContext.fromGeometry(
      geometry: expansion.geometry,
      excludedPlacementKey: selection.selectionKey,
    );

    final result = ChunkPrefabSurfaceSnap.resolve(
      placement: original.copyWith(y: 96),
      prefab: prefab,
      context: context,
      snapRadiusWorld: 8,
      chunkWidth: chunk.width,
      chunkHeight: chunk.height,
    );

    expect(result.snapped, isTrue);
    expect(result.placement.x, original.x);
    expect(result.placement.y, original.y);
    expect(
      context.obstacles.any(
        (polygon) => polygon.identity.placementKey == selection.selectionKey,
      ),
      isFalse,
    );
    expect(
      context.obstacles.any((polygon) => polygon.identity.placementKey == null),
      isTrue,
    );
  });

  test('offers only scales with a whole-pixel transformed support height', () {
    final halfPixelSupport = _prefab(
      collisionShapes: <TerrainSourceShapeDef>[
        TerrainSourceShapeDef(
          shapeId: 'body',
          vertices: const <TerrainSourceVertexDef>[
            TerrainSourceVertexDef(xHalfPixels: -20, yHalfPixels: -39),
            TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: -39),
            TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 1),
            TerrainSourceVertexDef(xHalfPixels: -20, yHalfPixels: 1),
          ],
        ),
      ],
    );

    expect(ChunkPrefabSurfaceSnap.compatibleScales(halfPixelSupport), <double>[
      2.0,
    ]);
    expect(
      ChunkPrefabSurfaceSnap.preferredCompatibleScale(halfPixelSupport),
      2.0,
    );
    expect(
      ChunkPrefabSurfaceSnap.isScaleCompatible(halfPixelSupport, 1.0),
      isFalse,
    );
  });

  test('explains when the collider has no lowest horizontal edge', () {
    final sloped = _prefab(
      collisionShapes: <TerrainSourceShapeDef>[
        TerrainSourceShapeDef(
          shapeId: 'body',
          vertices: const <TerrainSourceVertexDef>[
            TerrainSourceVertexDef(xHalfPixels: -20, yHalfPixels: -40),
            TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: -40),
            TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 0),
            TerrainSourceVertexDef(xHalfPixels: -20, yHalfPixels: -2),
          ],
        ),
      ],
    );
    final chunk = _chunk();

    final result = ChunkPrefabSurfaceSnap.resolve(
      placement: const PlacedPrefabDef(
        prefabId: 'crate',
        prefabKey: 'crate',
        x: 50,
        y: 96,
      ),
      prefab: sloped,
      context: _context(chunk, sloped),
      snapRadiusWorld: 8,
      chunkWidth: chunk.width,
      chunkHeight: chunk.height,
    );

    expect(result.status, ChunkPrefabSurfaceSnapStatus.noHorizontalSupport);
    expect(result.collisionLoops, hasLength(1));
    expect(result.message, contains('horizontal lowest edge'));
  });
}

ChunkPrefabSurfaceSnapContext _context(
  ChunkV2FileData chunk,
  PrefabV3Def prefab,
) {
  final expansion = expandChunkV2Collision(
    chunk: chunk,
    prefabs: <PrefabV3Def>[prefab],
    sourcePath: 'chunk.json',
  ).expansion;
  expect(expansion, isNotNull);
  return ChunkPrefabSurfaceSnapContext.fromGeometry(
    geometry: expansion!.geometry,
  );
}

PrefabV3Def _prefab({List<TerrainSourceShapeDef>? collisionShapes}) =>
    PrefabV3Def(
      prefabKey: 'crate',
      id: 'crate',
      revision: 1,
      status: PrefabStatus.active,
      kind: PrefabKind.obstacle,
      visualSource: const PrefabVisualSource.atlasSlice('crate'),
      anchorXPx: 10,
      anchorYPx: 20,
      collisionShapes:
          collisionShapes ??
          <TerrainSourceShapeDef>[_rectangle('body', -10, -20, 10, 0)],
      tags: const <String>[],
    );

ChunkV2FileData _chunk({List<TerrainSourceShapeDef>? collisionShapes}) =>
    ChunkV2FileData(
      chunkKey: 'forest',
      id: 'forest',
      revision: 1,
      status: chunkStatusActive,
      levelId: 'forest',
      tileSize: 16,
      width: 320,
      height: 180,
      difficulty: chunkDifficultyNormal,
      assemblyGroupId: defaultChunkAssemblyGroupId,
      tags: const <String>[],
      tileLayers: const <TileLayerDef>[],
      prefabs: const <PlacedPrefabDef>[],
      markers: const <PlacedMarkerDef>[],
      groundBandZIndex: 0,
      collisionShapes:
          collisionShapes ??
          <TerrainSourceShapeDef>[_rectangle('ground', 0, 100, 320, 180)],
    );

TerrainSourceShapeDef _rectangle(
  String id,
  int left,
  int top,
  int right,
  int bottom,
) => TerrainSourceShapeDef(
  shapeId: id,
  vertices: <TerrainSourceVertexDef>[
    TerrainSourceVertexDef(xHalfPixels: left * 2, yHalfPixels: top * 2),
    TerrainSourceVertexDef(xHalfPixels: right * 2, yHalfPixels: top * 2),
    TerrainSourceVertexDef(xHalfPixels: right * 2, yHalfPixels: bottom * 2),
    TerrainSourceVertexDef(xHalfPixels: left * 2, yHalfPixels: bottom * 2),
  ],
);
