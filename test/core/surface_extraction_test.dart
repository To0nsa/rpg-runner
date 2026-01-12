import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/collision/static_world_geometry.dart';
import 'package:rpg_runner/core/ecs/spatial/grid_index_2d.dart';
import 'package:rpg_runner/core/navigation/surface_extractor.dart';
import 'package:rpg_runner/core/navigation/types/surface_id.dart';
import 'package:rpg_runner/core/navigation/utils/surface_spatial_index.dart';

void main() {
  test('merges adjacent top segments across chunk boundaries', () {
    const geometry = StaticWorldGeometry(
      groundPlane: null,
      solids: <StaticSolid>[
        StaticSolid(
          minX: 0,
          minY: 100,
          maxX: 100,
          maxY: 116,
          sides: StaticSolid.sideTop,
          oneWayTop: true,
          chunkIndex: 0,
          localSolidIndex: 0,
        ),
        StaticSolid(
          minX: 100,
          minY: 100,
          maxX: 200,
          maxY: 116,
          sides: StaticSolid.sideTop,
          oneWayTop: true,
          chunkIndex: 1,
          localSolidIndex: 0,
        ),
      ],
    );

    final surfaces = SurfaceExtractor(mergeEps: 1e-6).extract(geometry);

    expect(surfaces, hasLength(1));
    final s = surfaces.single;
    expect(s.xMin, closeTo(0, 1e-9));
    expect(s.xMax, closeTo(200, 1e-9));
    expect(unpackChunkIndex(s.id), 0);
    expect(unpackLocalSolidIndex(s.id), 0);
  });

  test('ground plane splits around obstacle walls', () {
    const groundTopY = 200.0;
    const geometry = StaticWorldGeometry(
      groundPlane: StaticGroundPlane(topY: groundTopY),
      solids: <StaticSolid>[
        StaticSolid(
          minX: 40,
          minY: 160,
          maxX: 60,
          maxY: groundTopY,
          sides: StaticSolid.sideAll,
          oneWayTop: false,
          chunkIndex: 0,
          localSolidIndex: 0,
        ),
      ],
    );

    final extractor = SurfaceExtractor(groundPadding: 100.0, mergeEps: 1e-6);
    final surfaces = extractor.extract(geometry);

    final groundSurfaces =
        surfaces.where((s) => (s.yTop - groundTopY).abs() < 1e-9).toList();
    expect(groundSurfaces, hasLength(2));
    expect(groundSurfaces[0].xMax, closeTo(40, 1e-9));
    expect(groundSurfaces[1].xMin, closeTo(60, 1e-9));
  });

  test('ground segments preserve gaps between walkable ranges', () {
    const groundTopY = 200.0;
    const geometry = StaticWorldGeometry(
      groundPlane: StaticGroundPlane(topY: groundTopY),
      groundSegments: <StaticGroundSegment>[
        StaticGroundSegment(
          minX: 0,
          maxX: 120,
          topY: groundTopY,
          chunkIndex: 1,
          localSegmentIndex: 0,
        ),
        StaticGroundSegment(
          minX: 200,
          maxX: 320,
          topY: groundTopY,
          chunkIndex: 1,
          localSegmentIndex: 1,
        ),
      ],
      groundGaps: <StaticGroundGap>[
        StaticGroundGap(minX: 120, maxX: 200),
      ],
    );

    final extractor = SurfaceExtractor(mergeEps: 1e-6);
    final surfaces = extractor.extract(geometry);

    final groundSurfaces =
        surfaces.where((s) => (s.yTop - groundTopY).abs() < 1e-9).toList();
    expect(groundSurfaces, hasLength(2));
    expect(groundSurfaces[0].xMax, closeTo(120, 1e-9));
    expect(groundSurfaces[1].xMin, closeTo(200, 1e-9));
  });

  test('spatial index returns surfaces overlapping query AABB', () {
    const geometry = StaticWorldGeometry(
      groundPlane: null,
      solids: <StaticSolid>[
        StaticSolid(
          minX: 32,
          minY: 200,
          maxX: 96,
          maxY: 216,
          sides: StaticSolid.sideTop,
          oneWayTop: true,
          chunkIndex: 0,
          localSolidIndex: 0,
        ),
      ],
    );

    final surfaces = SurfaceExtractor().extract(geometry);
    final index = SurfaceSpatialIndex(index: GridIndex2D(cellSize: 64));
    index.rebuild(surfaces);

    final out = <int>[];
    index.queryAabb(
      minX: 40,
      minY: 199,
      maxX: 80,
      maxY: 201,
      outSurfaceIndices: out,
    );

    expect(out, hasLength(1));
    expect(out.first, 0);
  });
}
