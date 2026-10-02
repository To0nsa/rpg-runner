import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/collision/terrain/terrain_pocket_query.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/collision/terrain/terrain_traversal_profile.dart';
import 'package:runner_core/ecs/stores/world_contact_capsule_store.dart';
import 'package:runner_core/enemies/enemy_terrain_profile.dart';
import 'package:test/test.dart';

void main() {
  test('opposing steep faces suspend a capsule above the floor', () {
    final pockets = _find(_compile(_wedge()));
    expect(pockets, hasLength(1));
    expect(pockets.single.center.xTicks / 1024, closeTo(70, .1));
    expect(pockets.single.center.yTicks / 1024, lessThan(80));
    expect(pockets.single.outline, hasLength(4));
  });

  test('widening the passage removes the warning', () {
    expect(_find(_compile(_wedge(gap: 40))), isEmpty);
  });

  test('walkable fill and buried faces do not report pockets', () {
    expect(
      _find(
        _compile([
          ..._wedge(),
          _polygon('fill', [(0, 20), (160, 20), (160, 110), (0, 110)]),
        ]),
      ),
      isEmpty,
    );
  });

  test('capsule size changes whether a narrowing gap is blocked', () {
    final geometry = _compile(_wedge(gap: 24));
    expect(_find(geometry, radius: 8), isEmpty);
    expect(_find(geometry, radius: 18), hasLength(1));
  });

  test('walkability uses the actor policy, not the player slope limit', () {
    final geometry = _compile([
      _polygon('left', [(0, 0), (40, 0), (100, 72), (0, 72)]),
      _polygon('right', [(160, 0), (200, 0), (200, 72), (100, 72)]),
    ]);
    expect(_find(geometry), isEmpty);
    expect(
      _find(
        geometry,
        profile: createGroundedEnemyTerrainProfile(
          capsule: WorldContactCapsuleDef(radius: 10, verticalHalfSegment: 12),
          maxWalkableSlopeDegrees: 45,
          minimumSupportUpComponent: 724,
        ).traversal,
      ),
      hasLength(1),
    );
  });

  test(
    'one-way edges, a single wall, and flying policies are not fall traps',
    () {
      expect(
        _find(_compile(_wedge(mode: TerrainCollisionMode.oneWay))),
        isEmpty,
      );
      expect(_find(_compile([_wedge().first])), isEmpty);
      expect(
        _find(
          _compile(_wedge()),
          profile: createFlyingEnemyTerrainProfile(
            capsule: WorldContactCapsuleDef(
              radius: 10,
              verticalHalfSegment: 12,
            ),
          ).traversal,
        ),
        isEmpty,
      );
    },
  );

  test('the complete capsule must fit above the pinch', () {
    expect(
      _find(
        _compile([
          ..._wedge(),
          _polygon('ceiling', [(45, 0), (95, 0), (95, 50), (45, 50)]),
        ]),
      ),
      isEmpty,
    );
  });

  test('source order cannot change warnings', () {
    final forward = _find(_compile(_wedge()));
    final reverse = _find(_compile(_wedge().reversed.toList()));
    expect(reverse.single.center, forward.single.center);
    expect(reverse.single.leftEdgeId, forward.single.leftEdgeId);
    expect(reverse.single.rightEdgeId, forward.single.rightEdgeId);
    expect(reverse.single.outline, forward.single.outline);
  });

  test('former rocky grove opposing faces reproduce the reported pocket', () {
    // Transformed small_rock_05 and small_rock_06 contours at the original
    // reported placements; independent of later authored level repairs.
    final geometry = _compile([
      _polygon('small_rock_05', [
        (467, 232),
        (462, 231),
        (459, 228),
        (451, 205),
        (449, 199),
        (446, 200),
        (443, 187),
        (442, 183),
        (428, 182),
        (428, 203),
        (426, 206),
        (423, 206),
        (423, 213),
        (422, 220),
        (421, 229),
        (419, 231),
        (419, 235),
        (467, 235),
      ]),
      _polygon('small_rock_06', [
        (465, 235),
        (468, 231),
        (469, 215),
        (473, 204),
        (478, 194),
        (480, 171),
        (486, 168),
        (487, 148),
        (494, 147),
        (527, 142),
        (530, 159),
        (540, 164),
        (543, 196),
        (548, 196),
        (554, 202),
        (555, 217),
        (558, 217),
        (561, 235),
      ]),
      _polygon('ground', [
        (410, 224),
        (580, 224),
        (580, 270),
        (410, 270),
      ], placement: false),
    ]);
    final pockets = _find(geometry, radius: 9.65, half: 12.85);
    expect(pockets, isNotEmpty);
    expect(
      pockets.any(
        (p) =>
            (p.center.xTicks / 1024 - 461.78).abs() < .1 &&
            (p.center.yTicks / 1024 - 193.58).abs() < .1,
      ),
      isTrue,
    );
  });
}

List<TerrainPocket> _find(
  TerrainGeometry geometry, {
  double radius = 10,
  double half = 12,
  TerrainTraversalProfile? profile,
}) => TerrainPocketQuery(geometry).find(
  radiusTicks: (radius * 1024).round(),
  verticalHalfSegmentTicks: (half * 1024).round(),
  profile:
      profile ??
      createEloiseTerrainTraversalProfile(
        enabled: true,
        isKinematic: false,
        useGravity: true,
        gravityScale: 1,
        collideCeilings: true,
        collideLeftWalls: true,
        collideRightWalls: true,
      ),
);

TerrainGeometry _compile(List<TerrainPolygonInput> polygons) =>
    const TerrainCompiler().compile(polygons, geometryVersion: 1);

List<TerrainPolygonInput> _wedge({
  double gap = 0,
  TerrainCollisionMode mode = TerrainCollisionMode.solid,
}) => [
  _polygon('left', [(0, 0), (40, 0), (70, 100), (0, 100)], mode: mode),
  _polygon('right', [
    (100 + gap, 0),
    (140 + gap, 0),
    (140 + gap, 100),
    (70 + gap, 100),
  ], mode: mode),
];

TerrainPolygonInput _polygon(
  String id,
  List<(double, double)> vertices, {
  TerrainCollisionMode mode = TerrainCollisionMode.solid,
  bool placement = true,
}) => TerrainPolygonInput.fromWorld(
  sourcePath: 'test/$id',
  identity: TerrainSourceIdentity(
    chunkIndex: 0,
    chunkKey: 'pocket',
    shapeId: id,
    placementKey: placement ? id : null,
  ),
  collisionMode: mode,
  vertices: vertices,
);
