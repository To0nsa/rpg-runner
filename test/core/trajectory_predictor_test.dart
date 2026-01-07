import 'package:flutter_test/flutter_test.dart';

import 'package:walkscape_runner/core/ecs/spatial/grid_index_2d.dart';
import 'package:walkscape_runner/core/navigation/types/surface_graph.dart';
import 'package:walkscape_runner/core/navigation/types/surface_id.dart';
import 'package:walkscape_runner/core/navigation/types/walk_surface.dart';
import 'package:walkscape_runner/core/navigation/utils/surface_spatial_index.dart';
import 'package:walkscape_runner/core/navigation/utils/trajectory_predictor.dart';

/// Helper to build a SurfaceGraph from a list of surfaces (no edges needed for
/// trajectory prediction tests).
SurfaceGraph _buildGraph(List<WalkSurface> surfaces) {
  final indexById = <int, int>{};
  for (var i = 0; i < surfaces.length; i++) {
    indexById[surfaces[i].id] = i;
  }
  return SurfaceGraph(
    surfaces: surfaces,
    edgeOffsets: List<int>.generate(surfaces.length + 1, (_) => 0),
    edges: const <SurfaceEdge>[],
    indexById: indexById,
  );
}

void main() {
  group('TrajectoryPredictor', () {
    late TrajectoryPredictor predictor;
    late SurfaceSpatialIndex spatialIndex;

    setUp(() {
      predictor = const TrajectoryPredictor(
        gravityY: 1200.0,
        dtSeconds: 1.0 / 60.0,
        maxTicks: 120,
      );
      spatialIndex = SurfaceSpatialIndex(
        index: GridIndex2D(cellSize: 32),
      );
    });

    test('simple fall onto ground plane', () {
      // Ground at y=100, entity starts at y=50 falling down.
      final surfaces = <WalkSurface>[
        WalkSurface(
          id: packSurfaceId(chunkIndex: 0, localSolidIndex: 0),
          xMin: -1000,
          xMax: 1000,
          yTop: 100,
        ),
      ];
      final graph = _buildGraph(surfaces);
      spatialIndex.rebuild(surfaces);

      final prediction = predictor.predictLanding(
        startX: 0,
        startBottomY: 50,
        velX: 0,
        velY: 0, // Starting with zero velocity, gravity will accelerate
        graph: graph,
        spatialIndex: spatialIndex,
        entityHalfWidth: 8,
      );

      expect(prediction, isNotNull);
      expect(prediction!.bottomY, equals(100.0));
      expect(prediction.x, closeTo(0, 1)); // Should land roughly where started
      expect(prediction.ticksToLand, greaterThan(0));
    });

    test('fall with horizontal velocity', () {
      // Ground at y=100, entity starts at y=50 moving right.
      final surfaces = <WalkSurface>[
        WalkSurface(
          id: packSurfaceId(chunkIndex: 0, localSolidIndex: 0),
          xMin: -1000,
          xMax: 1000,
          yTop: 100,
        ),
      ];
      final graph = _buildGraph(surfaces);
      spatialIndex.rebuild(surfaces);

      final prediction = predictor.predictLanding(
        startX: 0,
        startBottomY: 50,
        velX: 200, // Moving right at 200 units/s
        velY: 0,
        graph: graph,
        spatialIndex: spatialIndex,
        entityHalfWidth: 8,
      );

      expect(prediction, isNotNull);
      expect(prediction!.bottomY, equals(100.0));
      expect(prediction.x, greaterThan(0)); // Should land to the right
    });

    test('jump arc landing on platform', () {
      // Platform at y=60 (higher than ground at y=100).
      // Entity starts at ground level jumping up.
      final surfaces = <WalkSurface>[
        WalkSurface(
          id: packSurfaceId(chunkIndex: 0, localSolidIndex: 0),
          xMin: 50,
          xMax: 150,
          yTop: 60, // Platform above
        ),
        WalkSurface(
          id: packSurfaceId(chunkIndex: 0, localSolidIndex: 1),
          xMin: -1000,
          xMax: 1000,
          yTop: 100, // Ground below
        ),
      ];
      final graph = _buildGraph(surfaces);
      spatialIndex.rebuild(surfaces);

      final prediction = predictor.predictLanding(
        startX: 0,
        startBottomY: 100, // Starting at ground
        velX: 200, // Moving right toward platform
        velY: -400, // Jumping up (negative = upward)
        graph: graph,
        spatialIndex: spatialIndex,
        entityHalfWidth: 8,
      );

      expect(prediction, isNotNull);
      // Should land on the higher platform (y=60), not ground (y=100)
      expect(prediction!.bottomY, equals(60.0));
    });

    test('no landing found returns null', () {
      // No surfaces - entity will fall forever.
      final graph = _buildGraph(const <WalkSurface>[]);
      spatialIndex.rebuild(const <WalkSurface>[]);

      final prediction = predictor.predictLanding(
        startX: 0,
        startBottomY: 50,
        velX: 0,
        velY: 0,
        graph: graph,
        spatialIndex: spatialIndex,
        entityHalfWidth: 8,
      );

      expect(prediction, isNull);
    });

    test('entity too wide for surface still lands with partial overlap', () {
      // Narrow surface that entity cannot fully fit on.
      final surfaces = <WalkSurface>[
        WalkSurface(
          id: packSurfaceId(chunkIndex: 0, localSolidIndex: 0),
          xMin: -5,
          xMax: 5, // Only 10 units wide
          yTop: 100,
        ),
      ];
      final graph = _buildGraph(surfaces);
      spatialIndex.rebuild(surfaces);

      final prediction = predictor.predictLanding(
        startX: 0,
        startBottomY: 50,
        velX: 0,
        velY: 0,
        graph: graph,
        spatialIndex: spatialIndex,
        entityHalfWidth: 20, // Entity is 40 units wide, surface is only 10
      );

      // Entity should still land if center is over the surface
      // (partial overlap is allowed in current implementation).
      expect(prediction, isNotNull);
    });

    test('horizontal miss - trajectory passes beside surface', () {
      // Surface only exists far to the right.
      final surfaces = <WalkSurface>[
        WalkSurface(
          id: packSurfaceId(chunkIndex: 0, localSolidIndex: 0),
          xMin: 500,
          xMax: 600,
          yTop: 100,
        ),
      ];
      final graph = _buildGraph(surfaces);
      spatialIndex.rebuild(surfaces);

      final prediction = predictor.predictLanding(
        startX: 0,
        startBottomY: 50,
        velX: 0, // Not moving horizontally
        velY: 0,
        graph: graph,
        spatialIndex: spatialIndex,
        entityHalfWidth: 8,
      );

      // Should not land on surface that's too far away.
      expect(prediction, isNull);
    });

    test('ascending entity does not trigger landing', () {
      // Entity jumping up through a platform should not "land" on it mid-ascent.
      final surfaces = <WalkSurface>[
        WalkSurface(
          id: packSurfaceId(chunkIndex: 0, localSolidIndex: 0),
          xMin: -100,
          xMax: 100,
          yTop: 80, // Platform between start and apex
        ),
        WalkSurface(
          id: packSurfaceId(chunkIndex: 0, localSolidIndex: 1),
          xMin: -100,
          xMax: 100,
          yTop: 150, // Lower surface (higher y)
        ),
      ];
      final graph = _buildGraph(surfaces);
      spatialIndex.rebuild(surfaces);

      final prediction = predictor.predictLanding(
        startX: 0,
        startBottomY: 100, // Starting between the two surfaces
        velX: 0,
        velY: -500, // Strong upward jump
        graph: graph,
        spatialIndex: spatialIndex,
        entityHalfWidth: 8,
      );

      expect(prediction, isNotNull);
      // Should land on the platform at y=80 on the way DOWN, not immediately.
      expect(prediction!.bottomY, equals(80.0));
      expect(prediction.ticksToLand, greaterThan(10)); // Not instant
    });

    test('prefers first landing (highest surface crossed)', () {
      // Multiple surfaces at different heights.
      final surfaces = <WalkSurface>[
        WalkSurface(
          id: packSurfaceId(chunkIndex: 0, localSolidIndex: 0),
          xMin: -100,
          xMax: 100,
          yTop: 80, // Higher platform
        ),
        WalkSurface(
          id: packSurfaceId(chunkIndex: 0, localSolidIndex: 1),
          xMin: -100,
          xMax: 100,
          yTop: 120, // Lower platform
        ),
      ];
      final graph = _buildGraph(surfaces);
      spatialIndex.rebuild(surfaces);

      final prediction = predictor.predictLanding(
        startX: 0,
        startBottomY: 50, // Starting above both
        velX: 0,
        velY: 100, // Already falling
        graph: graph,
        spatialIndex: spatialIndex,
        entityHalfWidth: 8,
      );

      expect(prediction, isNotNull);
      // Should land on the FIRST surface encountered (y=80, higher platform).
      expect(prediction!.bottomY, equals(80.0));
    });
  });
}
