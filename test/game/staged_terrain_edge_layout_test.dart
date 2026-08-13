import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/collision/terrain/terrain_edge.dart';
import 'package:runner_core/collision/terrain/terrain_edge_id.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/snapshots/staged_terrain_render_snapshot.dart';

import 'package:rpg_runner/game/components/staged_terrain_edge_layout.dart';

void main() {
  test('orientation follows the exact Core outward normal', () {
    expect(
      StagedTerrainEdgeLayout.orientationFor(
        _edge(index: 0, start: (0, 0), end: (10, 0)),
      ),
      TerrainMaterialEdgeOrientation.top,
    );
    expect(
      StagedTerrainEdgeLayout.orientationFor(
        _edge(index: 1, start: (0, 0), end: (0, 10)),
      ),
      TerrainMaterialEdgeOrientation.rightWall,
    );
    expect(
      StagedTerrainEdgeLayout.orientationFor(
        _edge(index: 2, start: (10, 0), end: (0, 0)),
      ),
      TerrainMaterialEdgeOrientation.underside,
    );
    expect(
      StagedTerrainEdgeLayout.orientationFor(
        _edge(index: 3, start: (0, 10), end: (0, 0)),
      ),
      TerrainMaterialEdgeOrientation.leftWall,
    );
  });

  test('top caps appear only at the ends of one material run', () {
    final firstId = _id(0);
    final secondId = _id(1);
    final snapshot = StagedTerrainRenderSnapshot(
      geometryVersion: 1,
      polygons: const <StagedTerrainPolygonRenderSnapshot>[],
      edges: <TerrainEdge>[
        _edge(index: 0, start: (0, 0), end: (50, 0), nextId: secondId),
        _edge(index: 1, start: (50, 0), end: (100, 0), previousId: firstId),
      ],
    );

    final decorations = StagedTerrainEdgeLayout.build(snapshot);

    expect(decorations, hasLength(2));
    expect(decorations.first.drawStartCap, isTrue);
    expect(decorations.first.drawEndCap, isFalse);
    expect(decorations.last.drawStartCap, isFalse);
    expect(decorations.last.drawEndCap, isTrue);
  });

  test('unconfigured wall and underside profiles remain fill only', () {
    final snapshot = StagedTerrainRenderSnapshot(
      geometryVersion: 1,
      polygons: const <StagedTerrainPolygonRenderSnapshot>[],
      edges: <TerrainEdge>[
        _edge(index: 0, start: (0, 0), end: (0, 10)),
        _edge(index: 1, start: (10, 0), end: (0, 0)),
      ],
    );

    expect(StagedTerrainEdgeLayout.build(snapshot), isEmpty);
  });
}

TerrainEdge _edge({
  required int index,
  required (int, int) start,
  required (int, int) end,
  TerrainEdgeId? previousId,
  TerrainEdgeId? nextId,
}) {
  final startPoint = TerrainPoint(start.$1, start.$2);
  final endPoint = TerrainPoint(end.$1, end.$2);
  final dx = end.$1 - start.$1;
  final dy = end.$2 - start.$2;
  return TerrainEdge(
    id: _id(index),
    start: startPoint,
    end: endPoint,
    tangent: TerrainDirection.fromDelta(dx, dy),
    outwardNormal: TerrainDirection.fromDelta(dy, -dx),
    collisionMode: TerrainCollisionMode.solid,
    surfaceKind: 'ground',
    materialKey: 'grass_dirt',
    previousId: previousId,
    nextId: nextId,
    startJoin: previousId == null
        ? TerrainVertexJoin.exposed
        : TerrainVertexJoin.smooth,
    endJoin: nextId == null
        ? TerrainVertexJoin.exposed
        : TerrainVertexJoin.smooth,
    bounds: TerrainAabb(
      minX: start.$1 < end.$1 ? start.$1 : end.$1,
      minY: start.$2 < end.$2 ? start.$2 : end.$2,
      maxX: start.$1 > end.$1 ? start.$1 : end.$1,
      maxY: start.$2 > end.$2 ? start.$2 : end.$2,
    ),
  );
}

TerrainEdgeId _id(int index) => TerrainEdgeId(
  chunkIndex: 0,
  chunkKey: 'chunk',
  shapeId: 'ground',
  localEdgeIndex: index,
);
