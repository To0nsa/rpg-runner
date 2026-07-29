import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/navigation/types/terrain_surface_graph.dart';
import 'package:test/test.dart';

import '../../tool/src/slopes_phase3_benchmark_fixture.dart';

void main() {
  group('Phase 3 benchmark fixture', () {
    test('publishes the representative shared surface and graph load', () {
      final fixture = SlopesPhase3BenchmarkFixture.build(
        edgeCount: slopesPhase3RepresentativeEdgeCount,
        sloped: true,
      );

      expect(
        fixture.geometry.edges,
        hasLength(slopesPhase3RepresentativeEdgeCount),
      );
      expect(
        fixture.geometry.edges.map((edge) => edge.id.chunkIndex).toSet(),
        containsAll(<int>[0, 1, 2, 3, 4]),
      );
      expect(fixture.nodeCount, greaterThan(0));
      expect(fixture.graphEdgeCount, greaterThan(0));
      expect(
        identical(
          fixture.bundle.surfaceSet,
          fixture.bundle.grojibGraph.surfaceSet,
        ),
        isTrue,
      );
      expect(
        identical(
          fixture.bundle.surfaceSet,
          fixture.bundle.hashashGraph.surfaceSet,
        ),
        isTrue,
      );
      for (final graph in <TerrainSurfaceGraph>[
        fixture.bundle.grojibGraph,
        fixture.bundle.hashashGraph,
      ]) {
        for (final edge in graph.edges) {
          expect(edge.to, inInclusiveRange(0, graph.surfaces.length - 1));
        }
      }
    });

    test('controller, navigation, and trajectory buffers stay warm', () {
      final fixture = SlopesPhase3BenchmarkFixture.build(
        edgeCount: slopesPhase3RepresentativeEdgeCount,
        sloped: true,
      );
      final cases = <SlopesPhase3ControllerCase>[
        SlopesPhase3ControllerCase.supported(
          fixture: fixture,
          enemyId: EnemyId.grojib,
        ),
        SlopesPhase3ControllerCase.supported(
          fixture: fixture,
          enemyId: EnemyId.hashash,
        ),
      ];
      for (final benchmarkCase in cases) {
        benchmarkCase.run();
      }
      final flying = SlopesPhase3ControllerCase.flyingBlocked(fixture: fixture)
        ..run();
      expect(flying.result.grounded, isFalse);
      expect(flying.result.contactCount, greaterThan(0));
      final controllerResizes = <int>[
        for (final benchmarkCase in cases)
          benchmarkCase.controller.queryBufferResizeCount,
      ];
      final navigation = SlopesPhase3NavigationHarness.build(fixture)..warm();
      final predictorResizes = navigation.predictor.queryBufferResizeCount;

      for (var iteration = 0; iteration < 1000; iteration += 1) {
        for (final benchmarkCase in cases) {
          benchmarkCase.run();
          expect(benchmarkCase.result.grounded, isTrue);
          expect(
            benchmarkCase.result.contactIterations,
            lessThanOrEqualTo(terrainMaxBlockingContacts),
          );
          expect(
            benchmarkCase.result.recoveryIterations,
            lessThanOrEqualTo(terrainMaxRecoveryIterations),
          );
        }
        navigation
          ..runSteadyState()
          ..runRepath()
          ..runTrajectory();
      }

      expect(<int>[
        for (final benchmarkCase in cases)
          benchmarkCase.controller.queryBufferResizeCount,
      ], controllerResizes);
      expect(navigation.predictor.queryBufferResizeCount, predictorResizes);
      expect(
        navigation.lastExpandedNodeCount,
        lessThan(slopesPhase3PathfinderExpansionLimit),
      );
      expect(navigation.prediction.hasLanding, isTrue);
    });

    test('mixed tick integrates 8/8/4/4 without hidden dynamic bodies', () {
      final geometry = buildSlopesPhase3BenchmarkGeometry(
        edgeCount: slopesPhase3RepresentativeEdgeCount,
        sloped: true,
        geometryVersion: 41,
      );
      final harness = SlopesPhase3MixedEnemyHarness.build(geometry);

      expect(harness.groundEnemies, hasLength(16));
      expect(harness.flyingEnemies, hasLength(4));
      expect(harness.derfs, hasLength(4));
      for (var tick = 0; tick < 120; tick += 1) {
        harness.runTick();
      }

      expect(harness.lastIntegratedBodyCount, 20);
      expect(
        harness.maxContactIterations,
        lessThanOrEqualTo(terrainMaxBlockingContacts),
      );
      expect(
        harness.maxRecoveryIterations,
        lessThanOrEqualTo(terrainMaxRecoveryIterations),
      );
    });

    test('hard-stream geometry retains every edge and local query result', () {
      final geometry = buildSlopesPhase3BenchmarkGeometry(
        edgeCount: slopesPhase3HardStreamEdgeCount,
        sloped: true,
        geometryVersion: 51,
      );
      final stack = buildSlopesPhase3SurfaceStack(geometry);
      final buffer = stack.edgeIndex.createQueryBuffer();
      final resizeCount = buffer.resizeCount;

      for (final edge in geometry.edges) {
        stack.edgeIndex.query(edge.bounds, buffer);
        expect(
          List<int>.generate(
            buffer.candidateCount,
            (index) =>
                buffer.edgeAt(index, geometry.edges).id == edge.id ? 1 : 0,
          ),
          contains(1),
        );
      }

      expect(geometry.edges, hasLength(slopesPhase3HardStreamEdgeCount));
      expect(buffer.resizeCount, resizeCount);
    });
  });
}
