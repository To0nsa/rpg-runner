import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/chunks/chunk_v2_collision_expansion.dart';
import 'package:runner_editor/src/chunks/chunk_v2_compiled_edge_inspection.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_data.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_physics_text.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';

void main() {
  test('formats physics and slope fixed-point units exactly', () {
    expect(TerrainPhysicsText.formatTicks(1), '0.0009765625');
    expect(TerrainPhysicsText.formatTicks(-513), '-0.5009765625');
    expect(TerrainPhysicsText.formatSlopeAngleUnits(60 * 1024), '60');
    expect(TerrainPhysicsText.formatSlopeAngleUnits(512), '0.5');
  });

  test('hit testing selects nearest Core edge and canonical corner tie', () {
    final expansion = _expansion();

    final top = hitTestChunkV2CompiledEdge(
      expansion: expansion,
      worldX: 5,
      worldY: 0.25,
      radiusWorld: 1,
    );
    final corner = hitTestChunkV2CompiledEdge(
      expansion: expansion,
      worldX: 0,
      worldY: 0,
      radiusWorld: 0,
    );
    final outside = hitTestChunkV2CompiledEdge(
      expansion: expansion,
      worldX: 50,
      worldY: 50,
      radiusWorld: 1,
    );

    expect(top?.localEdgeIndex, 0);
    expect(corner?.localEdgeIndex, 0);
    expect(outside, isNull);
  });

  test('inspection reads Core traversal angle and exact edge facts', () {
    final expansion = _expansion();
    final verticalId = expansion.geometry.edges
        .singleWhere((edge) => edge.dxTicks == 0 && edge.dyTicks > 0)
        .id;

    final inspection = inspectChunkV2CompiledEdge(expansion, verticalId)!;

    expect(inspection.edge.id, verticalId);
    expect(inspection.absoluteSlopeAngleUnits, 90 * 1024);
    expect(inspection.edge.id.placementKey, isNull);
    expect(inspectChunkV2CompiledEdge(expansion, null), isNull);
  });

  test('hit testing rejects malformed display input', () {
    final expansion = _expansion();
    expect(
      () => hitTestChunkV2CompiledEdge(
        expansion: expansion,
        worldX: double.nan,
        worldY: 0,
        radiusWorld: 1,
      ),
      throwsArgumentError,
    );
    expect(
      () => hitTestChunkV2CompiledEdge(
        expansion: expansion,
        worldX: 0,
        worldY: 0,
        radiusWorld: -1,
      ),
      throwsArgumentError,
    );
  });
}

ChunkV2CollisionExpansion _expansion() => expandChunkV2Collision(
  chunk: ChunkV2FileData(
    chunkKey: 'forest_test',
    id: 'forest_test',
    revision: 1,
    status: chunkStatusActive,
    levelId: 'forest',
    tileSize: 16,
    width: 100,
    height: 100,
    difficulty: chunkDifficultyNormal,
    assemblyGroupId: defaultChunkAssemblyGroupId,
    tags: const <String>[],
    tileLayers: const <TileLayerDef>[],
    prefabs: const <PlacedPrefabDef>[],
    markers: const <PlacedMarkerDef>[],
    groundBandZIndex: 0,
    collisionShapes: <TerrainSourceShapeDef>[
      TerrainSourceShapeDef(
        shapeId: 'ground_001',
        vertices: const <TerrainSourceVertexDef>[
          TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 0),
          TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 0),
          TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 20),
          TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 20),
        ],
      ),
    ],
  ),
  prefabs: const [],
  sourcePath: 'chunks/forest/test.json',
).expansion!;
