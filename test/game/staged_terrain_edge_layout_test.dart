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

  test('smooth top continuation keeps caps only at exposed endpoints', () {
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

  test('connected convex wall-to-top corner receives one top cap', () {
    final wallId = _id(0);
    final topId = _id(1);
    final snapshot = StagedTerrainRenderSnapshot(
      geometryVersion: 1,
      polygons: const <StagedTerrainPolygonRenderSnapshot>[],
      edges: <TerrainEdge>[
        _edge(
          index: 0,
          start: (0, 50),
          end: (0, 0),
          nextId: topId,
          endJoin: TerrainVertexJoin.connected,
        ),
        _edge(
          index: 1,
          start: (0, 0),
          end: (100, 0),
          previousId: wallId,
          startJoin: TerrainVertexJoin.connected,
        ),
      ],
    );

    final decorations = StagedTerrainEdgeLayout.build(snapshot);

    expect(decorations.last.orientation, TerrainMaterialEdgeOrientation.top);
    expect(decorations.first.drawEndCap, isFalse);
    expect(decorations.last.drawStartCap, isTrue);
    expect(decorations.last.drawEndCap, isTrue);
  });

  test('closed rectangle resolves all four convex corners exactly once', () {
    final topId = _id(0);
    final rightId = _id(1);
    final undersideId = _id(2);
    final leftId = _id(3);
    final snapshot = StagedTerrainRenderSnapshot(
      geometryVersion: 1,
      polygons: const <StagedTerrainPolygonRenderSnapshot>[],
      edges: <TerrainEdge>[
        _edge(
          index: 0,
          start: (0, 0),
          end: (100, 0),
          previousId: leftId,
          nextId: rightId,
          startJoin: TerrainVertexJoin.connected,
          endJoin: TerrainVertexJoin.connected,
        ),
        _edge(
          index: 1,
          start: (100, 0),
          end: (100, 50),
          previousId: topId,
          nextId: undersideId,
          startJoin: TerrainVertexJoin.connected,
          endJoin: TerrainVertexJoin.connected,
        ),
        _edge(
          index: 2,
          start: (100, 50),
          end: (0, 50),
          previousId: rightId,
          nextId: leftId,
          startJoin: TerrainVertexJoin.connected,
          endJoin: TerrainVertexJoin.connected,
        ),
        _edge(
          index: 3,
          start: (0, 50),
          end: (0, 0),
          previousId: undersideId,
          nextId: topId,
          startJoin: TerrainVertexJoin.connected,
          endJoin: TerrainVertexJoin.connected,
        ),
      ],
    );

    final decorations = StagedTerrainEdgeLayout.build(snapshot);

    expect(
      decorations.map(
        (decoration) => (decoration.drawStartCap, decoration.drawEndCap),
      ),
      <(bool, bool)>[
        (true, true),
        (false, false),
        (true, true),
        (false, false),
      ],
    );
  });

  test('same-orientation convex bend selects only the incoming end cap', () {
    final firstId = _id(0);
    final secondId = _id(1);
    final snapshot = StagedTerrainRenderSnapshot(
      geometryVersion: 1,
      polygons: const <StagedTerrainPolygonRenderSnapshot>[],
      edges: <TerrainEdge>[
        _edge(
          index: 0,
          start: (0, 10),
          end: (10, 10),
          nextId: secondId,
          endJoin: TerrainVertexJoin.connected,
        ),
        _edge(
          index: 1,
          start: (10, 10),
          end: (20, 20),
          previousId: firstId,
          startJoin: TerrainVertexJoin.connected,
        ),
      ],
    );

    final decorations = StagedTerrainEdgeLayout.build(snapshot);

    expect(decorations.first.drawEndCap, isTrue);
    expect(decorations.last.drawStartCap, isFalse);
  });

  test('concave connected bend does not receive an outer cap', () {
    final firstId = _id(0);
    final secondId = _id(1);
    final snapshot = StagedTerrainRenderSnapshot(
      geometryVersion: 1,
      polygons: const <StagedTerrainPolygonRenderSnapshot>[],
      edges: <TerrainEdge>[
        _edge(
          index: 0,
          start: (0, 10),
          end: (10, 10),
          nextId: secondId,
          endJoin: TerrainVertexJoin.connected,
        ),
        _edge(
          index: 1,
          start: (10, 10),
          end: (20, 0),
          previousId: firstId,
          startJoin: TerrainVertexJoin.connected,
        ),
      ],
    );

    final decorations = StagedTerrainEdgeLayout.build(snapshot);

    expect(decorations.first.drawEndCap, isFalse);
    expect(decorations.last.drawStartCap, isFalse);
  });

  test('configured wall and underside profiles decorate exact normals', () {
    final snapshot = StagedTerrainRenderSnapshot(
      geometryVersion: 1,
      polygons: const <StagedTerrainPolygonRenderSnapshot>[],
      edges: <TerrainEdge>[
        _edge(index: 0, start: (0, 0), end: (0, 10)),
        _edge(index: 1, start: (10, 0), end: (0, 0)),
      ],
    );

    final decorations = StagedTerrainEdgeLayout.build(snapshot);

    expect(
      decorations.map((decoration) => decoration.orientation),
      <TerrainMaterialEdgeOrientation>[
        TerrainMaterialEdgeOrientation.rightWall,
        TerrainMaterialEdgeOrientation.underside,
      ],
    );
    expect(decorations.last.drawStartCap, isTrue);
    expect(decorations.last.drawEndCap, isTrue);
  });

  test('smooth underside continuation keeps caps at exposed endpoints', () {
    final firstId = _id(0);
    final secondId = _id(1);
    final snapshot = StagedTerrainRenderSnapshot(
      geometryVersion: 1,
      polygons: const <StagedTerrainPolygonRenderSnapshot>[],
      edges: <TerrainEdge>[
        _edge(index: 0, start: (100, 10), end: (50, 10), nextId: secondId),
        _edge(index: 1, start: (50, 10), end: (0, 10), previousId: firstId),
      ],
    );

    final decorations = StagedTerrainEdgeLayout.build(snapshot);

    expect(decorations, hasLength(2));
    expect(decorations.first.drawStartCap, isTrue);
    expect(decorations.first.drawEndCap, isFalse);
    expect(decorations.last.drawStartCap, isFalse);
    expect(decorations.last.drawEndCap, isTrue);
  });
}

TerrainEdge _edge({
  required int index,
  required (int, int) start,
  required (int, int) end,
  TerrainEdgeId? previousId,
  TerrainEdgeId? nextId,
  TerrainVertexJoin? startJoin,
  TerrainVertexJoin? endJoin,
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
    startJoin:
        startJoin ??
        (previousId == null
            ? TerrainVertexJoin.exposed
            : TerrainVertexJoin.smooth),
    endJoin:
        endJoin ??
        (nextId == null ? TerrainVertexJoin.exposed : TerrainVertexJoin.smooth),
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
