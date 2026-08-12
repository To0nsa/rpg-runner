import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/systems/flying_enemy_locomotion_system.dart';
import 'package:runner_core/ecs/systems/world_motion_authority.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/players/characters/eloise.dart';
import 'package:runner_core/players/player_catalog.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/tuning/flying_enemy_tuning.dart';
import 'package:test/test.dart';

void main() {
  group('Unoco terrain-relative hover', () {
    test('uses the highest local solid below flat and sloped footprints', () {
      final flat = _Harness.create(
        geometry: _flatTerrain,
        enemyX: 500,
        enemyY: 350,
        playerX: 550,
      )..configureHover(height: 100, desiredRange: 50);
      final uphill = _Harness.create(
        geometry: _uphillTerrain,
        enemyX: 500,
        enemyY: 350,
        playerX: 550,
      )..configureHover(height: 100, desiredRange: 50);
      final downhill = _Harness.create(
        geometry: _downhillTerrain,
        enemyX: 500,
        enemyY: 350,
        playerX: 550,
      )..configureHover(height: 100, desiredRange: 50);

      flat.stepLocomotion();
      uphill.stepLocomotion();
      downhill.stepLocomotion();

      expect(flat.effectiveFlightReferenceY, 500);
      expect(uphill.effectiveFlightReferenceY, closeTo(398.375, 0.01));
      expect(downhill.effectiveFlightReferenceY, closeTo(398.375, 0.01));
      expect(flat.enemyVelocityY, greaterThan(0));
      expect(uphill.enemyVelocityY, lessThan(0));
      expect(downhill.enemyVelocityY, lessThan(0));
    });

    test(
      'retains the last local reference over a pit then uses level plane',
      () {
        final retained = _Harness.create(
          geometry: _shortFloorTerrain,
          enemyX: 100,
          enemyY: 350,
          playerX: 150,
          groundTopY: 800,
        )..configureHover(height: 100, desiredRange: 50);

        retained.stepLocomotion();
        expect(retained.effectiveFlightReferenceY, 500);
        retained.enemyX = 400;
        retained.playerX = 450;
        retained.stepLocomotion();

        expect(retained.hasLocalTerrainReference, isTrue);
        expect(retained.effectiveFlightReferenceY, 500);

        final planeFallback = _Harness.create(
          geometry: _shortFloorTerrain,
          enemyX: 400,
          enemyY: 350,
          playerX: 450,
          groundTopY: 800,
        )..configureHover(height: 100, desiredRange: 50);
        planeFallback.stepLocomotion();

        expect(planeFallback.hasLocalTerrainReference, isFalse);
        expect(planeFallback.effectiveFlightReferenceY, 800);
        expect(planeFallback.enemyVelocityY, greaterThan(0));
      },
    );
  });

  group('Unoco terrain collision', () {
    for (final scenario in <_BlockingScenario>[
      _BlockingScenario(
        name: 'one-pixel wall at maximum speed',
        geometry: _thinWallTerrain,
        startX: 200,
        startY: 250,
        velocityX: 12000,
        velocityY: 0,
      ),
      _BlockingScenario(
        name: 'solid slope face',
        geometry: _blockingSlopeTerrain,
        startX: 200,
        startY: 250,
        velocityX: 12000,
        velocityY: 0,
      ),
      _BlockingScenario(
        name: 'solid ceiling underside',
        geometry: _ceilingTerrain,
        startX: 200,
        startY: 200,
        velocityX: 0,
        velocityY: -12000,
      ),
      _BlockingScenario(
        name: 'solid floor face without grounding',
        geometry: _floorCollisionTerrain,
        startX: 200,
        startY: 200,
        velocityX: 0,
        velocityY: 12000,
      ),
      _BlockingScenario(
        name: 'concave solid boundary',
        geometry: _concaveTerrain,
        startX: 250,
        startY: 125,
        velocityX: 12000,
        velocityY: 0,
      ),
    ]) {
      test('sweeps the full capsule against ${scenario.name}', () {
        final harness = _Harness.create(
          geometry: scenario.geometry,
          enemyX: scenario.startX,
          enemyY: scenario.startY,
          playerX: 900,
        );

        harness.stepMotion(
          velocityX: scenario.velocityX,
          velocityY: scenario.velocityY,
        );

        final expectedX = scenario.startX + scenario.velocityX / _tickHz;
        final expectedY = scenario.startY + scenario.velocityY / _tickHz;
        expect(
          harness.enemyX == expectedX && harness.enemyY == expectedY,
          isFalse,
          reason: 'the requested sweep must be clipped by the solid',
        );
        expect(harness.blockingContactCount, greaterThan(0));
        expect(harness.terrainGrounded, isFalse);
        expect(harness.legacyGrounded, isFalse);
      });
    }

    test(
      'ignores one-way terrain from above through below without support',
      () {
        final harness = _Harness.create(
          geometry: _oneWayTerrain,
          enemyX: 200,
          enemyY: 200,
          playerX: 900,
        );

        harness.stepMotion(velocityX: 0, velocityY: 12000);

        expect(harness.enemyY, closeTo(400, 1e-9));
        expect(harness.blockingContactCount, 0);
        expect(harness.terrainGrounded, isFalse);
        expect(harness.legacyGrounded, isFalse);
      },
    );
  });

  group('Unoco deterministic solid clearance', () {
    test('takes the same bounded route around a wall and returns to hover', () {
      final first = _detourHarness();
      final second = _detourHarness();
      final initialRng = first.rngState;
      final firstRoute = <(int, int, int)>[];
      final secondRoute = <(int, int, int)>[];
      var usedClearance = false;
      var minimumY = first.enemyY;
      var priorCandidateId = -1;

      for (var tick = 0; tick < 180; tick += 1) {
        final priorX = first.enemyX;
        final priorY = first.enemyY;
        first.stepLocomotion();
        second.stepLocomotion();
        firstRoute.add(first.quantizedRoutePoint);
        secondRoute.add(second.quantizedRoutePoint);
        usedClearance |= first.clearanceCandidateId > 0;
        if (first.enemyY < minimumY) minimumY = first.enemyY;
        expect(first.clearanceCandidateId, inInclusiveRange(-1, 3));
        expect(first.clearanceHoldTicksLeft, inInclusiveRange(0, 12));
        expect(
          (first.enemyX - priorX) * (first.enemyX - priorX) +
              (first.enemyY - priorY) * (first.enemyY - priorY),
          lessThanOrEqualTo(50),
          reason: 'clearance must remain bounded motion, never relocation',
        );
        expect(
          (priorCandidateId == 1 && first.clearanceCandidateId == 2) ||
              (priorCandidateId == 2 && first.clearanceCandidateId == 1),
          isFalse,
          reason: 'opposed tangent candidates must not oscillate tick to tick',
        );
        expect(first.terrainGrounded, isFalse);
        expect(first.legacyGrounded, isFalse);
        priorCandidateId = first.clearanceCandidateId;
      }

      expect(firstRoute, secondRoute);
      expect(usedClearance, isTrue);
      expect(minimumY, lessThan(270));
      expect(first.enemyX, greaterThan(340));
      expect(first.enemyY, closeTo(300, 25));
      expect(first.rngState, initialRng);
    });
  });
}

class _Harness {
  _Harness._({
    required this.world,
    required this.player,
    required this.enemy,
    required this.authority,
    required this.movement,
    required this.locomotion,
    required this.groundTopY,
  });

  factory _Harness.create({
    required TerrainGeometry geometry,
    required double enemyX,
    required double enemyY,
    required double playerX,
    double playerY = 100,
    double groundTopY = 1000,
    UnocoDemonTuning tuning = const UnocoDemonTuning(),
  }) {
    final world = EcsWorld(seed: 424242);
    final movement = MovementTuningDerived.from(
      eloiseCharacter.tuning.movement,
      tickHz: _tickHz,
    );
    final playerArchetype = PlayerCatalogDerived.from(
      eloiseCharacter.catalog,
      movement: movement,
      resources: ResourceTuningDerived.from(eloiseCharacter.tuning.resource),
    ).archetype;
    final player = EntityFactory(world).createPlayer(
      posX: _playerSpawnX,
      posY: 0,
      velX: 0,
      velY: 0,
      facing: playerArchetype.facing,
      grounded: false,
      body: playerArchetype.body,
      collider: playerArchetype.collider,
      health: playerArchetype.health,
      mana: playerArchetype.mana,
      stamina: playerArchetype.stamina,
    );
    final enemyArchetype = const EnemyCatalog().get(EnemyId.unocoDemon);
    final enemy = EntityFactory(world).createEnemy(
      enemyId: EnemyId.unocoDemon,
      posX: enemyX,
      posY: enemyY,
      velX: 0,
      velY: 0,
      facing: Facing.right,
      body: enemyArchetype.body,
      collider: enemyArchetype.collider,
      health: enemyArchetype.health,
      mana: enemyArchetype.mana,
      stamina: enemyArchetype.stamina,
      tags: enemyArchetype.tags,
      resistance: enemyArchetype.resistance,
    );
    final authority = TerrainMultiBodyWorldMotionAuthority(
      geometry: geometry,
      playerProfile: playerArchetype.terrainTraversalProfile,
    );
    authority.initializePlayer(
      world,
      player: player,
      archetype: playerArchetype,
    );
    final playerTransformIndex = world.transform.indexOf(player);
    world.transform.posX[playerTransformIndex] = playerX;
    world.transform.posY[playerTransformIndex] = playerY;
    world.body.enabled[world.body.indexOf(player)] = false;
    return _Harness._(
      world: world,
      player: player,
      enemy: enemy,
      authority: authority,
      movement: movement,
      locomotion: FlyingEnemyLocomotionSystem(
        unocoDemonTuning: UnocoDemonTuningDerived.from(tuning, tickHz: _tickHz),
        worldMotionAuthority: authority,
      ),
      groundTopY: groundTopY,
    );
  }

  final EcsWorld world;
  final int player;
  final int enemy;
  final TerrainMultiBodyWorldMotionAuthority authority;
  final MovementTuningDerived movement;
  final FlyingEnemyLocomotionSystem locomotion;
  final double groundTopY;
  int _tick = 0;

  void configureHover({required double height, required double desiredRange}) {
    final index = world.flyingEnemySteering.indexOf(enemy);
    world.flyingEnemySteering.initialized[index] = true;
    world.flyingEnemySteering.desiredRange[index] = desiredRange;
    world.flyingEnemySteering.desiredRangeHoldLeftS[index] = 1000;
    world.flyingEnemySteering.flightTargetAboveGround[index] = height;
    world.flyingEnemySteering.flightTargetHoldLeftS[index] = 1000;
  }

  void stepLocomotion() {
    _tick += 1;
    authority.prepareTick(world, player: player, currentTick: _tick);
    locomotion.step(
      world,
      player: player,
      groundTopY: groundTopY,
      dtSeconds: 1 / _tickHz,
      currentTick: _tick,
    );
    _integratePreparedTick();
  }

  void stepMotion({required double velocityX, required double velocityY}) {
    _tick += 1;
    authority.prepareTick(world, player: player, currentTick: _tick);
    final transformIndex = world.transform.indexOf(enemy);
    world.transform.velX[transformIndex] = velocityX;
    world.transform.velY[transformIndex] = velocityY;
    _integratePreparedTick();
  }

  void _integratePreparedTick() {
    authority.step(
      world,
      player: player,
      movement: movement,
      fixedPointPilotEnabled: false,
      fixedPointSubpixelScale: terrainPhysicsTicksPerWorldUnit,
      currentTick: _tick,
    );
  }

  int get _transformIndex => world.transform.indexOf(enemy);
  int get _steeringIndex => world.flyingEnemySteering.indexOf(enemy);
  int get _contactIndex => world.terrainContact.indexOf(enemy);

  double get enemyX => world.transform.posX[_transformIndex];
  set enemyX(double value) => world.transform.posX[_transformIndex] = value;
  double get enemyY => world.transform.posY[_transformIndex];
  double get enemyVelocityX => world.transform.velX[_transformIndex];
  double get enemyVelocityY => world.transform.velY[_transformIndex];
  set playerX(double value) =>
      world.transform.posX[world.transform.indexOf(player)] = value;
  bool get hasLocalTerrainReference =>
      world.flyingEnemySteering.hasLocalTerrainReference[_steeringIndex];
  double get effectiveFlightReferenceY =>
      world.flyingEnemySteering.effectiveFlightReferenceY[_steeringIndex];
  int get rngState => world.flyingEnemySteering.rngState[_steeringIndex];
  double get desiredRange =>
      world.flyingEnemySteering.desiredRange[_steeringIndex];
  double get desiredRangeHoldLeftS =>
      world.flyingEnemySteering.desiredRangeHoldLeftS[_steeringIndex];
  double get flightTargetAboveGround =>
      world.flyingEnemySteering.flightTargetAboveGround[_steeringIndex];
  double get flightTargetHoldLeftS =>
      world.flyingEnemySteering.flightTargetHoldLeftS[_steeringIndex];
  int get blockingContactCount =>
      world.terrainContact.blockingContactCount[_contactIndex];
  bool get terrainGrounded => world.terrainContact.grounded[_contactIndex];
  bool get legacyGrounded =>
      world.collision.grounded[world.collision.indexOf(enemy)];
  int get clearanceCandidateId =>
      world.flyingEnemySteering.clearanceCandidateId[_steeringIndex];
  int get clearanceHoldTicksLeft =>
      world.flyingEnemySteering.clearanceHoldTicksLeft[_steeringIndex];
  (int, int, int) get quantizedRoutePoint => (
    physicsCoordinateToTicks(enemyX, name: 'routeX'),
    physicsCoordinateToTicks(enemyY, name: 'routeY'),
    clearanceCandidateId,
  );
}

class _BlockingScenario {
  const _BlockingScenario({
    required this.name,
    required this.geometry,
    required this.startX,
    required this.startY,
    required this.velocityX,
    required this.velocityY,
  });

  final String name;
  final TerrainGeometry geometry;
  final double startX;
  final double startY;
  final double velocityX;
  final double velocityY;
}

_Harness _detourHarness() => _Harness.create(
  geometry: _detourTerrain,
  enemyX: 200,
  enemyY: 300,
  playerX: 700,
  groundTopY: 480,
  tuning: const UnocoDemonTuning(
    unocoDemonAccelX: 18000,
    unocoDemonDecelX: 18000,
    unocoDemonVerticalDeadzone: 0,
  ),
)..configureHover(height: 180, desiredRange: 50);

TerrainGeometry _compile(
  String shapeId,
  List<(double, double)> vertices, {
  TerrainCollisionMode collisionMode = TerrainCollisionMode.solid,
}) => const TerrainCompiler().compile(<TerrainPolygonInput>[
  TerrainPolygonInput.fromWorld(
    sourcePath: 'test/$shapeId',
    identity: TerrainSourceIdentity(
      chunkIndex: 0,
      chunkKey: 'test',
      shapeId: shapeId,
    ),
    vertices: vertices,
    collisionMode: collisionMode,
  ),
  TerrainPolygonInput.fromWorld(
    sourcePath: 'test/player-spawn',
    identity: TerrainSourceIdentity(
      chunkIndex: 99,
      chunkKey: 'test-support',
      shapeId: 'player-spawn',
    ),
    vertices: <(double, double)>[
      (2000, 1000),
      (2200, 1000),
      (2200, 1100),
      (2000, 1100),
    ],
  ),
], geometryVersion: 1);

final TerrainGeometry _flatTerrain = _compile('flat', <(double, double)>[
  (0, 500),
  (1000, 500),
  (1000, 700),
  (0, 700),
]);
final TerrainGeometry _uphillTerrain = _compile('uphill', <(double, double)>[
  (0, 500),
  (1000, 300),
  (1000, 700),
  (0, 700),
]);
final TerrainGeometry _downhillTerrain = _compile(
  'downhill',
  <(double, double)>[(0, 300), (1000, 500), (1000, 700), (0, 700)],
);
final TerrainGeometry _shortFloorTerrain = _compile(
  'short-floor',
  <(double, double)>[(0, 500), (250, 500), (250, 700), (0, 700)],
);
final TerrainGeometry _thinWallTerrain = _compile(
  'thin-wall',
  <(double, double)>[(300, 0), (301, 0), (301, 600), (300, 600)],
);
final TerrainGeometry _blockingSlopeTerrain = _compile(
  'blocking-slope',
  <(double, double)>[(300, 300), (500, 100), (550, 500)],
);
final TerrainGeometry _ceilingTerrain = _compile('ceiling', <(double, double)>[
  (0, 100),
  (600, 100),
  (600, 102),
  (0, 102),
]);
final TerrainGeometry _floorCollisionTerrain = _compile(
  'floor-collision',
  <(double, double)>[(0, 300), (600, 300), (600, 302), (0, 302)],
);
final TerrainGeometry _concaveTerrain = _compile('concave', <(double, double)>[
  (300, 100),
  (450, 100),
  (450, 400),
  (400, 400),
  (400, 150),
  (300, 150),
]);
final TerrainGeometry _oneWayTerrain = _compile('one-way', <(double, double)>[
  (0, 300),
  (600, 300),
  (600, 310),
  (0, 310),
], collisionMode: TerrainCollisionMode.oneWay);
final TerrainGeometry _detourTerrain = const TerrainCompiler().compile(
  <TerrainPolygonInput>[
    TerrainPolygonInput.fromWorld(
      sourcePath: 'test/detour-floor',
      identity: TerrainSourceIdentity(
        chunkIndex: 0,
        chunkKey: 'test',
        shapeId: 'detour-floor',
      ),
      vertices: <(double, double)>[
        (0, 480),
        (1000, 480),
        (1000, 700),
        (0, 700),
      ],
    ),
    TerrainPolygonInput.fromWorld(
      sourcePath: 'test/detour-wall',
      identity: TerrainSourceIdentity(
        chunkIndex: 0,
        chunkKey: 'test',
        shapeId: 'detour-wall',
      ),
      vertices: <(double, double)>[
        (300, 250),
        (320, 250),
        (320, 480),
        (300, 480),
      ],
    ),
    TerrainPolygonInput.fromWorld(
      sourcePath: 'test/player-spawn',
      identity: TerrainSourceIdentity(
        chunkIndex: 99,
        chunkKey: 'test-support',
        shapeId: 'player-spawn',
      ),
      vertices: <(double, double)>[
        (2000, 1000),
        (2200, 1000),
        (2200, 1100),
        (2000, 1100),
      ],
    ),
  ],
  geometryVersion: 1,
);

const int _tickHz = 60;
const double _playerSpawnX = 2100;
