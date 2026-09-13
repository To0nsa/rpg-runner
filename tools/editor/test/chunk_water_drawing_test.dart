import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/terrain/water_region.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_water_drawing.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_codec.dart';
import 'package:runner_editor/src/chunks/chunk_v2_collision_expansion.dart';
import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_data.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';

void main() {
  late ChunkV2FileData chunk;
  setUp(() {
    chunk = ChunkV2FileCodec.decode(
      File('../../docs/examples/water_pool_chunk.json').readAsStringSync(),
    ).copyWith(collisionShapes: [], waterRegions: []);
  });

  ChunkWaterDrawing begin({
    Offset start = const Offset(11, 19),
    bool grid = false,
    bool neighbors = false,
    double zoom = 1,
  }) => ChunkWaterDrawing()
    ..begin(
      chunk: chunk,
      pointer: 1,
      worldPoint: start,
      materialKey: 'biome_water',
      snapToGrid: grid,
      snapToNeighbors: neighbors,
      zoom: zoom,
    );

  test('reverse drag uses whole pixels and one revision-checked commit', () {
    final drawing = begin(start: const Offset(90.6, 70.4));
    drawing.update(pointer: 2, worldPoint: Offset.zero, zoom: 1);
    expect(drawing.bounds, const Rect.fromLTRB(91, 70, 91, 70));
    drawing.update(pointer: 1, worldPoint: const Offset(20.3, 15.6), zoom: 1);
    expect(drawing.buildCommit(), isNull, reason: 'Pointer is still down.');
    drawing.finish(pointer: 1, worldPoint: const Offset(20.3, 15.6), zoom: 1);
    final candidate = drawing.candidate!;
    expect(
      [candidate.x, candidate.y, candidate.width, candidate.height],
      [20, 16, 71, 54],
    );
    expect(candidate.materialKey, 'biome_water');
    final commit = drawing.buildCommit()!;
    final applied = commit.apply(chunk);
    expect(applied.revision, chunk.revision + 1);
    expect(applied.waterRegions, [candidate]);
    expect(commit.apply(applied), same(applied));
    expect(drawing.cancel(), isTrue);
    expect(drawing.bounds, isNull);
    expect(drawing.buildCommit(), isNull);
    expect(drawing.cancel(), isFalse);
  });

  test(
    'grid snaps both corners and clamps to the last in-bounds grid line',
    () {
      chunk = chunk.copyWith(width: 99, height: 55, tileSize: 16);
      final drawing = begin(start: const Offset(-10, 9), grid: true);
      drawing.finish(pointer: 1, worldPoint: const Offset(110, 60), zoom: 1);
      expect(drawing.bounds, const Rect.fromLTRB(0, 16, 96, 48));
      expect(drawing.buildCommit(), isNotNull);
    },
  );

  test(
    'exact neighboring corners take priority over the grid at every zoom',
    () {
      chunk = chunk.copyWith(
        collisionShapes: [
          TerrainSourceShapeDef(
            shapeId: 'bank',
            vertices: const [
              TerrainSourceVertexDef(xHalfPixels: 42, yHalfPixels: 42),
              TerrainSourceVertexDef(xHalfPixels: 60, yHalfPixels: 42),
              TerrainSourceVertexDef(xHalfPixels: 60, yHalfPixels: 60),
            ],
          ),
        ],
      );
      for (final zoom in [.5, 1.0, 4.0]) {
        final drawing = begin(
          start: Offset(21 - 7 / zoom, 21),
          neighbors: true,
          grid: true,
          zoom: zoom,
        );
        expect(drawing.snappedNeighbor, const Offset(21, 21));
        expect(drawing.bounds!.topLeft, const Offset(21, 21));
        drawing.finish(
          pointer: 1,
          worldPoint: const Offset(70, 70),
          zoom: zoom,
        );
        expect(drawing.bounds, const Rect.fromLTRB(21, 21, 64, 64));
        final outside = begin(
          start: Offset(21 - 9 / zoom, 21),
          neighbors: true,
          zoom: zoom,
        );
        expect(outside.snappedNeighbor, isNull);
      }
    },
  );

  test(
    'water corners snap exactly; touching is valid and overlap is rejected',
    () {
      chunk = chunk.copyWith(
        waterRegions: [
          WaterRegionData(
            id: 'water_1',
            x: 21,
            y: 21,
            width: 40,
            height: 40,
            materialKey: 'biome_water',
          ),
        ],
      );
      final drawing = begin(start: const Offset(63, 22), neighbors: true);
      expect(drawing.snappedNeighbor, const Offset(61, 21));
      drawing.finish(pointer: 1, worldPoint: const Offset(90, 61), zoom: 1);
      expect(drawing.candidate!.id, 'water_2');
      expect(drawing.buildCommit(), isNotNull);
      final overlap = begin(start: const Offset(30, 30));
      overlap.finish(pointer: 1, worldPoint: const Offset(80, 80), zoom: 1);
      expect(overlap.candidate, isNotNull);
      expect(overlap.error, contains('overlap'));
      expect(overlap.buildCommit(), isNull);
    },
  );

  test('placed prefab snapping uses expanded world vertices after scale', () {
    chunk = chunk.copyWith(
      prefabs: const [
        PlacedPrefabDef(
          prefabId: 'rock',
          prefabKey: 'rock',
          x: 91,
          y: 53,
          scale: .5,
        ),
      ],
    );
    final expansion = expandChunkV2Collision(
      chunk: chunk,
      sourcePath: 'water_test.json',
      prefabs: [
        PrefabV3Def(
          prefabKey: 'rock',
          id: 'rock',
          revision: 1,
          status: PrefabStatus.active,
          kind: PrefabKind.obstacle,
          visualSource: const PrefabVisualSource.atlasSlice('rock'),
          anchorXPx: 0,
          anchorYPx: 0,
          tags: const [],
          collisionShapes: [
            TerrainSourceShapeDef(
              shapeId: 'body',
              vertices: const [
                TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 0),
                TerrainSourceVertexDef(xHalfPixels: 80, yHalfPixels: 0),
                TerrainSourceVertexDef(xHalfPixels: 80, yHalfPixels: 80),
                TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 80),
              ],
            ),
          ],
        ),
      ],
    ).expansion;
    expect(expansion, isNotNull);
    final drawing = ChunkWaterDrawing()
      ..begin(
        chunk: chunk,
        pointer: 1,
        worldPoint: const Offset(110, 74),
        materialKey: 'biome_water',
        snapToGrid: true,
        snapToNeighbors: true,
        zoom: 2,
        expansion: expansion,
      );
    expect(drawing.snappedNeighbor, const Offset(111, 73));
    drawing.finish(pointer: 1, worldPoint: const Offset(160, 100), zoom: 2);
    expect(drawing.candidate!.x, 111);
    expect(drawing.candidate!.y, 73);
    expect(drawing.buildCommit(), isNotNull);
  });

  test(
    'zero area and fractional neighbor vertices cannot produce invalid source',
    () {
      chunk = chunk.copyWith(
        collisionShapes: [
          TerrainSourceShapeDef(
            shapeId: 'bank',
            vertices: const [
              TerrainSourceVertexDef(xHalfPixels: 41, yHalfPixels: 41),
              TerrainSourceVertexDef(xHalfPixels: 81, yHalfPixels: 41),
              TerrainSourceVertexDef(xHalfPixels: 81, yHalfPixels: 81),
            ],
          ),
        ],
      );
      final drawing = begin(start: const Offset(20.5, 20.5), neighbors: true);
      expect(drawing.snappedNeighbor, isNull);
      drawing.finish(pointer: 1, worldPoint: const Offset(20.5, 20.5), zoom: 1);
      expect(drawing.candidate, isNull);
      expect(drawing.error, isNotNull);
      expect(drawing.buildCommit(), isNull);
    },
  );
}
