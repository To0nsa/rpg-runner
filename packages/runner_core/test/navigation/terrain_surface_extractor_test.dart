import 'dart:convert';
import 'dart:io';

import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_edge_id.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/navigation/terrain_surface_extractor.dart';
import 'package:runner_core/navigation/types/terrain_navigation_surface.dart';
import 'package:test/test.dart';

import '../fixtures/slopes_golden_fixture.dart';

void main() {
  const compiler = TerrainCompiler();
  const extractor = TerrainSurfaceExtractor();
  const enemyCatalog = EnemyCatalog();

  test('extracts every canonical upward non-vertical edge exactly once', () {
    final geometry = compiler.compile(
      buildSlopesGoldenInputs(),
      geometryVersion: 7,
    );
    final set = extractor.extract(geometry);
    final expectedIds = <Object>[
      for (final edge in geometry.edges)
        if (edge.dxTicks > 0 && edge.outwardNormal.yTicks < 0) edge.id,
    ];

    expect(set.geometryVersion, 7);
    expect(
      set.surfaces.map((surface) => surface.id),
      orderedEquals(expectedIds),
    );
    expect(
      set.surfaces.every(
        (surface) => surface.dxTicks > 0 && surface.outwardNormal.yTicks < 0,
      ),
      isTrue,
    );
    expect(
      set.surfaces.any((surface) => surface.id.shapeId == 'over_limit_island'),
      isTrue,
    );
    expect(
      set.surfaces.any(
        (surface) => surface.collisionMode == TerrainCollisionMode.oneWay,
      ),
      isTrue,
    );
    expect(() => set.surfaces.add(set.surfaces.first), throwsUnsupportedError);
  });

  test('surface interpolation, length, and profile eligibility are exact', () {
    final set = extractor.extract(
      compiler.compile(buildSlopesGoldenInputs(), geometryVersion: 1),
    );
    final slope = set.surfaces.singleWhere(
      (surface) =>
          surface.id.chunkIndex == 0 &&
          surface.id.shapeId == 'main' &&
          surface.start == TerrainPoint.fromWorld(96, 320) &&
          surface.end == TerrainPoint.fromWorld(160, 288),
    );

    expect(slope.yAtXTicks(physicsCoordinateToTicks(96)), 320 * 1024);
    expect(slope.yAtXTicks(physicsCoordinateToTicks(128)), 304 * 1024);
    expect(slope.yAtXTicks(physicsCoordinateToTicks(160)), 288 * 1024);
    expect(slope.lengthTicks, 73271);
    expect(
      () => slope.yAtXTicks(physicsCoordinateToTicks(95.5)),
      throwsRangeError,
    );

    final exactFortyFive = set.surfaces.singleWhere(
      (surface) => -surface.outwardNormal.yTicks == 724,
    );
    final exactSixty = set.surfaces.singleWhere(
      (surface) =>
          surface.dxTicks == 56 * terrainPhysicsTicksPerWorldUnit &&
          surface.dyTicks.abs() == 97 * terrainPhysicsTicksPerWorldUnit,
    );
    final overSixty = set.surfaces.singleWhere(
      (surface) =>
          surface.dxTicks == 55 * terrainPhysicsTicksPerWorldUnit &&
          surface.dyTicks.abs() == 97 * terrainPhysicsTicksPerWorldUnit,
    );
    final oneWay = set.surfaces.firstWhere(
      (surface) => surface.collisionMode == TerrainCollisionMode.oneWay,
    );
    final grojib = enemyCatalog.terrainContactProfile(EnemyId.grojib).traversal;
    final hashash = enemyCatalog
        .terrainContactProfile(EnemyId.hashash)
        .traversal;
    final unoco = enemyCatalog
        .terrainContactProfile(EnemyId.unocoDemon)
        .traversal;

    expect(exactFortyFive.isEligibleFor(grojib), isTrue);
    expect(exactSixty.isEligibleFor(grojib), isFalse);
    expect(exactSixty.isEligibleFor(hashash), isTrue);
    expect(overSixty.isEligibleFor(hashash), isFalse);
    expect(oneWay.isEligibleFor(hashash), isTrue);
    expect(oneWay.isEligibleFor(unoco), isFalse);
  });

  test('compatible exact seams form reciprocal canonical chains', () {
    final set = extractor.extract(
      compiler.compile(buildSlopesGoldenInputs(), geometryVersion: 3),
    );
    final left = set.surfaces.singleWhere(
      (surface) =>
          surface.id.chunkIndex == 0 &&
          surface.id.shapeId == 'main' &&
          surface.end == TerrainPoint.fromWorld(512, 320),
    );
    final right = set.surfaces.singleWhere(
      (surface) =>
          surface.id.chunkIndex == 1 &&
          surface.id.shapeId == 'limit_island' &&
          surface.start == TerrainPoint.fromWorld(512, 320),
    );

    expect(left.nextId, right.id);
    expect(right.previousId, left.id);
    expect(left.endKind, TerrainSurfaceEndpointKind.smooth);
    expect(right.startKind, TerrainSurfaceEndpointKind.smooth);
    expect(left.chainId, right.chainId);
    expect(left.chainId.compareTo(left.id), lessThanOrEqualTo(0));
    expect(left.chainId.compareTo(right.id), lessThanOrEqualTo(0));
    expect(set.indexOfId(left.id), isNotNull);
    expect(set.surfaceById(left.id), same(left));
  });

  test(
    'flat, peak, valley, and ledge classifications share intended chains',
    () {
      final set = extractor.extract(
        compiler.compile(buildSlopesGoldenInputs(), geometryVersion: 3),
      );
      TerrainNavigationSurface segment(
        double startX,
        double startY,
        double endX,
        double endY,
      ) => set.surfaces.singleWhere(
        (surface) =>
            surface.id.chunkIndex == 0 &&
            surface.id.shapeId == 'main' &&
            surface.start == TerrainPoint.fromWorld(startX, startY) &&
            surface.end == TerrainPoint.fromWorld(endX, endY),
      );

      final flatBeforePeak = segment(0, 320, 96, 320);
      final uphill = segment(96, 320, 160, 288);
      final peakFlat = segment(160, 288, 224, 288);
      final downhill = segment(224, 288, 288, 320);
      final valleyFlat = segment(288, 320, 320, 320);
      final chainId = flatBeforePeak.chainId;

      expect(<TerrainEdgeId>[
        uphill.chainId,
        peakFlat.chainId,
        downhill.chainId,
        valleyFlat.chainId,
      ], everyElement(chainId));
      expect(uphill.startKind, TerrainSurfaceEndpointKind.corner);
      expect(uphill.endKind, TerrainSurfaceEndpointKind.corner);
      expect(downhill.endKind, TerrainSurfaceEndpointKind.corner);

      final pitLeft = set.surfaces.singleWhere(
        (surface) =>
            surface.id.chunkIndex == 2 &&
            surface.id.shapeId == 'main_left' &&
            surface.end.xTicks == physicsCoordinateToTicks(1376),
      );
      final pitRight = set.surfaces.singleWhere(
        (surface) =>
            surface.id.chunkIndex == 2 &&
            surface.id.shapeId == 'landing_right' &&
            surface.start.xTicks == physicsCoordinateToTicks(1440),
      );
      expect(pitLeft.endIsLedge, isTrue);
      expect(pitRight.startIsLedge, isTrue);
      expect(pitLeft.chainId, isNot(pitRight.chainId));
    },
  );

  test(
    'material boundaries preserve intentional ledges and separate chains',
    () {
      final geometry = compiler.compile(<TerrainPolygonInput>[
        _rectangle(
          chunkIndex: 0,
          shapeId: 'stone',
          minX: -100,
          maxX: 0,
          materialKey: 'stone',
        ),
        _rectangle(
          chunkIndex: 1,
          shapeId: 'moss',
          minX: 0,
          maxX: 100,
          materialKey: 'moss',
        ),
      ], geometryVersion: 4);
      final set = extractor.extract(geometry);
      final stone = set.surfaces.singleWhere(
        (surface) => surface.id.shapeId == 'stone',
      );
      final moss = set.surfaces.singleWhere(
        (surface) => surface.id.shapeId == 'moss',
      );

      expect(stone.end, moss.start);
      expect(stone.nextId, isNull);
      expect(moss.previousId, isNull);
      expect(stone.endIsLedge, isTrue);
      expect(moss.startIsLedge, isTrue);
      expect(stone.chainId, stone.id);
      expect(moss.chainId, moss.id);
    },
  );

  test('order, winding, and no-op version changes preserve the signature', () {
    final forwardInputs = buildSlopesGoldenInputs();
    final reverseInputs = buildSlopesGoldenInputs().reversed.toList();
    final first = extractor.extract(
      compiler.compile(forwardInputs, geometryVersion: 10),
    );
    final reordered = extractor.extract(
      compiler.compile(reverseInputs, geometryVersion: 11),
    );
    final clockwise = extractor.extract(
      compiler.compile(<TerrainPolygonInput>[
        _windingFixture(reversed: false),
      ], geometryVersion: 12),
    );
    final counterclockwise = extractor.extract(
      compiler.compile(<TerrainPolygonInput>[
        _windingFixture(reversed: true),
      ], geometryVersion: 13),
    );

    expect(first.signature(), reordered.signature());
    expect(
      first.canonicalRecords(),
      orderedEquals(reordered.canonicalRecords()),
    );
    expect(first.geometryVersion, isNot(reordered.geometryVersion));
    expect(clockwise.signature(), counterclockwise.signature());
    expect(first.signature(), matches(RegExp(r'^[0-9a-f]{64}$')));
  });

  test('canonical IDs and signatures repeat in fresh Dart processes', () {
    Map<String, Object?> runFreshProcess() {
      final result = Process.runSync(Platform.resolvedExecutable, <String>[
        'run',
        'test/helpers/print_terrain_surface_signature.dart',
      ], workingDirectory: Directory.current.path);
      expect(result.exitCode, 0, reason: result.stderr.toString());
      return jsonDecode(result.stdout.toString().trim())
          as Map<String, Object?>;
    }

    expect(runFreshProcess(), runFreshProcess());
  });

  test('negative coordinates and an empty geometry remain deterministic', () {
    final negative = extractor.extract(
      compiler.compile(<TerrainPolygonInput>[
        TerrainPolygonInput.fromWorld(
          sourcePath: 'negative/slope',
          identity: TerrainSourceIdentity(
            chunkIndex: -2,
            chunkKey: 'negative',
            shapeId: 'slope',
          ),
          vertices: const <(double, double)>[
            (-10, -10),
            (0, -5),
            (0, 10),
            (-10, 10),
          ],
          materialKey: 'stone',
        ),
      ], geometryVersion: 20),
    );
    final surface = negative.surfaces.single;
    expect(surface.yAtXTicks(physicsCoordinateToTicks(-5)), -7680);

    final empty = extractor.extract(
      compiler.compile(const <TerrainPolygonInput>[], geometryVersion: 21),
    );
    expect(empty.surfaces, isEmpty);
    expect(empty.geometryVersion, 21);
    expect(empty.signature(), matches(RegExp(r'^[0-9a-f]{64}$')));
  });
}

TerrainPolygonInput _rectangle({
  required int chunkIndex,
  required String shapeId,
  required double minX,
  required double maxX,
  required String materialKey,
}) => TerrainPolygonInput.fromWorld(
  sourcePath: 'terrain/$shapeId',
  identity: TerrainSourceIdentity(
    chunkIndex: chunkIndex,
    chunkKey: 'chunk_$chunkIndex',
    shapeId: shapeId,
  ),
  vertices: <(double, double)>[(minX, 0), (maxX, 0), (maxX, 100), (minX, 100)],
  surfaceKind: 'terrain',
  materialKey: materialKey,
);

TerrainPolygonInput _windingFixture({required bool reversed}) {
  const vertices = <(double, double)>[
    (-32, 8),
    (0, -8),
    (32, 8),
    (32, 32),
    (-32, 32),
  ];
  return TerrainPolygonInput.fromWorld(
    sourcePath: 'winding/fixture',
    identity: TerrainSourceIdentity(
      chunkIndex: -1,
      chunkKey: 'base',
      shapeId: 'winding',
    ),
    vertices: reversed ? vertices.reversed : vertices,
    surfaceKind: 'terrain',
    materialKey: 'stone',
  );
}
