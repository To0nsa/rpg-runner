import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/collision/terrain/terrain_motion_request.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/combat/control_lock.dart';
import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/systems/anim/anim_system.dart';
import 'package:runner_core/ecs/systems/enemy_death_state_system.dart';
import 'package:runner_core/ecs/systems/gravity_system.dart';
import 'package:runner_core/ecs/systems/ground_enemy_locomotion_system.dart';
import 'package:runner_core/ecs/systems/world_motion_authority.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/enemies/death_behavior.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/players/characters/eloise.dart';
import 'package:runner_core/players/player_catalog.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/tuning/ground_enemy_tuning.dart';
import 'package:runner_core/tuning/physics_tuning.dart';
import 'package:test/test.dart';

void main() {
  group('ground enemy terrain locomotion', () {
    test('Grojib keeps authored surface speed on flat and 45 degrees', () {
      final flat = _Harness.create(
        enemyId: EnemyId.grojib,
        geometry: _flatTerrain,
        enemyX: 300,
        enemySupportY: 1200,
        playerX: 1500,
      );
      final slope = _Harness.create(
        enemyId: EnemyId.grojib,
        geometry: _uphill45Terrain,
        enemyX: 300,
        enemySupportY: 900,
        playerX: 900,
      );

      flat.settle();
      slope.settle();
      flat.step(targetX: 1000);
      slope.step(targetX: 1000);

      expect(flat.motionMode, TerrainMotionMode.groundedSurface);
      expect(slope.motionMode, TerrainMotionMode.groundedSurface);
      expect(flat.supportedTravelTicks.abs(), closeTo(2048, 2));
      expect(slope.supportedTravelTicks.abs(), closeTo(2048, 2));
      expect(
        slope.supportedTravelTicks.abs(),
        closeTo(flat.supportedTravelTicks.abs(), 2),
      );
      expect(slope.enemyVelX, greaterThan(0));
      expect(slope.enemyVelY, lessThan(0));
    });

    test(
      'Hashash keeps authored surface speed in both directions at 60 degrees',
      () {
        final harness = _Harness.create(
          enemyId: EnemyId.hashash,
          geometry: _uphill60Terrain,
          enemyX: 300,
          enemySupportY: 2480.5,
          playerX: 900,
        );
        harness.settle();

        harness.step(targetX: 1000);
        final uphillTravel = harness.supportedTravelTicks.abs();
        expect(harness.motionMode, TerrainMotionMode.groundedSurface);
        expect(uphillTravel, closeTo(2048, 2));
        expect(harness.enemyVelX, greaterThan(0));
        expect(harness.enemyVelY, lessThan(0));

        harness.step(targetX: 0);
        final downhillTravel = harness.supportedTravelTicks.abs();
        expect(downhillTravel, closeTo(uphillTravel, 2));
        expect(harness.enemyVelX, lessThan(0));
        expect(harness.enemyVelY, greaterThan(0));
        expect(harness.enemyGrounded, isTrue);
      },
    );

    test('status and arrival multipliers apply before support projection', () {
      final harness = _Harness.create(
        enemyId: EnemyId.grojib,
        geometry: _uphill45Terrain,
        enemyX: 300,
        enemySupportY: 900,
        playerX: 900,
      );
      harness.settle();
      final modifierIndex = harness.world.statModifier.indexOf(harness.enemy);
      harness.world.statModifier.moveSpeedMul[modifierIndex] = 0.5;

      harness.step(
        targetX: harness.enemyX + 100,
        speedScale: 0.8,
        stateSpeedMul: 0.5,
      );

      // 120 units/s * 50% status * 80% engagement * 50% state = 24.
      expect(harness.supportedTravelTicks.abs(), closeTo(410, 2));
      expect(harness.enemyGrounded, isTrue);
    });

    test(
      'acceleration, stopping, and reversal stay in surface-speed space',
      () {
        final harness = _Harness.create(
          enemyId: EnemyId.grojib,
          geometry: _uphill45Terrain,
          enemyX: 300,
          enemySupportY: 900,
          playerX: 900,
          accelX: 1200,
          decelX: 1200,
        );
        harness.settle();

        final accelerating = <int>[];
        for (var tick = 0; tick < 3; tick += 1) {
          harness.step(targetX: 1000);
          accelerating.add(harness.supportedTravelTicks.abs());
        }
        expect(accelerating[1], greaterThan(accelerating[0]));
        expect(accelerating[2], greaterThan(accelerating[1]));

        final stopping = <int>[];
        for (var tick = 0; tick < 3; tick += 1) {
          harness.step(targetX: harness.enemyX);
          stopping.add(harness.supportedTravelTicks.abs());
        }
        expect(stopping[1], lessThan(stopping[0]));
        expect(stopping[2], lessThanOrEqualTo(stopping[1]));

        harness.step(targetX: 0);
        expect(harness.enemyVelX, lessThan(0));
        expect(harness.enemyVelY, greaterThan(0));
        expect(harness.enemyGrounded, isTrue);
      },
    );

    test('move and stun locks stop tangent motion without losing support', () {
      for (final lock in <int>[LockFlag.move, LockFlag.stun]) {
        final harness = _Harness.create(
          enemyId: EnemyId.grojib,
          geometry: _uphill45Terrain,
          enemyX: 300,
          enemySupportY: 900,
          playerX: 900,
        );
        harness.settle();
        harness.step(targetX: 1000);
        final beforeX = harness.enemyX;
        final beforeY = harness.enemyY;
        harness.world.controlLock.addLock(
          harness.enemy,
          lock,
          10,
          harness.tick,
        );

        harness.step(targetX: 1000);

        expect(harness.supportedTravelTicks, 0, reason: 'lock=$lock');
        expect(
          harness.enemyX,
          closeTo(beforeX, 1 / 1024),
          reason: 'lock=$lock',
        );
        expect(
          harness.enemyY,
          closeTo(beforeY, 1 / 1024),
          reason: 'lock=$lock',
        );
        expect(harness.enemyGrounded, isTrue, reason: 'lock=$lock');
      }
    });

    test('ordinary pursuit accepts exact four-pixel step and snap', () {
      final step = _Harness.create(
        enemyId: EnemyId.grojib,
        geometry: _fourPixelStepTerrain,
        enemyX: 280,
        enemySupportY: 304,
        playerX: 650,
        speedX: 600,
      );
      step.settle();
      var usedStep = false;
      for (var tick = 0; tick < 30; tick += 1) {
        step.step(targetX: 650);
        usedStep = usedStep || step.usedStep;
      }
      expect(
        usedStep,
        isTrue,
        reason:
            'x=${step.enemyX} grounded=${step.enemyGrounded} '
            'hitRight=${step.hitRight}',
      );
      expect(step.enemyGrounded, isTrue);

      final snap = _Harness.create(
        enemyId: EnemyId.grojib,
        geometry: _fourPixelDropTerrain,
        enemyX: 280,
        enemySupportY: 300,
        playerX: 650,
        speedX: 600,
      );
      snap.settle();
      var usedSnap = false;
      for (var tick = 0; tick < 30; tick += 1) {
        snap.step(targetX: 650);
        usedSnap = usedSnap || snap.usedSnap;
      }
      expect(usedSnap, isTrue);
      expect(snap.enemyGrounded, isTrue);
    });

    test('five-pixel transitions do not activate step or snap helpers', () {
      bool activated({required TerrainGeometry geometry, required bool snap}) {
        final harness = _Harness.create(
          enemyId: EnemyId.grojib,
          geometry: geometry,
          enemyX: 280,
          enemySupportY: 300,
          playerX: 650,
          speedX: 600,
        );
        harness.settle();
        for (var tick = 0; tick < 30; tick += 1) {
          final contact = harness.world.terrainContact.indexOf(harness.enemy);
          final prior =
              harness.world.terrainContact.supportEdgeId[contact]?.shapeId;
          harness.step(targetX: 650);
          final current =
              harness.world.terrainContact.supportEdgeId[contact]?.shapeId;
          if (prior?.startsWith('lower') == true &&
              current?.startsWith('upper') == true &&
              (snap ? harness.usedSnap : harness.usedStep)) {
            return true;
          }
        }
        return false;
      }

      expect(activated(geometry: _fivePixelStepTerrain, snap: false), isFalse);
      expect(activated(geometry: _fivePixelDropTerrain, snap: true), isFalse);
    });

    test('seams and one-way supports traverse while walls block pursuit', () {
      for (final scenario in <({TerrainGeometry geometry, double supportY})>[
        (geometry: _stitchedFlatTerrain, supportY: 300),
        (geometry: _oneWayTerrain, supportY: 300),
      ]) {
        final harness = _Harness.create(
          enemyId: EnemyId.grojib,
          geometry: scenario.geometry,
          enemyX: 280,
          enemySupportY: scenario.supportY,
          playerX: 650,
          speedX: 600,
        );
        harness.settle();
        harness.world.spawnState.removeEntity(harness.enemy);
        final anim = AnimSystem(
          tickHz: 60,
          enemyCatalog: const EnemyCatalog(),
          playerMovement: harness.movement,
          playerAnimTuning: AnimTuningDerived.from(
            eloiseCharacter.tuning.anim,
            tickHz: 60,
          ),
        );
        for (var tick = 0; tick < 20; tick += 1) {
          harness.step(targetX: 650);
          anim.step(
            harness.world,
            player: harness.player,
            currentTick: harness.tick,
          );
          expect(harness.enemyGrounded, isTrue, reason: 'tick=$tick');
          expect(
            harness.world.animState.anim[harness.world.animState.indexOf(
              harness.enemy,
            )],
            isNot(anyOf(AnimKey.jump, AnimKey.fall)),
            reason: 'tick=$tick',
          );
        }
        expect(harness.enemyX, greaterThan(400));
      }

      final wall = _Harness.create(
        enemyId: EnemyId.grojib,
        geometry: _floorAndWallTerrain,
        enemyX: 280,
        enemySupportY: 300,
        playerX: 650,
        speedX: 600,
      );
      wall.settle();
      var blocked = false;
      for (var tick = 0; tick < 30; tick += 1) {
        wall.step(targetX: 650);
        blocked = blocked || wall.hitRight;
      }
      expect(blocked, isTrue);
      expect(wall.enemyX, lessThan(400));
      expect(wall.enemyVelX, 0);
      expect(wall.enemyGrounded, isTrue);
    });

    test('jump launch leaves support and stays world-space for the tick', () {
      final harness = _Harness.create(
        enemyId: EnemyId.grojib,
        geometry: _uphill45Terrain,
        enemyX: 300,
        enemySupportY: 900,
        playerX: 900,
      );
      harness.settle();
      final startY = harness.enemyY;

      harness.step(targetX: 1000, jumpNow: true, commitMoveDirX: 1);

      expect(harness.motionMode, TerrainMotionMode.worldSpace);
      expect(harness.enemyGrounded, isFalse);
      expect(harness.usedSnap, isFalse);
      expect(harness.enemyY, lessThan(startY));
      expect(harness.enemyVelX, greaterThan(0));
      expect(harness.enemyVelY, lessThan(0));
    });

    test('enemy walk phase advances from resolved support distance', () {
      final harness = _Harness.create(
        enemyId: EnemyId.grojib,
        geometry: _uphill45Terrain,
        enemyX: 300,
        enemySupportY: 900,
        playerX: 900,
      );
      harness.settle();
      harness.world.spawnState.removeEntity(harness.enemy);
      harness.step(targetX: 1000);
      final anim = AnimSystem(
        tickHz: 60,
        enemyCatalog: const EnemyCatalog(),
        playerMovement: harness.movement,
        playerAnimTuning: AnimTuningDerived.from(
          eloiseCharacter.tuning.anim,
          tickHz: 60,
        ),
      );
      final animIndex = harness.world.animState.indexOf(harness.enemy);

      anim.step(harness.world, player: harness.player, currentTick: 200);
      final advancedPhase =
          harness.world.animState.groundedLocomotionPhaseBp[animIndex];
      expect(advancedPhase, greaterThan(0));

      final motionIndex = harness.world.resolvedMotion.indexOf(harness.enemy);
      harness.world.resolvedMotion.supportedTravelTicks[motionIndex] = 0;
      anim.step(harness.world, player: harness.player, currentTick: 201);
      expect(
        harness.world.animState.groundedLocomotionPhaseBp[animIndex],
        advancedPhase,
      );
    });

    test(
      'ground-impact death reads final terrain support and keeps timeout',
      () {
        final grounded = _Harness.create(
          enemyId: EnemyId.grojib,
          geometry: _uphill45Terrain,
          enemyX: 300,
          enemySupportY: 900,
          playerX: 900,
        );
        grounded.settle();
        grounded.world.collision.grounded[grounded.world.collision.indexOf(
              grounded.enemy,
            )] =
            false;
        grounded.world.health.hp[grounded.world.health.indexOf(
              grounded.enemy,
            )] =
            0;
        final death = EnemyDeathStateSystem(tickHz: 60);
        death.step(grounded.world, currentTick: grounded.tick);
        expect(
          grounded.world.deathState.phase[grounded.world.deathState.indexOf(
            grounded.enemy,
          )],
          DeathPhase.deathAnim,
        );

        final airborne = _Harness.create(
          enemyId: EnemyId.hashash,
          geometry: _uphill60Terrain,
          enemyX: 300,
          enemySupportY: 2480.5,
          playerX: 900,
        );
        airborne.settle();
        airborne.step(targetX: 1000, jumpNow: true, commitMoveDirX: 1);
        airborne.world.health.hp[airborne.world.health.indexOf(
              airborne.enemy,
            )] =
            0;
        death.step(airborne.world, currentTick: airborne.tick);
        final deathIndex = airborne.world.deathState.indexOf(airborne.enemy);
        expect(
          airborne.world.deathState.phase[deathIndex],
          DeathPhase.fallingUntilGround,
        );

        for (
          var tick = 0;
          tick < 120 &&
              airborne.world.deathState.phase[deathIndex] ==
                  DeathPhase.fallingUntilGround;
          tick += 1
        ) {
          airborne.step(targetX: 1000);
          death.step(airborne.world, currentTick: airborne.tick);
        }
        expect(airborne.enemyGrounded, isTrue);
        expect(
          airborne.world.deathState.phase[deathIndex],
          DeathPhase.deathAnim,
        );

        final timedOut = _Harness.create(
          enemyId: EnemyId.grojib,
          geometry: _flatTerrain,
          enemyX: 300,
          enemySupportY: 1200,
          playerX: 1500,
        );
        timedOut.settle();
        timedOut.step(targetX: 1000, jumpNow: true, commitMoveDirX: 1);
        timedOut.world.health.hp[timedOut.world.health.indexOf(
              timedOut.enemy,
            )] =
            0;
        death.step(timedOut.world, currentTick: timedOut.tick);
        final timeoutIndex = timedOut.world.deathState.indexOf(timedOut.enemy);
        death.step(timedOut.world, currentTick: timedOut.tick + 180);
        expect(
          timedOut.world.deathState.phase[timeoutIndex],
          DeathPhase.deathAnim,
        );
      },
    );
  });
}

final class _Harness {
  _Harness._({
    required this.world,
    required this.player,
    required this.enemy,
    required this.movement,
    required this.authority,
    required this.locomotion,
  });

  factory _Harness.create({
    required EnemyId enemyId,
    required TerrainGeometry geometry,
    required double enemyX,
    required double enemySupportY,
    required double playerX,
    double speedX = 120,
    double accelX = 100000,
    double decelX = 100000,
  }) {
    final world = EcsWorld(seed: 17);
    final movement = MovementTuningDerived.from(
      eloiseCharacter.tuning.movement,
      tickHz: 60,
    );
    final playerArchetype = PlayerCatalogDerived.from(
      eloiseCharacter.catalog,
      movement: movement,
      resources: ResourceTuningDerived.from(eloiseCharacter.tuning.resource),
    ).archetype;
    final player = EntityFactory(world).createPlayer(
      posX: playerX,
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
    final enemyArchetype = const EnemyCatalog().get(enemyId);
    final enemy = EntityFactory(world).createEnemy(
      enemyId: enemyId,
      posX: enemyX,
      posY:
          enemySupportY -
          enemyArchetype.collider.offsetY -
          enemyArchetype.collider.halfY -
          12,
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
      statusImmunity: enemyArchetype.statusImmunity,
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
    final locomotion = GroundEnemyLocomotionSystem(
      groundEnemyTuning: GroundEnemyTuningDerived.from(
        GroundEnemyTuning(
          locomotion: GroundEnemyLocomotionTuning(
            speedX: speedX,
            accelX: accelX,
            decelX: decelX,
            stopDistanceX: 0.1,
            jumpSpeed: 500,
          ),
        ),
        tickHz: 60,
      ),
    );
    return _Harness._(
      world: world,
      player: player,
      enemy: enemy,
      movement: movement,
      authority: authority,
      locomotion: locomotion,
    );
  }

  final EcsWorld world;
  final int player;
  final int enemy;
  final MovementTuningDerived movement;
  final TerrainMultiBodyWorldMotionAuthority authority;
  final GroundEnemyLocomotionSystem locomotion;
  final GravitySystem _gravity = GravitySystem();
  int _tick = 0;

  int get tick => _tick;

  double get enemyX => world.transform.posX[world.transform.indexOf(enemy)];
  double get enemyY => world.transform.posY[world.transform.indexOf(enemy)];
  double get enemyVelX => world.transform.velX[world.transform.indexOf(enemy)];
  double get enemyVelY => world.transform.velY[world.transform.indexOf(enemy)];
  bool get enemyGrounded =>
      world.terrainContact.grounded[world.terrainContact.indexOf(enemy)];
  int get supportedTravelTicks =>
      world.resolvedMotion.supportedTravelTicks[world.resolvedMotion.indexOf(
        enemy,
      )];
  TerrainMotionMode get motionMode =>
      world.resolvedMotion.mode[world.resolvedMotion.indexOf(enemy)];
  bool get usedStep =>
      world.terrainContact.usedStep[world.terrainContact.indexOf(enemy)];
  bool get usedSnap =>
      world.terrainContact.usedSnap[world.terrainContact.indexOf(enemy)];
  bool get hitRight =>
      world.terrainContact.hitRight[world.terrainContact.indexOf(enemy)];

  void settle() {
    for (var tick = 0; tick < 120 && !enemyGroundedOrUninitialized; tick += 1) {
      step(targetX: enemyX);
    }
    expect(enemyGrounded, isTrue, reason: 'enemy failed to settle on terrain');
    for (
      var tick = 0;
      tick < 120 && (enemyVelX.abs() + enemyVelY.abs()) > 1e-6;
      tick += 1
    ) {
      step(targetX: enemyX);
    }
    expect(enemyVelX.abs() + enemyVelY.abs(), lessThanOrEqualTo(1e-6));
  }

  bool get enemyGroundedOrUninitialized =>
      world.terrainContact.has(enemy) && enemyGrounded;

  void step({
    required double targetX,
    bool jumpNow = false,
    int commitMoveDirX = 0,
    double speedScale = 1,
    double stateSpeedMul = 1,
  }) {
    _tick += 1;
    authority.prepareTick(world, player: player, currentTick: _tick);
    final navIndex = world.navIntent.indexOf(enemy);
    world.navIntent.desiredX[navIndex] = targetX;
    world.navIntent.jumpNow[navIndex] = jumpNow;
    world.navIntent.hasPlan[navIndex] = false;
    world.navIntent.commitMoveDirX[navIndex] = commitMoveDirX;
    world.navIntent.hasSafeSurface[navIndex] = false;
    final engagementIndex = world.engagementIntent.indexOf(enemy);
    world.engagementIntent.desiredTargetX[engagementIndex] = targetX;
    world.engagementIntent.speedScale[engagementIndex] = speedScale;
    world.engagementIntent.arrivalSlowRadiusX[engagementIndex] = 0;
    world.engagementIntent.stateSpeedMul[engagementIndex] = stateSpeedMul;
    locomotion.step(
      world,
      player: player,
      dtSeconds: movement.dtSeconds,
      currentTick: _tick,
    );
    _gravity.step(world, movement, physics: const PhysicsTuning());
    authority.step(
      world,
      player: player,
      movement: movement,
      fixedPointPilotEnabled: false,
      fixedPointSubpixelScale: terrainPhysicsTicksPerWorldUnit,
      currentTick: _tick,
    );
  }
}

final TerrainGeometry _flatTerrain = const TerrainCompiler().compile([
  TerrainPolygonInput.fromWorld(
    sourcePath: 'test/flat',
    identity: TerrainSourceIdentity(
      chunkIndex: 0,
      chunkKey: 'test',
      shapeId: 'flat',
    ),
    vertices: [(0, 1200), (2000, 1200), (2000, 1500), (0, 1500)],
  ),
], geometryVersion: 1);

final TerrainGeometry _uphill45Terrain = const TerrainCompiler().compile([
  TerrainPolygonInput.fromWorld(
    sourcePath: 'test/uphill-45',
    identity: TerrainSourceIdentity(
      chunkIndex: 0,
      chunkKey: 'test',
      shapeId: 'uphill-45',
    ),
    vertices: [(0, 1200), (1200, 0), (1500, 1500), (0, 1500)],
  ),
], geometryVersion: 1);

final TerrainGeometry _uphill60Terrain = const TerrainCompiler().compile([
  TerrainPolygonInput.fromWorld(
    sourcePath: 'test/uphill-60',
    identity: TerrainSourceIdentity(
      chunkIndex: 0,
      chunkKey: 'test',
      shapeId: 'uphill-60',
    ),
    vertices: [(0, 3000), (1120, 1060), (1400, 3600), (0, 3600)],
  ),
], geometryVersion: 1);

final TerrainGeometry _fourPixelStepTerrain = const TerrainCompiler().compile([
  TerrainPolygonInput.fromWorld(
    sourcePath: 'test/lower-step',
    identity: TerrainSourceIdentity(
      chunkIndex: 0,
      chunkKey: 'test',
      shapeId: 'lower-step',
    ),
    vertices: [(0, 304), (320, 304), (320, 500), (0, 500)],
  ),
  TerrainPolygonInput.fromWorld(
    sourcePath: 'test/upper-step',
    identity: TerrainSourceIdentity(
      chunkIndex: 0,
      chunkKey: 'test',
      shapeId: 'upper-step',
    ),
    vertices: [(320, 300), (700, 300), (700, 500), (320, 500)],
  ),
], geometryVersion: 1);

final TerrainGeometry _fourPixelDropTerrain = const TerrainCompiler().compile([
  TerrainPolygonInput.fromWorld(
    sourcePath: 'test/high-drop',
    identity: TerrainSourceIdentity(
      chunkIndex: 0,
      chunkKey: 'test',
      shapeId: 'high-drop',
    ),
    vertices: [(0, 300), (320, 300), (320, 500), (0, 500)],
  ),
  TerrainPolygonInput.fromWorld(
    sourcePath: 'test/low-drop',
    identity: TerrainSourceIdentity(
      chunkIndex: 0,
      chunkKey: 'test',
      shapeId: 'low-drop',
    ),
    vertices: [(320, 304), (700, 304), (700, 500), (320, 500)],
  ),
], geometryVersion: 1);

final TerrainGeometry _fivePixelStepTerrain = const TerrainCompiler().compile([
  TerrainPolygonInput.fromWorld(
    sourcePath: 'test/lower-step-5',
    identity: TerrainSourceIdentity(
      chunkIndex: 0,
      chunkKey: 'test',
      shapeId: 'lower-step-5',
    ),
    vertices: [(0, 300), (320, 300), (320, 500), (0, 500)],
  ),
  TerrainPolygonInput.fromWorld(
    sourcePath: 'test/upper-step-5',
    identity: TerrainSourceIdentity(
      chunkIndex: 0,
      chunkKey: 'test',
      shapeId: 'upper-step-5',
    ),
    vertices: [(320, 295), (700, 295), (700, 500), (320, 500)],
  ),
], geometryVersion: 1);

final TerrainGeometry _fivePixelDropTerrain = const TerrainCompiler().compile([
  TerrainPolygonInput.fromWorld(
    sourcePath: 'test/lower-drop-5',
    identity: TerrainSourceIdentity(
      chunkIndex: 0,
      chunkKey: 'test',
      shapeId: 'lower-drop-5',
    ),
    vertices: [(0, 300), (320, 300), (320, 500), (0, 500)],
  ),
  TerrainPolygonInput.fromWorld(
    sourcePath: 'test/upper-drop-5',
    identity: TerrainSourceIdentity(
      chunkIndex: 0,
      chunkKey: 'test',
      shapeId: 'upper-drop-5',
    ),
    vertices: [(320, 305), (700, 305), (700, 500), (320, 500)],
  ),
], geometryVersion: 1);

final TerrainGeometry _stitchedFlatTerrain = const TerrainCompiler().compile([
  TerrainPolygonInput.fromWorld(
    sourcePath: 'test/stitched-left',
    identity: TerrainSourceIdentity(
      chunkIndex: 0,
      chunkKey: 'left',
      shapeId: 'ground',
    ),
    vertices: [(0, 300), (320, 300), (320, 500), (0, 500)],
  ),
  TerrainPolygonInput.fromWorld(
    sourcePath: 'test/stitched-right',
    identity: TerrainSourceIdentity(
      chunkIndex: 1,
      chunkKey: 'right',
      shapeId: 'ground',
    ),
    vertices: [(320, 300), (700, 300), (700, 500), (320, 500)],
  ),
], geometryVersion: 1);

final TerrainGeometry _oneWayTerrain = const TerrainCompiler().compile([
  TerrainPolygonInput.fromWorld(
    sourcePath: 'test/one-way',
    identity: TerrainSourceIdentity(
      chunkIndex: 0,
      chunkKey: 'test',
      shapeId: 'one-way',
    ),
    collisionMode: TerrainCollisionMode.oneWay,
    vertices: [(0, 300), (700, 300), (700, 310), (0, 310)],
  ),
], geometryVersion: 1);

final TerrainGeometry _floorAndWallTerrain = const TerrainCompiler().compile([
  TerrainPolygonInput.fromWorld(
    sourcePath: 'test/floor',
    identity: TerrainSourceIdentity(
      chunkIndex: 0,
      chunkKey: 'test',
      shapeId: 'floor',
    ),
    vertices: [(0, 300), (700, 300), (700, 500), (0, 500)],
  ),
  TerrainPolygonInput.fromWorld(
    sourcePath: 'test/wall',
    identity: TerrainSourceIdentity(
      chunkIndex: 0,
      chunkKey: 'test',
      shapeId: 'wall',
    ),
    vertices: [(400, 100), (420, 100), (420, 300), (400, 300)],
  ),
], geometryVersion: 1);
