import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_edge_index.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/collision/terrain/terrain_traversal_profile.dart';
import 'package:runner_core/combat/aim_motion_forecast.dart';
import 'package:runner_core/ecs/stores/body_store.dart';
import 'package:runner_core/ecs/stores/world_contact_capsule_store.dart';
import 'package:runner_core/ecs/systems/gravity_system.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/tuning/physics_tuning.dart';
import 'package:test/test.dart';

void main() {
  for (final swimming in [false, true]) {
    test('gravity forecast matches live gravity, swimming=$swimming', () {
      final world = EcsWorld();
      final actor = _actor(
        world,
        y: 100,
        vy: -180,
        body: const BodyDef(gravityScale: 0.75, maxVelY: 200),
      );
      world.gravityControl.setSuppressForTicks(actor, 4);
      if (swimming) {
        world.swimState.add(actor);
        world.swimState.setImmersion(world.swimState.indexOf(actor), 1000);
      }
      const physics = PhysicsTuning(
        gravityY: 1000,
        fixedPointPilot: FixedPointPilotTuning(enabled: true),
      );
      final forecast = AimMotionForecast(tickHz: 60, physics: physics)
        ..reset(world, actor);
      final movement = MovementTuningDerived.from(
        const MovementTuning(),
        tickHz: 60,
      );
      final gravity = GravitySystem();
      final ti = world.transform.indexOf(actor);
      for (var tick = 0; tick < 60; tick++) {
        final oldY = world.transform.posY[ti];
        final oldVy = world.transform.velY[ti];
        forecast.advance(1);
        expect(world.transform.posY[ti], oldY);
        expect(world.transform.velY[ti], oldVy);
        gravity.step(world, movement, physics: physics);
        world.transform.posY[ti] += world.transform.velY[ti] / 60;
        expect(forecast.y, closeTo(world.transform.posY[ti], 1e-9));
        expect(forecast.velocityY, world.transform.velY[ti]);
      }
    });
  }

  test('flying motion stays linear without gravity', () {
    final world = EcsWorld();
    final actor = _actor(
      world,
      y: 100,
      vy: -180,
      vx: 60,
      body: const BodyDef(useGravity: false),
    );
    final forecast = AimMotionForecast(tickHz: 60)
      ..reset(world, actor)
      ..advance(30);
    expect(forecast.isLinear, isTrue);
    expect((forecast.x, forecast.y), (130.0, 10.0));
  });

  test('fall lands on the first platform and keeps the body above it', () {
    final terrain = _terrain([
      _box('upper', -1000, 140, 1000, 145),
      _box('lower', -1000, 200, 1000, 220),
    ]);
    final world = EcsWorld();
    final actor = _actor(world, y: 100, vy: 180);
    final forecast =
        AimMotionForecast(tickHz: 60, terrainProvider: () => terrain)
          ..reset(world, actor)
          ..advance(60);
    expect(forecast.y, closeTo(130, 0.1));
    expect(forecast.velocityY.abs(), lessThan(0.01));
    expect(world.terrainContact.grounded.single, isFalse);
  });

  test(
    'a ceiling stops upward prediction before gravity turns it downward',
    () {
      final terrain = _terrain([_box('ceiling', -1000, 50, 1000, 60)]);
      final world = EcsWorld();
      final actor = _actor(world, y: 100, vy: -360);
      final forecast = AimMotionForecast(
        tickHz: 60,
        terrainProvider: () => terrain,
      )..reset(world, actor);
      for (var tick = 0; tick < 30; tick++) {
        forecast.advance(1);
        expect(forecast.y, greaterThanOrEqualTo(70));
      }
      expect(forecast.velocityY, greaterThan(0));
    },
  );

  test('one-way platform permits ascent and catches descent', () {
    final terrain = _terrain([
      _box('platform', -1000, 80, 1000, 85, oneWay: true),
    ]);
    final world = EcsWorld();
    final actor = _actor(world, y: 110, vy: -360);
    final forecast =
        AimMotionForecast(tickHz: 60, terrainProvider: () => terrain)
          ..reset(world, actor)
          ..advance(18);
    expect(forecast.y, lessThan(70));
    forecast.advance(42);
    expect(forecast.y, closeTo(70, 0.1));
  });

  test('walking beyond finite support predicts a fall into the gap', () {
    final terrain = _terrain([_box('edge', 0, 140, 130, 200)]);
    final world = EcsWorld();
    final actor = _actor(world, y: 130, vx: 180);
    final forecast =
        AimMotionForecast(tickHz: 60, terrainProvider: () => terrain)
          ..reset(world, actor)
          ..advance(30);
    expect(forecast.x, greaterThan(150));
    expect(forecast.y, greaterThan(150));
  });

  test('forecast uses a replacement terrain publication', () {
    var terrain = _terrain([_box('floor', -1000, 140, 1000, 200)]);
    final world = EcsWorld();
    final actor = _actor(world, y: 100, vy: 180);
    final forecast =
        AimMotionForecast(tickHz: 60, terrainProvider: () => terrain)
          ..reset(world, actor)
          ..advance(30);
    expect(forecast.y, closeTo(130, 0.1));
    terrain = _terrain([]);
    forecast
      ..reset(world, actor)
      ..advance(30);
    expect(forecast.y, greaterThan(300));
  });

  test('a wall stops the forecast without sliding through the floor', () {
    final terrain = _terrain([
      _box('floor', -1000, 140, 1000, 200),
      _box('wall', 180, 0, 200, 140),
    ]);
    final world = EcsWorld();
    final actor = _actor(world, y: 130, vx: 180);
    final forecast =
        AimMotionForecast(tickHz: 60, terrainProvider: () => terrain)
          ..reset(world, actor)
          ..advance(60);
    expect(forecast.x, closeTo(175, 0.1));
    expect(forecast.y, closeTo(130, 0.1));
    expect(forecast.velocityX, 0);
  });

  test(
    'landing and supported motion follow a slope instead of a flat clamp',
    () {
      final terrain = _terrain([
        TerrainPolygonInput.fromWorld(
          sourcePath: 'test/slope',
          identity: TerrainSourceIdentity(
            chunkIndex: 0,
            chunkKey: 'test',
            shapeId: 'slope',
          ),
          vertices: [(-1000, 100), (1000, 300), (1000, 600), (-1000, 600)],
        ),
      ]);
      final world = EcsWorld();
      final actor = _actor(world, y: 100, vx: 120, vy: 180);
      final forecast =
          AimMotionForecast(tickHz: 60, terrainProvider: () => terrain)
            ..reset(world, actor)
            ..advance(60);
      final supportY = 100 + (forecast.x + 1000) * 0.1;
      expect(forecast.x, greaterThan(200));
      expect(forecast.y, closeTo(supportY - 10.025, 0.1));
    },
  );
}

int _actor(
  EcsWorld world, {
  required double y,
  double vx = 0,
  double vy = 0,
  BodyDef body = const BodyDef(),
}) {
  final entity = world.createEntity();
  world.transform.add(entity, posX: 100, posY: y, velX: vx, velY: vy);
  world.body.add(entity, body);
  world.worldContactCapsule.add(
    entity,
    WorldContactCapsuleDef(radius: 5, verticalHalfSegment: 5),
  );
  world.terrainTraversalProfile.add(
    entity,
    createEloiseTerrainTraversalProfile(
      enabled: true,
      isKinematic: false,
      useGravity: body.useGravity,
      gravityScale: body.gravityScale,
      collideCeilings: true,
      collideLeftWalls: true,
      collideRightWalls: true,
    ),
  );
  world.terrainContact.add(entity);
  return entity;
}

AimTerrain _terrain(List<TerrainPolygonInput> polygons) {
  final geometry = const TerrainCompiler().compile(
    polygons,
    geometryVersion: 1,
  );
  return (geometry: geometry, index: TerrainEdgeIndex(edges: geometry.edges));
}

TerrainPolygonInput _box(
  String id,
  double left,
  double top,
  double right,
  double bottom, {
  bool oneWay = false,
}) => TerrainPolygonInput.fromWorld(
  sourcePath: 'test/$id',
  identity: TerrainSourceIdentity(chunkIndex: 0, chunkKey: 'test', shapeId: id),
  collisionMode: oneWay
      ? TerrainCollisionMode.oneWay
      : TerrainCollisionMode.solid,
  vertices: [(left, top), (right, top), (right, bottom), (left, bottom)],
);
