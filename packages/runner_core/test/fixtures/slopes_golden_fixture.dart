import 'package:runner_core/collision/terrain/capsule_segment_kernel.dart';
import 'package:runner_core/collision/terrain/terrain_edge.dart';
import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/collision/terrain/upright_capsule.dart';

const String slopesGoldenFixtureId = 'slopes_golden_v1';
const int slopesGoldenGeometryVersion = 1;
const int slopesGoldenChunkWidth = 512;
const int slopesGoldenChunkHeight = 512;

/// Builds the exact four-chunk Phase 0 source fixture in world coordinates.
List<TerrainPolygonInput> buildSlopesGoldenInputs() {
  return <TerrainPolygonInput>[
    _ground(
      chunkIndex: 0,
      shapeId: 'main',
      top: const <(double, double)>[
        (0, 320),
        (96, 320),
        (160, 288),
        (224, 288),
        (288, 320),
        (320, 320),
        (352, 336),
        (384, 320),
        (416, 320),
        (448, 304),
        (480, 320),
        (512, 320),
      ],
    ),
    _ground(
      chunkIndex: 1,
      shapeId: 'limit_island',
      top: const <(double, double)>[
        (0, 320),
        (64, 320),
        (120, 223),
        (176, 223),
        (224, 271),
        (256, 271),
      ],
    ),
    _ground(
      chunkIndex: 1,
      shapeId: 'over_limit_island',
      top: const <(double, double)>[
        (288, 320),
        (343, 223),
        (368, 223),
        (368, 320),
        (512, 320),
      ],
    ),
    _polygon(
      chunkIndex: 1,
      shapeId: 'ceiling_solid',
      vertices: const <(double, double)>[
        (400, 128),
        (480, 128),
        (480, 192),
        (448, 176),
        (416, 192),
        (400, 192),
      ],
    ),
    _polygon(
      chunkIndex: 1,
      shapeId: 'one_way_slope',
      collisionMode: TerrainCollisionMode.oneWay,
      surfaceKind: 'oneWay',
      vertices: const <(double, double)>[
        (384, 272),
        (448, 240),
        (448, 248),
        (384, 280),
      ],
    ),
    _polygon(
      chunkIndex: 1,
      shapeId: 'narrow_peak',
      vertices: const <(double, double)>[(464, 320), (472, 304), (480, 320)],
    ),
    _ground(
      chunkIndex: 2,
      shapeId: 'main_left',
      top: const <(double, double)>[
        (0, 320),
        (96, 320),
        (160, 288),
        (224, 288),
        (288, 320),
        (352, 320),
      ],
    ),
    _ground(
      chunkIndex: 2,
      shapeId: 'landing_right',
      top: const <(double, double)>[(416, 288), (512, 288)],
    ),
    _polygon(
      chunkIndex: 2,
      shapeId: 'one_way_bridge',
      collisionMode: TerrainCollisionMode.oneWay,
      surfaceKind: 'oneWay',
      vertices: const <(double, double)>[
        (336, 256),
        (448, 224),
        (448, 232),
        (336, 264),
      ],
    ),
    _ground(
      chunkIndex: 3,
      shapeId: 'main',
      top: const <(double, double)>[
        (0, 288),
        (64, 320),
        (256, 320),
        (320, 304),
        (512, 304),
      ],
    ),
    _polygon(
      chunkIndex: 3,
      shapeId: 'derf_valid',
      surfaceKind: 'perch',
      vertices: const <(double, double)>[
        (96, 256),
        (160, 239),
        (160, 272),
        (96, 272),
      ],
    ),
    _polygon(
      chunkIndex: 3,
      shapeId: 'derf_narrow',
      surfaceKind: 'perch',
      vertices: const <(double, double)>[
        (192, 256),
        (223, 248),
        (223, 272),
        (192, 272),
      ],
    ),
    _polygon(
      chunkIndex: 3,
      shapeId: 'unoco_blocker',
      vertices: const <(double, double)>[
        (288, 144),
        (416, 144),
        (416, 208),
        (352, 192),
        (288, 208),
      ],
    ),
  ];
}

/// Produces reviewed raw-kernel contacts without applying gameplay policy.
List<CapsuleSweepHit> buildSlopesGoldenContactHits(TerrainGeometry geometry) {
  final kernel = CapsuleSegmentKernel();
  final hits = <CapsuleSweepHit>[];

  void addHit({
    required UprightCapsule capsule,
    required int dxTicks,
    required int dyTicks,
    required TerrainEdge edge,
  }) {
    final hit = CapsuleSweepHit();
    kernel.sweep(
      capsule: capsule,
      displacementXTicks: dxTicks,
      displacementYTicks: dyTicks,
      edge: edge,
      out: hit,
    );
    if (!hit.hit) {
      throw StateError('Golden contact missed ${edge.id}.');
    }
    hits.add(hit);
  }

  addHit(
    capsule: UprightCapsule(
      center: TerrainPoint.fromWorld(48, 270),
      radiusTicks: 10 * terrainPhysicsTicksPerWorldUnit,
      verticalHalfSegmentTicks: 20 * terrainPhysicsTicksPerWorldUnit,
    ),
    dxTicks: 0,
    dyTicks: 40 * terrainPhysicsTicksPerWorldUnit,
    edge: geometry.edges.firstWhere(
      (edge) =>
          edge.id.chunkIndex == 0 &&
          edge.id.shapeId == 'main' &&
          edge.start == TerrainPoint.fromWorld(0, 320) &&
          edge.end == TerrainPoint.fromWorld(96, 320),
    ),
  );
  addHit(
    capsule: UprightCapsule(
      center: TerrainPoint.fromWorld(128, 258),
      radiusTicks: 10 * terrainPhysicsTicksPerWorldUnit,
      verticalHalfSegmentTicks: 20 * terrainPhysicsTicksPerWorldUnit,
    ),
    dxTicks: 0,
    dyTicks: 50 * terrainPhysicsTicksPerWorldUnit,
    edge: geometry.edges.firstWhere(
      (edge) =>
          edge.id.chunkIndex == 0 &&
          edge.id.shapeId == 'main' &&
          edge.dxTicks == 64 * terrainPhysicsTicksPerWorldUnit &&
          edge.dyTicks == -32 * terrainPhysicsTicksPerWorldUnit,
    ),
  );
  addHit(
    capsule: UprightCapsule(
      center: TerrainPoint.fromWorld(840, 270),
      radiusTicks: 10 * terrainPhysicsTicksPerWorldUnit,
      verticalHalfSegmentTicks: 20 * terrainPhysicsTicksPerWorldUnit,
    ),
    dxTicks: 100 * terrainPhysicsTicksPerWorldUnit,
    dyTicks: 0,
    edge: geometry.edges.firstWhere(
      (edge) =>
          edge.id.chunkIndex == 1 &&
          edge.id.shapeId == 'over_limit_island' &&
          edge.start.x == 880 &&
          edge.end.x == 880,
    ),
  );
  return hits;
}

TerrainPolygonInput _ground({
  required int chunkIndex,
  required String shapeId,
  required List<(double, double)> top,
}) {
  final last = top.last;
  final first = top.first;
  return _polygon(
    chunkIndex: chunkIndex,
    shapeId: shapeId,
    vertices: <(double, double)>[
      ...top,
      (last.$1, slopesGoldenChunkHeight.toDouble()),
      (first.$1, slopesGoldenChunkHeight.toDouble()),
    ],
  );
}

TerrainPolygonInput _polygon({
  required int chunkIndex,
  required String shapeId,
  required List<(double, double)> vertices,
  TerrainCollisionMode collisionMode = TerrainCollisionMode.solid,
  String surfaceKind = 'terrain',
}) {
  return TerrainPolygonInput.fromWorld(
    sourcePath: 'terrain/chunk$chunkIndex/$shapeId',
    identity: TerrainSourceIdentity(
      chunkIndex: chunkIndex,
      chunkKey: 'chunk_$chunkIndex',
      shapeId: shapeId,
    ),
    vertices: vertices,
    collisionMode: collisionMode,
    surfaceKind: surfaceKind,
    materialKey: 'golden',
    transform: TerrainSourceTransform(
      translateXSourceTicks:
          chunkIndex * slopesGoldenChunkWidth * terrainSourceTicksPerWorldUnit,
    ),
  );
}
