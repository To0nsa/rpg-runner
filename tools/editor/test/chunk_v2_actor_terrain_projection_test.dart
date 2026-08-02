import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/navigation/terrain_spawn_placement.dart';
import 'package:runner_editor/src/chunks/chunk_v2_actor_terrain_projection.dart';
import 'package:runner_editor/src/chunks/chunk_v2_collision_expansion.dart';

void main() {
  test('projects accepted actor policies without inventing extra graphs', () {
    final projection = ChunkV2ActorTerrainProjection.build(
      _expansion(_terrainInputs()),
    );
    final surfaces = projection.surfaceSet.surfaces;
    final flat32 = surfaces.singleWhere(
      (surface) => surface.id.shapeId == 'flat_32',
    );
    final flat31 = surfaces.singleWhere(
      (surface) => surface.id.shapeId == 'flat_31',
    );
    final steep50 = surfaces.singleWhere(
      (surface) => surface.id.shapeId == 'steep_50',
    );
    final oneWay = surfaces.singleWhere(
      (surface) => surface.id.shapeId == 'one_way',
    );

    final eloise = projection.groundedView(ChunkV2TerrainActor.eloise)!;
    final grojib = projection.groundedView(ChunkV2TerrainActor.grojib)!;
    final hashash = projection.groundedView(ChunkV2TerrainActor.hashash)!;
    expect(eloise.graph, isNull);
    expect(eloise.isEligible(steep50.id), isTrue);
    expect(grojib.isEligible(steep50.id), isFalse);
    expect(hashash.isEligible(steep50.id), isTrue);
    expect(grojib.graph, same(projection.bundle.grojibGraph));
    expect(hashash.graph, same(projection.bundle.hashashGraph));
    expect(grojib.graph!.surfaceSet, same(projection.surfaceSet));
    expect(hashash.graph!.surfaceSet, same(projection.surfaceSet));

    final solidWall = projection.expansion.geometry.edges.firstWhere(
      (edge) => edge.id.shapeId == 'flat_32' && edge.dxTicks == 0,
    );
    expect(projection.isUnocoSolidBlocker(solidWall.id), isTrue);
    expect(projection.isUnocoLocalHoverCandidate(solidWall.id), isFalse);
    expect(projection.isUnocoSolidBlocker(flat32.id), isTrue);
    expect(projection.isUnocoLocalHoverCandidate(flat32.id), isTrue);
    expect(projection.isUnocoSolidBlocker(oneWay.id), isFalse);
    expect(projection.isUnocoLocalHoverCandidate(oneWay.id), isFalse);

    final exactPerch = projection.derfPerchEvidence(flat32.id)!;
    final narrowPerch = projection.derfPerchEvidence(flat31.id)!;
    final steepPerch = projection.derfPerchEvidence(steep50.id)!;
    final oneWayPerch = projection.derfPerchEvidence(oneWay.id)!;
    expect(derfMinimumSupportSpanTicks, 32 * terrainPhysicsTicksPerWorldUnit);
    expect(exactPerch.slopeAndModeEligible, isTrue);
    expect(exactPerch.supportSpanEligible, isTrue);
    expect(exactPerch.perchEligible, isTrue);
    expect(narrowPerch.slopeAndModeEligible, isTrue);
    expect(narrowPerch.supportSpanEligible, isFalse);
    expect(steepPerch.slopeAndModeEligible, isFalse);
    expect(oneWayPerch.slopeAndModeEligible, isFalse);
  });

  test(
    'retains Core surface and graph signatures under source permutation',
    () {
      final inputs = _terrainInputs();
      final forward = ChunkV2ActorTerrainProjection.build(_expansion(inputs));
      final reversed = ChunkV2ActorTerrainProjection.build(
        _expansion(inputs.reversed),
      );

      expect(
        forward.bundle.surfaceSignature(),
        reversed.bundle.surfaceSignature(),
      );
      expect(forward.bundle.graphSignature(), reversed.bundle.graphSignature());
      expect(
        forward.unocoSolidBlockerIds.map((id) => id.canonicalKey).toSet(),
        reversed.unocoSolidBlockerIds.map((id) => id.canonicalKey).toSet(),
      );
      expect(
        forward.derfPerches
            .where((item) => item.perchEligible)
            .map((item) => item.surface.id.canonicalKey),
        reversed.derfPerches
            .where((item) => item.perchEligible)
            .map((item) => item.surface.id.canonicalKey),
      );
    },
  );
}

ChunkV2CollisionExpansion _expansion(Iterable<TerrainPolygonInput> inputs) {
  final inputList = List<TerrainPolygonInput>.of(inputs);
  final geometry = const TerrainCompiler().compile(
    inputList,
    geometryVersion: 7,
  );
  return ChunkV2CollisionExpansion(
    chunkKey: 'test',
    geometry: geometry,
    directShapeCount: inputList.length,
    expandedPrefabShapes: const <ChunkV2ExpandedPrefabShape>[],
  );
}

List<TerrainPolygonInput> _terrainInputs() => <TerrainPolygonInput>[
  _ground('flat_32', const <(double, double)>[(0, 100), (32, 100)]),
  _ground('flat_31', const <(double, double)>[(40, 100), (71, 100)]),
  _ground('steep_50', const <(double, double)>[(80, 100), (120, 52)]),
  _ground('one_way', const <(double, double)>[
    (130, 100),
    (170, 100),
  ], collisionMode: TerrainCollisionMode.oneWay),
];

TerrainPolygonInput _ground(
  String shapeId,
  List<(double, double)> top, {
  TerrainCollisionMode collisionMode = TerrainCollisionMode.solid,
}) => TerrainPolygonInput.fromWorld(
  sourcePath: 'test/$shapeId.json',
  identity: TerrainSourceIdentity(
    chunkIndex: 0,
    chunkKey: 'test',
    shapeId: shapeId,
  ),
  collisionMode: collisionMode,
  vertices: <(double, double)>[...top, (top.last.$1, 140), (top.first.$1, 140)],
);
