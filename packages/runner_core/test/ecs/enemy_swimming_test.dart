import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/combat/control_lock.dart';
import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/systems/enemy_engagement_system.dart';
import 'package:runner_core/ecs/systems/gravity_system.dart';
import 'package:runner_core/ecs/systems/ground_enemy_locomotion_system.dart';
import 'package:runner_core/ecs/systems/terrain_enemy_navigation_system.dart';
import 'package:runner_core/ecs/systems/water_immersion_system.dart';
import 'package:runner_core/ecs/systems/world_motion_authority.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/navigation/terrain_surface_navigator.dart';
import 'package:runner_core/navigation/terrain_surface_pathfinder.dart';
import 'package:runner_core/players/characters/eloise.dart';
import 'package:runner_core/players/player_catalog.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/terrain/swimming_tuning.dart';
import 'package:runner_core/terrain/water_region.dart';
import 'package:runner_core/tuning/ground_enemy_tuning.dart';
import 'package:runner_core/tuning/physics_tuning.dart';
import 'package:test/test.dart';

void main() {
  for (final enemyId in groundNavigatingEnemyIds) {
    for (final direction in [-1, 1]) {
      test('$enemyId enters, swims across and exits toward $direction', () {
        final harness = _Harness(enemyId, direction: direction);
        var swam = false;
        var stroked = false;
        for (var tick = 0; tick < 600; tick++) {
          harness.step();
          swam |= harness.swimming;
          stroked |=
              harness.world.swimState.nextStrokeTick[harness.world.swimState
                  .indexOf(harness.enemy)] >
              0;
          if (swam &&
              !harness.swimming &&
              (direction > 0 ? harness.x > 820 : harness.x < 180) &&
              harness.world.terrainContact.grounded[harness.world.terrainContact
                  .indexOf(harness.enemy)]) {
            break;
          }
        }
        expect(swam, isTrue);
        expect(stroked, isTrue);
        expect(
          direction > 0 ? harness.x > 810 : harness.x < 190,
          isTrue,
          reason: 'Stopped at ${harness.x}, ${harness.y}',
        );
        expect(harness.swimming, isFalse);
        expect(
          harness.world.terrainContact.grounded[harness.world.terrainContact
              .indexOf(harness.enemy)],
          isTrue,
          reason:
              'Final ${harness.x}, ${harness.y}, vx=${harness.vx}, vy=${harness.vy}',
        );
      });
    }

    test('$enemyId water speed composes with status and engagement', () {
      final h = _Harness(enemyId)..immerse();
      final engagement = h.world.engagementIntent.indexOf(h.enemy);
      h.world.engagementIntent.desiredTargetX[engagement] = 900;
      h.world.engagementIntent.speedScale[engagement] = 0.9;
      h.world.engagementIntent.stateSpeedMul[engagement] = 0.5;
      h.world.statModifier.moveSpeedMul[h.world.statModifier.indexOf(h.enemy)] =
          0.5;
      for (var tick = 1; tick <= 120; tick++) {
        h.locomotion.step(
          h.world,
          player: h.player,
          dtSeconds: 1 / 60,
          currentTick: tick,
        );
      }
      expect(h.vx, closeTo(300 * 0.8 * 0.9 * 0.5 * 0.5, 1e-9));
    });

    test('$enemyId locks prevent swimming propulsion but preserve sinking', () {
      for (final lock in [LockFlag.move, LockFlag.nav, LockFlag.stun]) {
        final h = _Harness(enemyId)..immerse();
        h.world.controlLock.addLock(h.enemy, lock, 60, 0);
        h.step();
        expect(h.vx, 0, reason: 'lock=$lock');
        expect(h.vy, greaterThan(0), reason: 'lock=$lock');
        expect(
          h.world.swimState.nextStrokeTick[h.world.swimState.indexOf(h.enemy)],
          0,
        );
      }
      final h = _Harness(enemyId)..immerse();
      h.world.controlLock.addLock(h.enemy, LockFlag.jump, 60, 0);
      h.step();
      expect(h.vx, greaterThan(0));
      expect(h.vy, greaterThan(0));
    });
  }

  test('submerged pursuit follows target depth without a dry landing prediction', () {
    final h = _Harness(EnemyId.grojib)..immerse();
    final pti = h.world.transform.indexOf(h.player);
    h.authority.beginBodyTeleport(h.world, h.player);
    h.world.transform.posX[pti] = 700;
    h.world.transform.posY[pti] =
        200 -
        h.world.worldContactCapsule.offsetYTicks[h.world.worldContactCapsule
                .indexOf(h.player)] /
            1024;
    h.world.terrainContact.clearSupport(h.player);
    h.world.body.useGravity[h.world.body.indexOf(h.player)] = false;
    for (var tick = 0; tick < 240; tick++) {
      h.step();
    }
    expect(h.navigation.lastPredictedPlayerLanding, isFalse);
    expect(
      h.swimming,
      isTrue,
      reason:
          'Enemy ${h.x}, ${h.y}; player ${h.world.transform.posX[pti]}, ${h.world.transform.posY[pti]}',
    );
    final capsule = h.world.worldContactCapsule;
    final center = h.y + capsule.offsetYTicks[capsule.indexOf(h.enemy)] / 1024;
    final targetCenter =
        h.world.transform.posY[pti] +
        capsule.offsetYTicks[capsule.indexOf(h.player)] / 1024;
    expect(center, closeTo(targetCenter, 10));
  });

  test('strokes respect cooldown and enemy buoyancy caps sinking', () {
    final h = _Harness(EnemyId.grojib)..immerse();
    h.step();
    final index = h.world.swimState.indexOf(h.enemy);
    expect(h.vy, lessThan(0));
    expect(h.world.swimState.nextStrokeTick[index], 13);
    h.world.transform.velY[h.world.transform.indexOf(h.enemy)] = 500;
    h.step();
    expect(h.vy, SwimmingTuning.maxSinkSpeed, reason: 'Enemy ${h.x}, ${h.y}');
    expect(h.world.swimState.nextStrokeTick[index], 13);
  });

  test('swimming cannot pass through a solid wall', () {
    final h = _Harness(EnemyId.grojib, withWall: true)..immerse();
    for (var tick = 0; tick < 300; tick++) {
      h.step();
      expect(h.x, lessThan(500));
    }
    expect(h.x, greaterThan(450));
  });

  test('only ground navigators receive swimming state', () {
    for (final enemyId in EnemyId.values) {
      final h = _Harness(enemyId);
      expect(
        h.world.swimState.has(h.enemy),
        groundNavigatingEnemyIds.contains(enemyId),
      );
    }
  });

  for (final fixed in [false, true]) {
    test(
      'swimming clears stale land jumps and repeats deterministically (fixed=$fixed)',
      () {
        final first = _Harness(EnemyId.hashash, fixed: fixed)..immerse();
        final second = _Harness(EnemyId.hashash, fixed: fixed)..immerse();
        final nav = first.world.surfaceNav.indexOf(first.enemy);
        first.world.surfaceNav.terrainState[nav].activeEdgeIndex = 999;
        final intent = first.world.navIntent.indexOf(first.enemy);
        first.world.navIntent.setActiveJumpTraversalAt(
          intent,
          takeoffX: 100,
          landingX: 900,
          commitDirectionX: -1,
          travelTicks: 20,
        );
        for (var tick = 0; tick < 300; tick++) {
          first.step();
          second.step();
          expect(
            (first.x, first.y, first.vx, first.vy, first.swimming),
            (second.x, second.y, second.vx, second.vy, second.swimming),
          );
        }
      },
    );
  }
}

final class _Harness {
  _Harness(
    EnemyId enemyId, {
    int direction = 1,
    bool withWall = false,
    this.fixed = false,
  }) {
    final playerArchetype = PlayerCatalogDerived.from(
      eloiseCharacter.catalog,
      movement: movement,
      resources: ResourceTuningDerived.from(eloiseCharacter.tuning.resource),
    ).archetype;
    final factory = EntityFactory(world);
    player = factory.createPlayer(
      posX: direction > 0 ? 940 : 60,
      posY:
          100 -
          playerArchetype.collider.offsetY -
          playerArchetype.collider.halfY,
      velX: 0,
      velY: 0,
      facing: Facing.right,
      grounded: false,
      body: playerArchetype.body,
      collider: playerArchetype.collider,
      health: playerArchetype.health,
      mana: playerArchetype.mana,
      stamina: playerArchetype.stamina,
    );
    final archetype = const EnemyCatalog().get(enemyId);
    enemy = factory.createEnemy(
      enemyId: enemyId,
      posX: direction > 0 ? 100 : 900,
      posY: 100 - archetype.collider.offsetY - archetype.collider.halfY,
      velX: 0,
      velY: 0,
      facing: Facing.right,
      artFacing: archetype.artFacingDir,
      body: archetype.body,
      collider: archetype.collider,
      health: archetype.health,
      mana: archetype.mana,
      stamina: archetype.stamina,
    );
    final geometry = const TerrainCompiler().compile([
      TerrainPolygonInput.fromWorld(
        sourcePath: 'test/pool',
        identity: TerrainSourceIdentity(
          chunkIndex: 0,
          chunkKey: 'pool',
          shapeId: 'basin',
        ),
        vertices: [
          (0, 100),
          (200, 100),
          (200, 340),
          (800, 340),
          (800, 100),
          (1000, 100),
          (1000, 380),
          (0, 380),
        ],
      ),
      if (withWall)
        TerrainPolygonInput.fromWorld(
          sourcePath: 'test/wall',
          identity: TerrainSourceIdentity(
            chunkIndex: 0,
            chunkKey: 'pool',
            shapeId: 'wall',
          ),
          vertices: [(500, -2000), (540, -2000), (540, 340), (500, 340)],
        ),
    ], geometryVersion: 1);
    authority = TerrainMultiBodyWorldMotionAuthority(
      geometry: geometry,
      playerProfile: playerArchetype.terrainTraversalProfile,
    );
    authority.initializePlayer(
      world,
      player: player,
      archetype: playerArchetype,
    );
    authority.prepareTick(world, player: player, currentTick: 0);
    gravity.step(world, movement, physics: const PhysicsTuning());
    authority.step(
      world,
      player: player,
      movement: movement,
      fixedPointPilotEnabled: false,
      fixedPointSubpixelScale: terrainPhysicsTicksPerWorldUnit,
      currentTick: 0,
    );
    navigation = TerrainEnemyNavigationSystem(
      runtimeBundle: () => authority.terrainRuntimeBundle,
      navigator: TerrainSurfaceNavigator(
        pathfinder: TerrainSurfacePathfinder(maxExpandedNodes: 128),
      ),
      physics: const PhysicsTuning(),
      dtSeconds: 1 / 60,
    );
  }

  final world = EcsWorld(seed: 17);
  final bool fixed;
  late final int player;
  late final int enemy;
  late final TerrainMultiBodyWorldMotionAuthority authority;
  late final TerrainEnemyNavigationSystem navigation;
  final movement = MovementTuningDerived.from(
    const MovementTuning(),
    tickHz: 60,
  );
  final locomotion = GroundEnemyLocomotionSystem(groundEnemyTuning: _tuning);
  final engagement = EnemyEngagementSystem(groundEnemyTuning: _tuning);
  final water = WaterImmersionSystem();
  final gravity = GravitySystem();
  final pools = [
    WaterRegion(
      sourceId: TerrainSourceIdentity(
        chunkIndex: 0,
        chunkKey: 'pool',
        shapeId: 'water',
      ),
      worldOriginXTicks: 0,
      data: WaterRegionData(
        id: 'water',
        x: 200,
        y: 100,
        width: 600,
        height: 240,
        materialKey: 'water',
      ),
    ),
  ];
  int tick = 0;
  double get x => world.transform.posX[world.transform.indexOf(enemy)];
  double get y => world.transform.posY[world.transform.indexOf(enemy)];
  double get vx => world.transform.velX[world.transform.indexOf(enemy)];
  double get vy => world.transform.velY[world.transform.indexOf(enemy)];
  bool get swimming => world.swimState.isSwimming(enemy);

  void immerse() {
    authority.beginBodyTeleport(world, enemy);
    world.transform.setPosXY(
      enemy,
      400,
      220 -
          world.worldContactCapsule.offsetYTicks[world.worldContactCapsule
                  .indexOf(enemy)] /
              1024,
    );
    world.terrainContact.clearSupport(enemy);
    water.step(world, pools);
    expect(swimming, isTrue);
  }

  void step() {
    tick++;
    authority.prepareTick(world, player: player, currentTick: tick);
    water.step(world, pools);
    navigation.step(
      world,
      player: player,
      currentTick: tick,
      waterRegions: pools,
    );
    engagement.step(world, player: player, currentTick: tick);
    locomotion.step(
      world,
      player: player,
      dtSeconds: 1 / 60,
      currentTick: tick,
    );
    gravity.step(
      world,
      movement,
      physics: PhysicsTuning(
        fixedPointPilot: FixedPointPilotTuning(enabled: fixed),
      ),
    );
    authority.step(
      world,
      player: player,
      movement: movement,
      fixedPointPilotEnabled: fixed,
      fixedPointSubpixelScale: terrainPhysicsTicksPerWorldUnit,
      currentTick: tick,
    );
    water.step(world, pools);
  }
}

final _tuning = GroundEnemyTuningDerived.from(
  const GroundEnemyTuning(),
  tickHz: 60,
);
