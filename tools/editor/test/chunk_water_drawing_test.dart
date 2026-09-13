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

  group('selected water corner resizing', () {
    late WaterRegionData region;
    setUp(() {
      region = WaterRegionData(
        id: 'pool',
        x: 21,
        y: 31,
        width: 40,
        height: 50,
        materialKey: 'biome_water',
      );
      chunk = chunk.copyWith(waterRegions: [region]);
    });

    ChunkWaterDrawing resize({
      ChunkWaterCorner corner = ChunkWaterCorner.bottomRight,
      Offset? pointerStart,
      bool grid = false,
      bool neighbors = false,
    }) => ChunkWaterDrawing()
      ..beginResize(
        chunk: chunk,
        region: region,
        corner: corner,
        pointer: 1,
        worldPoint: pointerStart ?? corner.position(waterRegionBounds(region)),
        snapToGrid: grid,
        snapToNeighbors: neighbors,
      );

    test('hit radius stays in canvas pixels and picks the nearest corner', () {
      for (final zoom in [.5, 1.0, 4.0]) {
        for (final corner in ChunkWaterCorner.values) {
          final point = corner.position(waterRegionBounds(region));
          expect(
            hitTestChunkWaterCorner(
              region: region,
              worldPoint: point + Offset(9 / zoom, 0),
              zoom: zoom,
            ),
            corner,
          );
        }
        expect(
          hitTestChunkWaterCorner(
            region: region,
            worldPoint: Offset(61 + 11 / zoom, 81),
            zoom: zoom,
          ),
          isNull,
        );
      }
      expect(
        hitTestChunkWaterCorner(
          region: region,
          worldPoint: const Offset(57, 79),
          zoom: 1,
        ),
        ChunkWaterCorner.bottomRight,
      );
    });

    for (final corner in ChunkWaterCorner.values) {
      test('$corner expands and shrinks with the opposite corner fixed', () {
        final rect = waterRegionBounds(region);
        final anchor = corner.opposite.position(rect);
        final start = corner.position(rect);
        final direction = Offset(
          (start.dx - anchor.dx).sign,
          (start.dy - anchor.dy).sign,
        );
        for (final delta in [10.0, -10.0]) {
          final drawing = resize(corner: corner);
          final target = start + direction * delta;
          drawing.update(pointer: 2, worldPoint: Offset.zero, zoom: 1);
          expect(drawing.bounds, rect);
          drawing.update(pointer: 1, worldPoint: target, zoom: 1);
          expect(drawing.bounds, Rect.fromPoints(anchor, target));
          expect(drawing.buildCommit(), isNull);
          expect(chunk.waterRegions.single, region);
          expect(drawing.previewRegions, hasLength(1));
          drawing.finish(pointer: 1, worldPoint: target, zoom: 1);
          final commit = drawing.buildCommit()!;
          final result = commit.apply(chunk);
          expect(result.revision, chunk.revision + 1);
          expect(result.waterRegions, [drawing.candidate]);
          expect(result.waterRegions.single.id, region.id);
          expect(result.waterRegions.single.materialKey, region.materialKey);
          expect(commit.apply(result), same(result), reason: 'Stale revision.');
        }
      });
    }

    test(
      'a grab offset, click and return drag do not snap the original bounds',
      () {
        final drawing = resize(pointerStart: const Offset(65, 83), grid: true);
        expect(drawing.bounds, waterRegionBounds(region));
        drawing.update(pointer: 1, worldPoint: const Offset(82, 96), zoom: 1);
        expect(drawing.bounds, const Rect.fromLTRB(21, 31, 80, 96));
        drawing.finish(pointer: 1, worldPoint: const Offset(65, 83), zoom: 1);
        expect(drawing.bounds, waterRegionBounds(region));
        expect(drawing.buildCommit(), isNull);
        final click = resize(pointerStart: const Offset(65, 83), grid: true);
        click.finish(pointer: 1, worldPoint: const Offset(65, 83), zoom: 1);
        expect(click.buildCommit(), isNull);
      },
    );

    test('snapping ignores its own corners and keeps an off-grid anchor', () {
      final free = resize(neighbors: true);
      free.finish(pointer: 1, worldPoint: const Offset(63, 82), zoom: 1);
      expect(free.snappedNeighbor, isNull);
      expect(free.bounds, const Rect.fromLTRB(21, 31, 63, 82));
      final grid = resize(grid: true);
      grid.finish(pointer: 1, worldPoint: const Offset(92, 108), zoom: 1);
      expect(grid.bounds, const Rect.fromLTRB(21, 31, 96, 112));
      final crossed = resize();
      crossed.finish(pointer: 1, worldPoint: const Offset(11, 21), zoom: 1);
      expect(crossed.bounds, const Rect.fromLTRB(11, 21, 21, 31));
      expect(crossed.buildCommit(), isNotNull);
    });

    test(
      'neighbor snapping beats grid; overlap and zero area cannot commit',
      () {
        final other = WaterRegionData(
          id: 'other',
          x: 93,
          y: 81,
          width: 20,
          height: 20,
          materialKey: 'biome_water',
        );
        chunk = chunk.copyWith(waterRegions: [other, region]);
        final drawing = resize(grid: true, neighbors: true);
        drawing.finish(pointer: 1, worldPoint: const Offset(91, 83), zoom: 1);
        expect(drawing.snappedNeighbor, const Offset(93, 81));
        expect(drawing.bounds, const Rect.fromLTRB(21, 31, 93, 81));
        expect(drawing.buildCommit()!.apply(chunk).waterRegions, hasLength(2));
        final invalid = resize();
        invalid.finish(pointer: 1, worldPoint: const Offset(100, 90), zoom: 1);
        expect(invalid.error, contains('overlap'));
        expect(invalid.previewRegions, isNull);
        expect(invalid.buildCommit(), isNull);
        expect(invalid.cancel(), isTrue);
        expect(invalid.isResizing, isFalse);
        expect(invalid.bounds, isNull);
        final zero = resize();
        zero.finish(pointer: 1, worldPoint: const Offset(21, 90), zoom: 1);
        expect(zero.candidate, isNull);
        expect(zero.buildCommit(), isNull);
      },
    );
  });

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
    'exact draft dimensions retain the chosen name without writing source',
    () {
      final drawing = ChunkWaterDrawing()
        ..begin(
          chunk: chunk,
          pointer: 1,
          worldPoint: const Offset(10, 10),
          materialKey: 'biome_water',
          regionId: 'named_pool',
          snapToGrid: false,
          snapToNeighbors: false,
          zoom: 1,
        );
      drawing.finish(pointer: 1, worldPoint: const Offset(30, 30), zoom: 1);
      expect(
        drawing.editDimensions(
          xHalfPixels: 24,
          bottomYHalfPixels: 80,
          widthHalfPixels: 48,
          heightHalfPixels: 32,
        ),
        isTrue,
      );
      expect(drawing.bounds, const Rect.fromLTRB(12, 24, 36, 40));
      expect(drawing.candidate!.id, 'named_pool');
      expect(chunk.waterRegions, isEmpty);
      expect(
        drawing.editDimensions(
          xHalfPixels: -2,
          bottomYHalfPixels: 80,
          widthHalfPixels: 48,
          heightHalfPixels: 32,
        ),
        isFalse,
      );
      expect(drawing.buildCommit(), isNull);
      expect(
        drawing.editDimensions(
          xHalfPixels: 24,
          bottomYHalfPixels: 80,
          widthHalfPixels: 48,
          heightHalfPixels: 32,
        ),
        isTrue,
      );
      expect(
        drawing.buildCommit()!.apply(chunk).waterRegions.single.id,
        'named_pool',
      );
    },
  );

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
