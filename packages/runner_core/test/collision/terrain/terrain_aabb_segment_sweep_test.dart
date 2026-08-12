import 'package:runner_core/collision/terrain/terrain_aabb_segment_sweep.dart';
import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:test/test.dart';

void main() {
  group('terrain AABB segment sweep', () {
    final geometry = _rectangle();
    final floor = geometry.edges.singleWhere(
      (edge) => edge.outwardNormal.yTicks < 0,
    );
    final leftWall = geometry.edges.singleWhere(
      (edge) => edge.outwardNormal.xTicks < 0,
    );
    final kernel = TerrainAabbSegmentSweepKernel();
    final hit = TerrainAabbSweepHit();

    test('finds exact high-speed floor and wall crossings', () {
      kernel.sweepAtCenter(
        centerXTicks: 150 * terrainPhysicsTicksPerWorldUnit,
        centerYTicks: 50 * terrainPhysicsTicksPerWorldUnit,
        halfWidthTicks: 10 * terrainPhysicsTicksPerWorldUnit,
        halfHeightTicks: 10 * terrainPhysicsTicksPerWorldUnit,
        displacementXTicks: 0,
        displacementYTicks: 100 * terrainPhysicsTicksPerWorldUnit,
        edge: floor,
        out: hit,
      );
      expect(hit.hit, isTrue);
      expect(hit.startedOverlapping, isFalse);
      expect(hit.timeOfImpact, closeTo(0.4, 1e-12));

      kernel.sweepAtCenter(
        centerXTicks: 50 * terrainPhysicsTicksPerWorldUnit,
        centerYTicks: 150 * terrainPhysicsTicksPerWorldUnit,
        halfWidthTicks: 10 * terrainPhysicsTicksPerWorldUnit,
        halfHeightTicks: 10 * terrainPhysicsTicksPerWorldUnit,
        displacementXTicks: 100 * terrainPhysicsTicksPerWorldUnit,
        displacementYTicks: 0,
        edge: leftWall,
        out: hit,
      );
      expect(hit.hit, isTrue);
      expect(hit.startedOverlapping, isFalse);
      expect(hit.timeOfImpact, closeTo(0.4, 1e-12));
    });

    test('ignores a parallel miss and identifies initial penetration', () {
      kernel.sweepAtCenter(
        centerXTicks: 150 * terrainPhysicsTicksPerWorldUnit,
        centerYTicks: 50 * terrainPhysicsTicksPerWorldUnit,
        halfWidthTicks: 10 * terrainPhysicsTicksPerWorldUnit,
        halfHeightTicks: 10 * terrainPhysicsTicksPerWorldUnit,
        displacementXTicks: 100 * terrainPhysicsTicksPerWorldUnit,
        displacementYTicks: 0,
        edge: floor,
        out: hit,
      );
      expect(hit.hit, isFalse);

      kernel.sweepAtCenter(
        centerXTicks: 150 * terrainPhysicsTicksPerWorldUnit,
        centerYTicks: 100 * terrainPhysicsTicksPerWorldUnit,
        halfWidthTicks: 10 * terrainPhysicsTicksPerWorldUnit,
        halfHeightTicks: 10 * terrainPhysicsTicksPerWorldUnit,
        displacementXTicks: 0,
        displacementYTicks: 50 * terrainPhysicsTicksPerWorldUnit,
        edge: floor,
        out: hit,
      );
      expect(hit.hit, isTrue);
      expect(hit.startedOverlapping, isTrue);
      expect(hit.timeOfImpact, 0);
    });

    test('sweeps a wide projectile continuously against a slope', () {
      final slope = _slope().edges.singleWhere(
        (edge) => edge.outwardNormal.yTicks < 0 && edge.dyTicks != 0,
      );
      kernel.sweepAtCenter(
        centerXTicks: 150 * terrainPhysicsTicksPerWorldUnit,
        centerYTicks: 0,
        halfWidthTicks: 16 * terrainPhysicsTicksPerWorldUnit,
        halfHeightTicks: 5 * terrainPhysicsTicksPerWorldUnit,
        displacementXTicks: 0,
        displacementYTicks: 300 * terrainPhysicsTicksPerWorldUnit,
        edge: slope,
        out: hit,
      );
      expect(hit.hit, isTrue);
      expect(hit.startedOverlapping, isFalse);
      expect(hit.timeOfImpact, inExclusiveRange(0, 1));
    });

    test('equal-time contacts use canonical edge identity', () {
      final first = TerrainAabbSweepHit()
        ..hit = true
        ..timeOfImpact = 0.5
        ..edgeId = geometry.edges.first.id;
      final second = TerrainAabbSweepHit()
        ..hit = true
        ..timeOfImpact = 0.5
        ..edgeId = geometry.edges.last.id;
      expect(
        kernel.compareHits(first, second),
        geometry.edges.first.id.compareTo(geometry.edges.last.id),
      );
    });
  });
}

TerrainGeometry _rectangle() => _compile(<(double, double)>[
  (100, 100),
  (200, 100),
  (200, 200),
  (100, 200),
]);

TerrainGeometry _slope() => _compile(<(double, double)>[
  (100, 100),
  (200, 200),
  (200, 240),
  (100, 240),
]);

TerrainGeometry _compile(List<(double, double)> vertices) =>
    const TerrainCompiler().compile(<TerrainPolygonInput>[
      TerrainPolygonInput.fromWorld(
        sourcePath: 'test/aabb-sweep',
        identity: TerrainSourceIdentity(
          chunkIndex: 0,
          chunkKey: 'test',
          shapeId: 'shape',
        ),
        vertices: vertices,
      ),
    ], geometryVersion: 1);
