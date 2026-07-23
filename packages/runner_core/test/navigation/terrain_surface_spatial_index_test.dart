import 'dart:math' as math;

import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_edge_id.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/navigation/terrain_surface_extractor.dart';
import 'package:runner_core/navigation/terrain_surface_query_buffer.dart';
import 'package:runner_core/navigation/terrain_surface_spatial_index.dart';
import 'package:runner_core/navigation/types/terrain_navigation_surface.dart';
import 'package:test/test.dart';

import '../fixtures/slopes_golden_fixture.dart';

void main() {
  test('multi-cell query deduplicates in canonical surface order', () {
    final set = _surfaceSet(<TerrainNavigationSurface>[
      _surface(0, -128, 0, 128, -64),
      _surface(1, -64, 64, 192, 0),
    ]);
    final index = TerrainSurfaceSpatialIndex(surfaceSet: set);
    final buffer = index.createQueryBuffer();

    final count = index.query(
      TerrainAabb(
        minX: -64 * terrainPhysicsTicksPerWorldUnit,
        minY: -64 * terrainPhysicsTicksPerWorldUnit,
        maxX: 128 * terrainPhysicsTicksPerWorldUnit,
        maxY: 64 * terrainPhysicsTicksPerWorldUnit,
      ),
      buffer,
    );

    expect(count, 2);
    expect(buffer.stats.rawCandidates, greaterThan(2));
    expect(buffer.stats.uniqueCandidates, 2);
    expect(buffer.surfaceAt(0, index.surfaces).id.localEdgeIndex, 0);
    expect(buffer.surfaceAt(1, index.surfaces).id.localEdgeIndex, 1);
  });

  test(
    'indexed segment bounds equal brute force for random sloped queries',
    () {
      final random = math.Random(314159);
      final surfaces = <TerrainNavigationSurface>[
        for (var index = 0; index < 240; index += 1)
          _surface(
            index,
            random.nextInt(1000) - 500,
            random.nextInt(1000) - 500,
            random.nextInt(80) + 1,
            random.nextInt(121) - 60,
            endpointIsDelta: true,
          ),
      ];
      final index = TerrainSurfaceSpatialIndex(
        surfaceSet: _surfaceSet(surfaces),
      );
      final buffer = index.createQueryBuffer();

      for (var queryIndex = 0; queryIndex < 100; queryIndex += 1) {
        final x = random.nextInt(900) - 450;
        final y = random.nextInt(900) - 450;
        final width = random.nextInt(100);
        final height = random.nextInt(100);
        final bounds = TerrainAabb(
          minX: x * terrainPhysicsTicksPerWorldUnit,
          minY: y * terrainPhysicsTicksPerWorldUnit,
          maxX: (x + width) * terrainPhysicsTicksPerWorldUnit,
          maxY: (y + height) * terrainPhysicsTicksPerWorldUnit,
        );
        index.query(bounds, buffer);
        final actual = <TerrainEdgeId>[
          for (
            var candidate = 0;
            candidate < buffer.candidateCount;
            candidate++
          )
            buffer.surfaceAt(candidate, index.surfaces).id,
        ];
        final expected = <TerrainEdgeId>[
          for (final surface in index.surfaces)
            if (_surfaceIntersects(surface, bounds)) surface.id,
        ];
        expect(actual, expected, reason: 'query $queryIndex');
      }
    },
  );

  test('long slopes and exact negative cell boundaries remain complete', () {
    final long = _surface(0, -128, -64, 128, 64);
    final boundary = _surface(1, 0, 64, 64, 64);
    final index = TerrainSurfaceSpatialIndex(
      surfaceSet: _surfaceSet(<TerrainNavigationSurface>[long, boundary]),
    );
    final buffer = index.createQueryBuffer();

    index.queryBounds(
      minX: -64 * terrainPhysicsTicksPerWorldUnit,
      minY: -33 * terrainPhysicsTicksPerWorldUnit,
      maxX: 64 * terrainPhysicsTicksPerWorldUnit,
      maxY: 64 * terrainPhysicsTicksPerWorldUnit,
      buffer: buffer,
    );

    expect(
      <TerrainEdgeId>[
        for (var candidate = 0; candidate < buffer.candidateCount; candidate++)
          buffer.surfaceAt(candidate, index.surfaces).id,
      ],
      <TerrainEdgeId>[long.id, boundary.id],
    );
    expect(index.insertedReferences, greaterThan(2));
    expect(index.occupiedCellCount, greaterThan(2));
  });

  test('queries above, below, and across a slope use full segment bounds', () {
    final slope = _surface(0, 0, 100, 100, 0);
    final index = TerrainSurfaceSpatialIndex(
      surfaceSet: _surfaceSet(<TerrainNavigationSurface>[slope]),
    );
    final buffer = index.createQueryBuffer();

    expect(
      index.queryBounds(
        minX: 40 * 1024,
        minY: -20 * 1024,
        maxX: 60 * 1024,
        maxY: -1 * 1024,
        buffer: buffer,
      ),
      0,
    );
    expect(
      index.queryBounds(
        minX: 40 * 1024,
        minY: 101 * 1024,
        maxX: 60 * 1024,
        maxY: 120 * 1024,
        buffer: buffer,
      ),
      0,
    );
    expect(
      index.queryBounds(
        minX: 40 * 1024,
        minY: 40 * 1024,
        maxX: 60 * 1024,
        maxY: 60 * 1024,
        buffer: buffer,
      ),
      1,
    );
  });

  test('canonical results ignore source input permutation', () {
    const compiler = TerrainCompiler();
    const extractor = TerrainSurfaceExtractor();
    final forward = extractor.extract(
      compiler.compile(buildSlopesGoldenInputs(), geometryVersion: 8),
    );
    final reverse = extractor.extract(
      compiler.compile(buildSlopesGoldenInputs().reversed, geometryVersion: 8),
    );
    final forwardIndex = TerrainSurfaceSpatialIndex(surfaceSet: forward);
    final reverseIndex = TerrainSurfaceSpatialIndex(surfaceSet: reverse);
    final forwardBuffer = forwardIndex.createQueryBuffer();
    final reverseBuffer = reverseIndex.createQueryBuffer();
    final bounds = TerrainAabb(
      minX: 0,
      minY: 100 * 1024,
      maxX: 2048 * 1024,
      maxY: 400 * 1024,
    );

    forwardIndex.query(bounds, forwardBuffer);
    reverseIndex.query(bounds, reverseBuffer);
    expect(
      _candidateIds(forwardIndex, forwardBuffer),
      orderedEquals(_candidateIds(reverseIndex, reverseBuffer)),
    );
  });

  test('representative and hard-stream capacities never truncate', () {
    for (final count in <int>[1280, 5120]) {
      final surfaces = <TerrainNavigationSurface>[
        for (var index = 0; index < count; index += 1)
          _surface(
            index,
            index * 2,
            index.isEven ? 0 : 32,
            index * 2 + 1,
            index.isEven ? 1 : 31,
          ),
      ];
      final spatialIndex = TerrainSurfaceSpatialIndex(
        surfaceSet: _surfaceSet(surfaces),
      );
      final buffer = spatialIndex.createQueryBuffer();
      final queried = spatialIndex.queryBounds(
        minX: -terrainCollisionSkinTicks,
        minY: -terrainCollisionSkinTicks,
        maxX: (count * 2 + 1) * terrainPhysicsTicksPerWorldUnit,
        maxY: 33 * terrainPhysicsTicksPerWorldUnit,
        buffer: buffer,
      );

      expect(queried, count);
      expect(buffer.stats.uniqueCandidates, count);
      expect(buffer.candidateCount, count);
    }
  });

  test('warm query buffers do not grow during steady-state use', () {
    final index = TerrainSurfaceSpatialIndex(
      surfaceSet: _surfaceSet(<TerrainNavigationSurface>[
        for (var surfaceIndex = 0; surfaceIndex < 1280; surfaceIndex += 1)
          _surface(
            surfaceIndex,
            surfaceIndex * 2,
            0,
            surfaceIndex * 2 + 1,
            surfaceIndex.isEven ? 0 : 1,
          ),
      ]),
    );
    final buffer = index.createQueryBuffer();
    final query = TerrainAabb(
      minX: -terrainCollisionSkinTicks,
      minY: -terrainCollisionSkinTicks,
      maxX: 10 * terrainPhysicsTicksPerWorldUnit,
      maxY: 10 * terrainPhysicsTicksPerWorldUnit,
    );
    index.query(query, buffer);
    final resizeCount = buffer.resizeCount;

    for (var iteration = 0; iteration < 10000; iteration += 1) {
      index.query(query, buffer);
    }

    expect(buffer.resizeCount, resizeCount);
  });

  test('invalid index and query dimensions fail before mutation', () {
    final set = _surfaceSet(<TerrainNavigationSurface>[
      _surface(0, 0, 0, 10, 0),
    ]);
    expect(
      () => TerrainSurfaceSpatialIndex(surfaceSet: set, cellSizeWorld: 0),
      throwsArgumentError,
    );
    final index = TerrainSurfaceSpatialIndex(surfaceSet: set);
    final buffer = index.createQueryBuffer();
    expect(
      () =>
          index.queryBounds(minX: 1, minY: 0, maxX: 0, maxY: 1, buffer: buffer),
      throwsArgumentError,
    );
    expect(buffer.candidateCount, 0);
  });
}

TerrainSurfaceSet _surfaceSet(List<TerrainNavigationSurface> surfaces) =>
    TerrainSurfaceSet(geometryVersion: 1, surfaces: surfaces);

TerrainNavigationSurface _surface(
  int id,
  int startX,
  int startY,
  int endX,
  int endY, {
  bool endpointIsDelta = false,
}) {
  if (endpointIsDelta) {
    endX += startX;
    endY += startY;
  }
  final edgeId = TerrainEdgeId(
    chunkIndex: 0,
    chunkKey: 'chunk',
    shapeId: 'surface',
    localEdgeIndex: id,
  );
  final start = TerrainPoint.fromWorld(startX.toDouble(), startY.toDouble());
  final end = TerrainPoint.fromWorld(endX.toDouble(), endY.toDouble());
  final dx = end.xTicks - start.xTicks;
  final dy = end.yTicks - start.yTicks;
  return TerrainNavigationSurface(
    id: edgeId,
    start: start,
    end: end,
    tangent: TerrainDirection.fromDelta(dx, dy),
    outwardNormal: TerrainDirection.fromDelta(dy, -dx),
    collisionMode: TerrainCollisionMode.solid,
    surfaceKind: 'terrain',
    materialKey: null,
    previousId: null,
    nextId: null,
    startKind: TerrainSurfaceEndpointKind.ledge,
    endKind: TerrainSurfaceEndpointKind.ledge,
    chainId: edgeId,
  );
}

bool _surfaceIntersects(TerrainNavigationSurface surface, TerrainAabb bounds) {
  final minY = math.min(surface.start.yTicks, surface.end.yTicks);
  final maxY = math.max(surface.start.yTicks, surface.end.yTicks);
  return surface.xMinTicks <= bounds.maxX &&
      surface.xMaxTicks >= bounds.minX &&
      minY <= bounds.maxY &&
      maxY >= bounds.minY;
}

List<TerrainEdgeId> _candidateIds(
  TerrainSurfaceSpatialIndex index,
  TerrainSurfaceQueryBuffer buffer,
) => <TerrainEdgeId>[
  for (var candidate = 0; candidate < buffer.candidateCount; candidate += 1)
    buffer.surfaceAt(candidate, index.surfaces).id,
];
