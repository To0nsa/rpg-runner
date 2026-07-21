import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_edge_index.dart';
import 'package:runner_core/collision/terrain/terrain_ground_target_resolver.dart';
import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/collision/terrain/terrain_traversal_profile.dart';
import 'package:test/test.dart';

void main() {
  group('terrain ground target resolver', () {
    test('resolves the first canonical walkable support deterministically', () {
      final geometry = _compile(
        version: 7,
        polygons: [
          _polygon('floor', const [(0, 100), (300, 100), (300, 140), (0, 140)]),
        ],
      );
      final resolver = _resolver(geometry);
      final request = TerrainGroundTargetRequest(
        castOrigin: TerrainPoint.fromWorld(100, 20),
        aimDirection: TerrainDirection.fromDelta(0, 1),
        rangeTicks: 80 * 1024,
        maximumDownwardProbeTicks: 8 * 1024,
      );

      final first = resolver.resolve(request);
      final second = resolver.resolve(request);

      expect(first.isValid, isTrue);
      expect(first.geometryVersion, 7);
      expect(first.resolvedPoint, TerrainPoint.fromWorld(100, 100));
      expect(first.supportEdgeId, isNotNull);
      expect(second.resolvedPoint, first.resolvedPoint);
      expect(second.supportEdgeId, first.supportEdgeId);
      expect(resolver.canCommitPreview(first), isTrue);
    });

    test('rejects a downward snap whose final point exceeds cast range', () {
      final geometry = _compile(
        version: 1,
        polygons: [
          _polygon('floor', const [(0, 100), (300, 100), (300, 140), (0, 140)]),
        ],
      );
      final result = _resolver(geometry).resolve(
        TerrainGroundTargetRequest(
          castOrigin: TerrainPoint.fromWorld(20, 20),
          aimDirection: TerrainDirection.fromDelta(1, 0),
          rangeTicks: 80 * 1024,
          maximumDownwardProbeTicks: 100 * 1024,
        ),
      );

      expect(result.validity, TerrainGroundTargetValidity.outsideCastRange);
      expect(result.resolvedPoint, TerrainPoint.fromWorld(100, 100));
    });

    test('solid line of sight blocker invalidates the resolved support', () {
      final geometry = _compile(
        version: 1,
        polygons: [
          _polygon('floor', const [(0, 100), (300, 100), (300, 140), (0, 140)]),
          _polygon('wall', const [(80, 55), (120, 55), (120, 60), (80, 60)]),
        ],
      );
      final result = _resolver(geometry).resolve(
        TerrainGroundTargetRequest(
          castOrigin: TerrainPoint.fromWorld(100, 20),
          aimDirection: TerrainDirection.fromDelta(0, 1),
          rangeTicks: 80 * 1024,
          maximumDownwardProbeTicks: 8 * 1024,
        ),
      );

      expect(result.validity, TerrainGroundTargetValidity.lineOfSightBlocked);
      expect(result.blockerEdgeId, isNotNull);
    });

    test('one-way line of sight blocks only from its collidable side', () {
      final geometry = const TerrainCompiler().compile([
        TerrainPolygonInput.fromWorld(
          sourcePath: 'test/floor',
          identity: TerrainSourceIdentity(
            chunkIndex: 0,
            chunkKey: 'test',
            shapeId: 'floor',
          ),
          vertices: [(0, 100), (300, 100), (300, 140), (0, 140)],
        ),
        TerrainPolygonInput.fromWorld(
          sourcePath: 'test/one-way',
          identity: TerrainSourceIdentity(
            chunkIndex: 0,
            chunkKey: 'test',
            shapeId: 'one-way',
          ),
          collisionMode: TerrainCollisionMode.oneWay,
          vertices: [(60, 60), (100, 60), (100, 61), (60, 61)],
        ),
      ], geometryVersion: 1);
      final resolver = _resolver(geometry);
      final fromAbove = resolver.resolve(
        TerrainGroundTargetRequest(
          castOrigin: TerrainPoint.fromWorld(100, 20),
          aimDirection: TerrainDirection.fromDelta(0, 1),
          rangeTicks: 80 * 1024,
          maximumDownwardProbeTicks: 8 * 1024,
        ),
      );
      final fromBelow = resolver.resolve(
        TerrainGroundTargetRequest(
          castOrigin: TerrainPoint.fromWorld(100, 80),
          aimDirection: TerrainDirection.fromDelta(0, 1),
          rangeTicks: 20 * 1024,
          maximumDownwardProbeTicks: 2 * 1024,
        ),
      );

      expect(
        fromAbove.validity,
        TerrainGroundTargetValidity.lineOfSightBlocked,
      );
      expect(
        fromBelow.validity,
        isNot(TerrainGroundTargetValidity.lineOfSightBlocked),
      );
    });

    test(
      'geometry version mismatch invalidates rather than redirects preview',
      () {
        final version1 = _compile(
          version: 1,
          polygons: [
            _polygon('floor', const [
              (0, 100),
              (300, 100),
              (300, 140),
              (0, 140),
            ]),
          ],
        );
        final version2 = _compile(
          version: 2,
          polygons: [
            _polygon('floor', const [(0, 90), (300, 90), (300, 140), (0, 140)]),
          ],
        );
        final request = TerrainGroundTargetRequest(
          castOrigin: TerrainPoint.fromWorld(100, 20),
          aimDirection: TerrainDirection.fromDelta(0, 1),
          rangeTicks: 80 * 1024,
          maximumDownwardProbeTicks: 8 * 1024,
        );
        final preview = _resolver(version1).resolve(request);

        expect(preview.isValid, isTrue);
        expect(_resolver(version2).canCommitPreview(preview), isFalse);
      },
    );
  });
}

TerrainGroundTargetResolver _resolver(TerrainGeometry geometry) {
  return TerrainGroundTargetResolver(
    geometry: geometry,
    index: TerrainEdgeIndex(edges: geometry.edges),
    profile: createEloiseTerrainTraversalProfile(
      enabled: true,
      isKinematic: false,
      useGravity: true,
      gravityScale: 1,
      collideCeilings: true,
      collideLeftWalls: true,
      collideRightWalls: true,
    ),
  );
}

TerrainGeometry _compile({
  required int version,
  required List<TerrainPolygonInput> polygons,
}) => const TerrainCompiler().compile(polygons, geometryVersion: version);

TerrainPolygonInput _polygon(String id, List<(double, double)> vertices) =>
    TerrainPolygonInput.fromWorld(
      sourcePath: 'test/$id',
      identity: TerrainSourceIdentity(
        chunkIndex: 0,
        chunkKey: 'test',
        shapeId: id,
      ),
      vertices: vertices,
    );
