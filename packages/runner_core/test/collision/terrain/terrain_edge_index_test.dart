import 'dart:math' as math;

import 'package:runner_core/collision/terrain/terrain_edge.dart';
import 'package:runner_core/collision/terrain/terrain_edge_id.dart';
import 'package:runner_core/collision/terrain/terrain_edge_index.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:test/test.dart';

void main() {
  test('closed exact-boundary edge enters both adjacent cell lanes', () {
    final edge = _edge(0, 0, 0, 64, 0);
    final index = TerrainEdgeIndex(edges: <TerrainEdge>[edge]);

    expect(index.insertedReferences, 6);
    expect(
      index.canonicalMembershipRecords(),
      containsAll(<String>[
        'index-cell|0/chunk/-/shape_0/0/0|-1|-1',
        'index-cell|0/chunk/-/shape_0/0/0|0|-1',
        'index-cell|0/chunk/-/shape_0/0/0|1|-1',
        'index-cell|0/chunk/-/shape_0/0/0|-1|0',
        'index-cell|0/chunk/-/shape_0/0/0|0|0',
        'index-cell|0/chunk/-/shape_0/0/0|1|0',
      ]),
    );
  });

  test('query deduplicates multi-cell references in canonical edge order', () {
    final later = _edge(2, -128, 0, 128, 0);
    final earlier = _edge(1, 0, -128, 0, 128);
    final index = TerrainEdgeIndex(edges: <TerrainEdge>[later, earlier]);
    final buffer = index.createQueryBuffer();

    final count = index.query(
      const TerrainAabb(minX: -1, minY: -1, maxX: 1, maxY: 1),
      buffer,
    );

    expect(count, 2);
    expect(buffer.stats.rawCandidates, greaterThan(2));
    expect(buffer.edgeAt(0, index.edges).id, earlier.id);
    expect(buffer.edgeAt(1, index.edges).id, later.id);
  });

  test('indexed candidates equal closed-AABB brute force', () {
    final random = math.Random(42);
    final edges = <TerrainEdge>[
      for (var i = 0; i < 240; i += 1)
        _edge(
          i,
          random.nextInt(1000) - 500,
          random.nextInt(1000) - 500,
          random.nextInt(1000) - 500,
          random.nextInt(1000) - 500,
        ),
    ];
    final index = TerrainEdgeIndex(edges: edges);
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
        for (var i = 0; i < buffer.candidateCount; i += 1)
          buffer.edgeAt(i, index.edges).id,
      ];
      final expected = <TerrainEdgeId>[
        for (final edge in index.edges)
          if (edge.bounds.intersects(bounds)) edge.id,
      ];
      expect(actual, expected, reason: 'query $queryIndex');
    }
  });

  test('reordered equivalent input produces the same index records', () {
    final edges = <TerrainEdge>[
      _edge(0, -10, -10, 10, 10),
      _edge(1, 10, -10, -10, 10),
      _edge(2, -128, 64, 128, 64),
    ];
    final forward = TerrainEdgeIndex(edges: edges);
    final reverse = TerrainEdgeIndex(edges: edges.reversed);

    expect(reverse.edges, forward.edges);
    expect(
      reverse.canonicalMembershipRecords(),
      forward.canonicalMembershipRecords(),
    );
  });

  test('representative and hard-stream capacities never truncate', () {
    for (final count in <int>[1280, 5120]) {
      final edges = <TerrainEdge>[
        for (var i = 0; i < count; i += 1)
          _edge(
            i,
            i * 2,
            i.isEven ? 0 : 32,
            i * 2 + 1,
            i.isEven ? 0 : 32,
            chunkIndex: i ~/ 1024,
          ),
      ];
      final index = TerrainEdgeIndex(edges: edges);
      final buffer = index.createQueryBuffer();
      final queried = index.query(
        TerrainAabb(
          minX: -terrainCollisionSkinTicks,
          minY: -terrainCollisionSkinTicks,
          maxX: (count * 2 + 1) * terrainPhysicsTicksPerWorldUnit,
          maxY: 33 * terrainPhysicsTicksPerWorldUnit,
        ),
        buffer,
      );
      expect(queried, count);
      expect(buffer.stats.uniqueCandidates, count);
    }
  });

  test('steady-state query storage does not resize', () {
    final index = TerrainEdgeIndex(
      edges: <TerrainEdge>[
        for (var i = 0; i < 1280; i += 1)
          _edge(i, i * 2, 0, i * 2 + 1, i.isEven ? 0 : 1),
      ],
    );
    final buffer = index.createQueryBuffer();
    const query = TerrainAabb(
      minX: -terrainCollisionSkinTicks,
      minY: -terrainCollisionSkinTicks,
      maxX: 10 * terrainPhysicsTicksPerWorldUnit,
      maxY: 10 * terrainPhysicsTicksPerWorldUnit,
    );
    index.query(query, buffer);
    final resizeCount = buffer.resizeCount;

    for (var i = 0; i < 10000; i += 1) {
      index.query(query, buffer);
    }

    expect(buffer.resizeCount, resizeCount);
  });
}

TerrainEdge _edge(
  int id,
  int startX,
  int startY,
  int endX,
  int endY, {
  int chunkIndex = 0,
}) {
  final start = TerrainPoint.fromWorld(startX.toDouble(), startY.toDouble());
  var end = TerrainPoint.fromWorld(endX.toDouble(), endY.toDouble());
  if (start == end) {
    end = end.translated(terrainPhysicsTicksPerWorldUnit, 0);
  }
  final dx = end.xTicks - start.xTicks;
  final dy = end.yTicks - start.yTicks;
  return TerrainEdge(
    id: TerrainEdgeId(
      chunkIndex: chunkIndex,
      chunkKey: 'chunk',
      shapeId: 'shape_$id',
      localEdgeIndex: 0,
    ),
    start: start,
    end: end,
    tangent: TerrainDirection.fromDelta(dx, dy),
    outwardNormal: TerrainDirection.fromDelta(dy, -dx),
    collisionMode: TerrainCollisionMode.solid,
    surfaceKind: 'terrain',
    materialKey: null,
    previousId: null,
    nextId: null,
    startJoin: TerrainVertexJoin.exposed,
    endJoin: TerrainVertexJoin.exposed,
    bounds: TerrainAabb(
      minX: math.min(start.xTicks, end.xTicks),
      minY: math.min(start.yTicks, end.yTicks),
      maxX: math.max(start.xTicks, end.xTicks),
      maxY: math.max(start.yTicks, end.yTicks),
    ),
  );
}
