import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';

import '../../tool/polygon_terrain_compilation.dart';
import '../../tool/polygon_terrain_legacy_projection.dart';
import '../../tool/polygon_terrain_source.dart';

void main() {
  test('migrated bottom bands derive exact flat ground gaps', () {
    final result = projectPolygonTerrainToLegacy(
      compiled: _compile(<PolygonTerrainShapeSource>[
        _rectangle('ground_002', left: 64, top: 32, right: 96, bottom: 64),
        _rectangle('ground_001', left: 0, top: 32, right: 32, bottom: 64),
      ]),
      legacyGroundTopY: 32,
    );

    expect(result.issues, isEmpty);
    expect(result.projection!.rectangles, isEmpty);
    expect(result.projection!.groundGaps, hasLength(1));
    expect(result.projection!.groundGaps.single.gapId, 'gap_1');
    expect(result.projection!.groundGaps.single.x, 32);
    expect(result.projection!.groundGaps.single.width, 32);
  });

  test(
    'concave solid decomposes into canonical non-overlapping rectangles',
    () {
      final result = projectPolygonTerrainToLegacy(
        compiled: _compile(<PolygonTerrainShapeSource>[
          _shape('obstacle', const <(int, int)>[
            (0, 0),
            (32, 0),
            (32, 16),
            (16, 16),
            (16, 32),
            (0, 32),
          ]),
        ]),
        legacyGroundTopY: 48,
      );

      expect(result.issues, isEmpty);
      expect(
        result.projection!.rectangles.map(
          (rectangle) => (
            rectangle.x,
            rectangle.topY,
            rectangle.width,
            rectangle.height,
            rectangle.collisionMode,
          ),
        ),
        <(int, int, int, int, TerrainCollisionMode)>[
          (0, 0, 32, 16, TerrainCollisionMode.solid),
          (0, 16, 16, 16, TerrainCollisionMode.solid),
        ],
      );
      expect(result.projection!.snappedSolidArea, BigInt.from(768));
      expect(result.projection!.groundGaps.single.width, 96);
    },
  );

  test('legacy snap matches integer 16-pixel rectangle behavior', () {
    final result = projectPolygonTerrainToLegacy(
      compiled: _compile(<PolygonTerrainShapeSource>[
        _rectangle('obstacle', left: 10, top: 10, right: 15, bottom: 15),
      ]),
      legacyGroundTopY: 48,
    );

    expect(result.issues, isEmpty);
    final rectangle = result.projection!.rectangles.single;
    expect(
      (rectangle.x, rectangle.topY, rectangle.width, rectangle.height),
      (16, 16, 16, 16),
    );
    expect(result.projection!.snappedSolidArea, BigInt.from(256));
  });

  test('diagonal solid fails instead of becoming its bounding rectangle', () {
    final result = projectPolygonTerrainToLegacy(
      compiled: _compile(<PolygonTerrainShapeSource>[
        _shape('slope', const <(int, int)>[(0, 0), (32, 16), (0, 32)]),
      ]),
      legacyGroundTopY: 48,
    );

    expect(result.projection, isNull);
    expect(result.issues.map((issue) => issue.code), <String>[
      'legacy_diagonal_edge',
      'legacy_diagonal_edge',
    ]);
  });

  test('one-way compatibility accepts only one non-overlapping rectangle', () {
    final accepted = projectPolygonTerrainToLegacy(
      compiled: _compile(<PolygonTerrainShapeSource>[
        _rectangle(
          'platform',
          left: 16,
          top: 16,
          right: 48,
          bottom: 32,
          mode: TerrainCollisionMode.oneWay,
        ),
      ]),
      legacyGroundTopY: 48,
    );
    final concave = projectPolygonTerrainToLegacy(
      compiled: _compile(<PolygonTerrainShapeSource>[
        _shape('platform', const <(int, int)>[
          (0, 0),
          (32, 0),
          (32, 16),
          (16, 16),
          (16, 32),
          (0, 32),
        ], mode: TerrainCollisionMode.oneWay),
      ]),
      legacyGroundTopY: 48,
    );
    final snapOverlap = projectPolygonTerrainToLegacy(
      compiled: _compile(<PolygonTerrainShapeSource>[
        _rectangle(
          'platform_a',
          left: 0,
          top: 0,
          right: 5,
          bottom: 5,
          mode: TerrainCollisionMode.oneWay,
        ),
        _rectangle(
          'platform_b',
          left: 6,
          top: 0,
          right: 11,
          bottom: 5,
          mode: TerrainCollisionMode.oneWay,
        ),
      ]),
      legacyGroundTopY: 48,
    );
    final mixedSnapOverlap = projectPolygonTerrainToLegacy(
      compiled: _compile(<PolygonTerrainShapeSource>[
        _rectangle('solid', left: 0, top: 0, right: 5, bottom: 5),
        _rectangle(
          'platform',
          left: 6,
          top: 0,
          right: 11,
          bottom: 5,
          mode: TerrainCollisionMode.oneWay,
        ),
      ]),
      legacyGroundTopY: 48,
    );

    expect(accepted.issues, isEmpty);
    expect(
      accepted.projection!.rectangles.single.collisionMode,
      TerrainCollisionMode.oneWay,
    );
    expect(concave.projection, isNull);
    expect(concave.issues.single.code, 'legacy_one_way_shape_unrepresentable');
    expect(snapOverlap.projection, isNull);
    expect(snapOverlap.issues.single.code, 'legacy_one_way_snap_overlap');
    expect(mixedSnapOverlap.projection, isNull);
    expect(
      mixedSnapOverlap.issues.single.code,
      'legacy_mixed_mode_snap_overlap',
    );
  });

  test('projection is invariant under source input order', () {
    final forward = <PolygonTerrainShapeSource>[
      _rectangle('ground_001', left: 0, top: 32, right: 32, bottom: 64),
      _rectangle('ground_002', left: 64, top: 32, right: 96, bottom: 64),
      _rectangle('obstacle', left: 32, top: 0, right: 48, bottom: 16),
    ];
    final first = projectPolygonTerrainToLegacy(
      compiled: _compile(forward),
      legacyGroundTopY: 32,
    ).projection!;
    final second = projectPolygonTerrainToLegacy(
      compiled: _compile(forward.reversed),
      legacyGroundTopY: 32,
    ).projection!;

    expect(_records(second), _records(first));
  });

  test('empty terrain projects to an exact full-width no-ground gap', () {
    final result = projectPolygonTerrainToLegacy(
      compiled: _compile(const <PolygonTerrainShapeSource>[], chunkWidth: 100),
      legacyGroundTopY: 32,
    );

    expect(result.issues, isEmpty);
    expect(result.projection!.rectangles, isEmpty);
    expect(result.projection!.groundGaps, hasLength(1));
    expect(result.projection!.groundGaps.single.x, 0);
    expect(result.projection!.groundGaps.single.width, 100);
  });
}

PolygonTerrainCompiledChunk _compile(
  Iterable<PolygonTerrainShapeSource> shapes, {
  int chunkWidth = 96,
}) {
  final chunk = PolygonTerrainChunkSource(
    chunkKey: 'projection_chunk',
    id: 'projection_chunk',
    revision: 1,
    status: 'active',
    levelId: 'forest',
    tileSize: 16,
    width: chunkWidth,
    height: 64,
    difficulty: 'normal',
    assemblyGroupId: 'default',
    placements: const <PolygonTerrainPlacementSource>[],
    collisionShapes: shapes,
  );
  final result = compilePolygonTerrainChunk(
    chunk: chunk,
    prefabSources: PolygonTerrainPrefabSourceSet(
      const <PolygonTerrainPrefabSource>[],
    ),
    sourcePath: 'chunks/forest/projection_chunk.json',
  );
  expect(result.issues, isEmpty);
  return result.compiled!;
}

PolygonTerrainShapeSource _rectangle(
  String shapeId, {
  required int left,
  required int top,
  required int right,
  required int bottom,
  TerrainCollisionMode mode = TerrainCollisionMode.solid,
}) => _shape(shapeId, <(int, int)>[
  (left, top),
  (right, top),
  (right, bottom),
  (left, bottom),
], mode: mode);

PolygonTerrainShapeSource _shape(
  String shapeId,
  Iterable<(int, int)> vertices, {
  TerrainCollisionMode mode = TerrainCollisionMode.solid,
}) => PolygonTerrainShapeSource(
  shapeId: shapeId,
  vertices: vertices.map(
    (point) => PolygonTerrainSourcePoint(
      xHalfPixels: point.$1 * 2,
      yHalfPixels: point.$2 * 2,
    ),
  ),
  collisionMode: mode,
  surfaceKind: null,
  materialKey: null,
);

List<Object> _records(PolygonTerrainLegacyProjection projection) => <Object>[
  for (final rectangle in projection.rectangles)
    (
      rectangle.x,
      rectangle.topY,
      rectangle.width,
      rectangle.height,
      rectangle.collisionMode,
    ),
  for (final gap in projection.groundGaps) (gap.gapId, gap.x, gap.width),
  projection.snappedSolidArea,
];
