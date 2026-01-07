import 'package:flutter_test/flutter_test.dart';

import 'package:walkscape_runner/core/collision/static_world_geometry.dart';
import 'package:walkscape_runner/core/ecs/spatial/grid_index_2d.dart';
import 'package:walkscape_runner/core/navigation/utils/jump_template.dart';
import 'package:walkscape_runner/core/navigation/types/surface_graph.dart';
import 'package:walkscape_runner/core/navigation/surface_graph_builder.dart';

JumpReachabilityTemplate _template() {
  const profile = JumpProfile(
    jumpSpeed: 600.0,
    gravityY: 1200.0,
    maxAirTicks: 90,
    airSpeedX: 300.0,
    dtSeconds: 1.0 / 60.0,
    agentHalfWidth: 10.0,
  );
  return JumpReachabilityTemplate.build(profile);
}

List<String> _edgeSignatures(SurfaceGraph graph) {
  final sigs = <String>[];
  for (var i = 0; i < graph.surfaces.length; i += 1) {
    final start = graph.edgeOffsets[i];
    final end = graph.edgeOffsets[i + 1];
    for (var ei = start; ei < end; ei += 1) {
      final edge = graph.edges[ei];
      sigs.add(
        '$i:${edge.kind.index}:${edge.to}:${edge.takeoffX.toStringAsFixed(3)}:'
        '${edge.landingX.toStringAsFixed(3)}:${edge.travelTicks}',
      );
    }
  }
  return sigs;
}

int _indexForSurface(
  SurfaceGraph graph, {
  required double yTop,
  required double xMin,
  required double xMax,
}) {
  for (var i = 0; i < graph.surfaces.length; i += 1) {
    final s = graph.surfaces[i];
    if ((s.yTop - yTop).abs() < 1e-9 &&
        (s.xMin - xMin).abs() < 1e-9 &&
        (s.xMax - xMax).abs() < 1e-9) {
      return i;
    }
  }
  throw StateError('Surface not found for y=$yTop x=[$xMin,$xMax].');
}

void main() {
  test('surface graph build is deterministic', () {
    const geometry = StaticWorldGeometry(
      groundPlane: null,
      solids: <StaticSolid>[
        StaticSolid(
          minX: 0,
          minY: 200,
          maxX: 100,
          maxY: 216,
          sides: StaticSolid.sideTop,
          oneWayTop: true,
          chunkIndex: 0,
          localSolidIndex: 0,
        ),
        StaticSolid(
          minX: 140,
          minY: 200,
          maxX: 240,
          maxY: 216,
          sides: StaticSolid.sideTop,
          oneWayTop: true,
          chunkIndex: 1,
          localSolidIndex: 0,
        ),
      ],
    );

    final builder = SurfaceGraphBuilder(
      surfaceGrid: GridIndex2D(cellSize: 64),
    );

    final a = builder.build(geometry: geometry, jumpTemplate: _template());
    final b = builder.build(geometry: geometry, jumpTemplate: _template());

    expect(_edgeSignatures(a.graph), _edgeSignatures(b.graph));
  });

  test('drop edges land on the first surface below', () {
    const geometry = StaticWorldGeometry(
      groundPlane: null,
      solids: <StaticSolid>[
        StaticSolid(
          minX: 0,
          minY: 100,
          maxX: 120,
          maxY: 116,
          sides: StaticSolid.sideTop,
          oneWayTop: true,
          chunkIndex: 0,
          localSolidIndex: 0,
        ),
        StaticSolid(
          minX: 0,
          minY: 140,
          maxX: 120,
          maxY: 156,
          sides: StaticSolid.sideTop,
          oneWayTop: true,
          chunkIndex: 0,
          localSolidIndex: 1,
        ),
        StaticSolid(
          minX: 0,
          minY: 180,
          maxX: 120,
          maxY: 196,
          sides: StaticSolid.sideTop,
          oneWayTop: true,
          chunkIndex: 0,
          localSolidIndex: 2,
        ),
      ],
    );

    final builder = SurfaceGraphBuilder(
      surfaceGrid: GridIndex2D(cellSize: 64),
    );

    final result = builder.build(geometry: geometry, jumpTemplate: _template());
    final graph = result.graph;

    final fromIndex = 0;
    final dropTargets = <int>[];
    final start = graph.edgeOffsets[fromIndex];
    final end = graph.edgeOffsets[fromIndex + 1];
    for (var i = start; i < end; i += 1) {
      final edge = graph.edges[i];
      if (edge.kind == SurfaceEdgeKind.drop) {
        dropTargets.add(edge.to);
      }
    }

    expect(dropTargets, isNotEmpty);
    for (final target in dropTargets) {
      expect(graph.surfaces[target].yTop, closeTo(140, 1e-9));
    }
  });

  test('long surfaces still emit jump edges for high platforms', () {
    const longSurfaceMinX = 0.0;
    const longSurfaceMaxX = 1000.0;
    const longSurfaceTopY = 200.0;
    const platformMinX = 200.0;
    const platformMaxX = 240.0;
    const platformTopY = 60.0;
    const geometry = StaticWorldGeometry(
      groundPlane: null,
      solids: <StaticSolid>[
        StaticSolid(
          minX: longSurfaceMinX,
          minY: longSurfaceTopY,
          maxX: longSurfaceMaxX,
          maxY: longSurfaceTopY + 16.0,
          sides: StaticSolid.sideTop,
          oneWayTop: true,
          chunkIndex: 0,
          localSolidIndex: 0,
        ),
        StaticSolid(
          minX: platformMinX,
          minY: platformTopY,
          maxX: platformMaxX,
          maxY: platformTopY + 16.0,
          sides: StaticSolid.sideTop,
          oneWayTop: true,
          chunkIndex: 0,
          localSolidIndex: 1,
        ),
      ],
    );

    final builder = SurfaceGraphBuilder(
      surfaceGrid: GridIndex2D(cellSize: 64),
    );
    final graph = builder.build(
      geometry: geometry,
      jumpTemplate: _template(),
    ).graph;

    final fromIndex = _indexForSurface(
      graph,
      yTop: longSurfaceTopY,
      xMin: longSurfaceMinX,
      xMax: longSurfaceMaxX,
    );
    final toIndex = _indexForSurface(
      graph,
      yTop: platformTopY,
      xMin: platformMinX,
      xMax: platformMaxX,
    );

    var hasJump = false;
    final start = graph.edgeOffsets[fromIndex];
    final end = graph.edgeOffsets[fromIndex + 1];
    for (var i = start; i < end; i += 1) {
      final edge = graph.edges[i];
      if (edge.kind == SurfaceEdgeKind.jump && edge.to == toIndex) {
        hasJump = true;
        break;
      }
    }

    expect(hasJump, isTrue);
  });

  test('ground segments allow jump edges across gaps', () {
    const groundTopY = 200.0;
    const geometry = StaticWorldGeometry(
      groundPlane: null,
      groundSegments: <StaticGroundSegment>[
        StaticGroundSegment(
          minX: 0,
          maxX: 120,
          topY: groundTopY,
          chunkIndex: 0,
          localSegmentIndex: 0,
        ),
        StaticGroundSegment(
          minX: 180,
          maxX: 300,
          topY: groundTopY,
          chunkIndex: 0,
          localSegmentIndex: 1,
        ),
      ],
    );

    final builder = SurfaceGraphBuilder(
      surfaceGrid: GridIndex2D(cellSize: 64),
    );
    final graph = builder.build(
      geometry: geometry,
      jumpTemplate: _template(),
    ).graph;

    final leftIndex = _indexForSurface(
      graph,
      yTop: groundTopY,
      xMin: 0,
      xMax: 120,
    );
    final rightIndex = _indexForSurface(
      graph,
      yTop: groundTopY,
      xMin: 180,
      xMax: 300,
    );

    var hasJump = false;
    final start = graph.edgeOffsets[leftIndex];
    final end = graph.edgeOffsets[leftIndex + 1];
    for (var i = start; i < end; i += 1) {
      final edge = graph.edges[i];
      if (edge.kind == SurfaceEdgeKind.jump && edge.to == rightIndex) {
        hasJump = true;
        break;
      }
    }

    expect(hasJump, isTrue);
  });
}
