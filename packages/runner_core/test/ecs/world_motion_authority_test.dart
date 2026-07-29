import 'package:runner_core/collision/static_world_geometry_index.dart';
import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/combat/control_lock.dart';
import 'package:runner_core/combat/damage_type.dart';
import 'package:runner_core/combat/faction.dart';
import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/stores/body_store.dart';
import 'package:runner_core/ecs/stores/enemies/enemy_store.dart';
import 'package:runner_core/ecs/stores/death_state_store.dart';
import 'package:runner_core/ecs/stores/projectile_store.dart';
import 'package:runner_core/ecs/systems/gravity_system.dart';
import 'package:runner_core/ecs/systems/player_movement_system.dart';
import 'package:runner_core/ecs/systems/world_motion_authority.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/enemies/death_behavior.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/players/characters/eloise.dart';
import 'package:runner_core/players/player_catalog.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/tuning/physics_tuning.dart';
import 'package:test/test.dart';

void main() {
  group('world motion authority', () {
    test('terrain authority rejects an unknown enabled dynamic body', () {
      final harness = _terrainHarness();
      final unsupported = harness.world.createEntity();
      harness.world.body.add(unsupported, const BodyDef());

      expect(
        () => harness.authority.prepareTick(
          harness.world,
          player: harness.player,
          currentTick: 1,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('no legacy collision fallback is permitted'),
          ),
        ),
      );
    });

    test('disabled and kinematic non-player bodies are explicitly ignored', () {
      final harness = _terrainHarness();
      final disabled = harness.world.createEntity();
      harness.world.body.add(disabled, const BodyDef(enabled: false));
      final kinematic = harness.world.createEntity();
      harness.world.body.add(kinematic, const BodyDef(isKinematic: true));

      expect(
        () => harness.authority.prepareTick(
          harness.world,
          player: harness.player,
          currentTick: 1,
        ),
        returnsNormally,
      );
    });

    test('prepared motion cannot be skipped or integrated twice', () {
      final skipped = _terrainHarness();
      skipped.authority.prepareTick(
        skipped.world,
        player: skipped.player,
        currentTick: 1,
      );
      expect(
        () => skipped.authority.prepareTick(
          skipped.world,
          player: skipped.player,
          currentTick: 2,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('did not integrate'),
          ),
        ),
      );

      final doubled = _terrainHarness();
      doubled.authority.prepareTick(
        doubled.world,
        player: doubled.player,
        currentTick: 1,
      );
      doubled.authority.step(
        doubled.world,
        player: doubled.player,
        movement: doubled.movement,
        legacyStaticWorld: _legacyWorld,
        fixedPointPilotEnabled: false,
        fixedPointSubpixelScale: 1024,
        currentTick: 1,
      );
      expect(
        () => doubled.authority.step(
          doubled.world,
          player: doubled.player,
          movement: doubled.movement,
          legacyStaticWorld: _legacyWorld,
          fixedPointPilotEnabled: false,
          fixedPointSubpixelScale: 1024,
          currentTick: 1,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('twice'),
          ),
        ),
      );
    });

    test('zero, one, and many enemies are initialized and integrated once', () {
      for (final enemyIds in <List<EnemyId>>[
        const <EnemyId>[],
        const <EnemyId>[EnemyId.grojib],
        const <EnemyId>[
          EnemyId.grojib,
          EnemyId.hashash,
          EnemyId.unocoDemon,
          EnemyId.derf,
        ],
      ]) {
        final harness = _terrainHarness();
        final enemies = <int>[];
        for (var index = 0; index < enemyIds.length; index += 1) {
          final id = enemyIds[index];
          enemies.add(
            _spawnEnemy(
              harness.world,
              id,
              x: 140 + index * 35,
              velocityX: id == EnemyId.derf ? 0 : 60,
            ),
          );
        }
        final playerTransform = harness.world.transform.indexOf(harness.player);
        harness.world.transform.velX[playerTransform] = 60;

        harness.authority.prepareTick(
          harness.world,
          player: harness.player,
          currentTick: 1,
        );
        final distance = _stepAuthority(harness, currentTick: 1);

        final dynamicEnemyCount = enemyIds
            .where((id) => id != EnemyId.derf)
            .length;
        expect(
          harness.authority.lastIntegratedBodyCount,
          1 + dynamicEnemyCount,
          reason: '$enemyIds',
        );
        expect(distance, closeTo(1, 1 / terrainPhysicsTicksPerWorldUnit));
        expect(
          harness.world.transform.posX[playerTransform],
          closeTo(101, 1 / terrainPhysicsTicksPerWorldUnit),
        );

        for (var index = 0; index < enemies.length; index += 1) {
          final enemy = enemies[index];
          final id = enemyIds[index];
          expect(harness.world.worldContactCapsule.has(enemy), isTrue);
          expect(harness.world.terrainTraversalProfile.has(enemy), isTrue);
          if (id == EnemyId.derf) {
            expect(harness.world.terrainContact.has(enemy), isFalse);
            expect(harness.world.resolvedMotion.has(enemy), isFalse);
            expect(
              harness.world.transform.posX[harness.world.transform.indexOf(
                enemy,
              )],
              140 + index * 35,
            );
          } else {
            expect(harness.world.terrainContact.has(enemy), isTrue);
            expect(harness.world.resolvedMotion.has(enemy), isTrue);
            expect(
              harness.world.resolvedMotion.resolvedXTicks[harness
                  .world
                  .resolvedMotion
                  .indexOf(enemy)],
              physicsCoordinateToTicks(1, name: 'expectedEnemyTravel'),
            );
          }
        }
      }
    });

    test('canonical entity order is independent of sparse-set order', () {
      ({
        ({double x, double y, int rx, int ry}) grojib,
        ({double x, double y, int rx, int ry}) hashash,
        double playerDistance,
      })
      run({required bool perturbBodyOrder}) {
        final harness = _terrainHarness();
        final grojib = _spawnEnemy(
          harness.world,
          EnemyId.grojib,
          x: 140,
          velocityX: 60,
        );
        final hashash = _spawnEnemy(
          harness.world,
          EnemyId.hashash,
          x: 210,
          velocityX: -60,
        );
        if (perturbBodyOrder) {
          final catalog = const EnemyCatalog();
          harness.world.body.removeEntity(grojib);
          harness.world.body.add(grojib, catalog.get(EnemyId.grojib).body);
        }
        harness.authority.prepareTick(
          harness.world,
          player: harness.player,
          currentTick: 1,
        );
        final distance = _stepAuthority(harness, currentTick: 1);

        ({double x, double y, int rx, int ry}) state(int entity) {
          final transformIndex = harness.world.transform.indexOf(entity);
          final resolvedIndex = harness.world.resolvedMotion.indexOf(entity);
          return (
            x: harness.world.transform.posX[transformIndex],
            y: harness.world.transform.posY[transformIndex],
            rx: harness.world.resolvedMotion.resolvedXTicks[resolvedIndex],
            ry: harness.world.resolvedMotion.resolvedYTicks[resolvedIndex],
          );
        }

        return (
          grojib: state(grojib),
          hashash: state(hashash),
          playerDistance: distance,
        );
      }

      expect(run(perturbBodyOrder: true), run(perturbBodyOrder: false));
    });

    test('missing terrain store fails before any body is integrated', () {
      final harness = _terrainHarness();
      final grojib = _spawnEnemy(
        harness.world,
        EnemyId.grojib,
        x: 150,
        velocityX: 60,
      );
      harness.authority.prepareTick(
        harness.world,
        player: harness.player,
        currentTick: 1,
      );
      harness.world.resolvedMotion.removeEntity(grojib);
      final playerTransform = harness.world.transform.indexOf(harness.player);
      harness.world.transform.velX[playerTransform] = 60;
      final playerStartX = harness.world.transform.posX[playerTransform];
      final enemyStartX =
          harness.world.transform.posX[harness.world.transform.indexOf(grojib)];

      expect(
        () => _stepAuthority(harness, currentTick: 1),
        throwsA(isA<TerrainBodyStoreError>()),
      );
      expect(harness.world.transform.posX[playerTransform], playerStartX);
      expect(
        harness.world.transform.posX[harness.world.transform.indexOf(grojib)],
        enemyStartX,
      );
      expect(harness.authority.lastIntegratedBodyCount, 0);
    });

    test(
      'atomic geometry replacement invalidates support and every path key',
      () {
        final harness = _terrainHarness();
        final grojib = _spawnEnemy(
          harness.world,
          EnemyId.grojib,
          x: 150,
          velocityY: 60,
        );
        final hashash = _spawnEnemy(
          harness.world,
          EnemyId.hashash,
          x: 210,
          velocityY: 60,
        );
        harness.authority.prepareTick(
          harness.world,
          player: harness.player,
          currentTick: 1,
        );
        _stepAuthority(harness, currentTick: 1);
        for (final enemy in <int>[grojib, hashash]) {
          final contactIndex = harness.world.terrainContact.indexOf(enemy);
          expect(harness.world.terrainContact.grounded[contactIndex], isTrue);
          final navIndex = harness.world.surfaceNav.indexOf(enemy);
          harness.world.surfaceNav.graphVersion[navIndex] = 1;
          harness.world.surfaceNav.currentSurfaceId[navIndex] = 4;
          harness.world.surfaceNav.lastGroundSurfaceId[navIndex] = 5;
          harness.world.surfaceNav.targetSurfaceId[navIndex] = 6;
          harness.world.surfaceNav.activeEdgeIndex[navIndex] = 7;
          harness.world.surfaceNav.pathCursor[navIndex] = 1;
          harness.world.surfaceNav.pathEdges[navIndex].addAll(<int>[7, 8]);
        }

        final oldSurfaceSignature = harness.authority.terrainRuntimeBundle
            .surfaceSignature();
        final oldGraphSignature = harness.authority.terrainRuntimeBundle
            .graphSignature();
        harness.authority.queueTerrainGeometryReplacement(
          _terrainGeometry(version: 2),
        );
        expect(harness.authority.terrainGeometryVersion, 1);
        expect(harness.authority.terrainRuntimeBundle.version, 1);

        harness.authority.prepareTick(
          harness.world,
          player: harness.player,
          currentTick: 2,
        );

        final published = harness.authority.terrainRuntimeBundle;
        expect(published.version, 2);
        expect(published.surfaceIndex.geometryVersion, 2);
        expect(published.graphPublication.geometryVersion, 2);
        expect(
          identical(published.surfaceIndex.surfaceSet, published.surfaceSet),
          isTrue,
        );
        expect(
          identical(
            published.graphPublication.surfaceSet,
            published.surfaceSet,
          ),
          isTrue,
        );
        expect(published.surfaceSignature(), oldSurfaceSignature);
        expect(published.graphSignature(), oldGraphSignature);

        for (final entity in <int>[harness.player, grojib, hashash]) {
          final contactIndex = harness.world.terrainContact.indexOf(entity);
          expect(harness.world.terrainContact.grounded[contactIndex], isFalse);
          expect(
            harness.world.terrainContact.supportEdgeId[contactIndex],
            isNull,
          );
        }
        for (final enemy in <int>[grojib, hashash]) {
          final navIndex = harness.world.surfaceNav.indexOf(enemy);
          expect(harness.world.surfaceNav.graphVersion[navIndex], -1);
          expect(harness.world.surfaceNav.currentSurfaceId[navIndex], -1);
          expect(harness.world.surfaceNav.lastGroundSurfaceId[navIndex], -1);
          expect(harness.world.surfaceNav.targetSurfaceId[navIndex], -1);
          expect(harness.world.surfaceNav.activeEdgeIndex[navIndex], -1);
          expect(harness.world.surfaceNav.pathCursor[navIndex], 0);
          expect(harness.world.surfaceNav.pathEdges[navIndex], isEmpty);
        }
      },
    );

    test('airborne active-edge state is culled before replacement AI', () {
      final harness = _terrainHarness();
      final hashash = _spawnEnemy(
        harness.world,
        EnemyId.hashash,
        x: 210,
        bodyY: 20,
        velocityX: 80,
        velocityY: -120,
      );
      harness.authority.prepareTick(
        harness.world,
        player: harness.player,
        currentTick: 1,
      );
      _stepAuthority(harness, currentTick: 1);
      final contactIndex = harness.world.terrainContact.indexOf(hashash);
      expect(harness.world.terrainContact.grounded[contactIndex], isFalse);
      final navIndex = harness.world.surfaceNav.indexOf(hashash);
      harness.world.surfaceNav.graphVersion[navIndex] = 1;
      harness.world.surfaceNav.currentSurfaceId[navIndex] = 4;
      harness.world.surfaceNav.lastGroundSurfaceId[navIndex] = 5;
      harness.world.surfaceNav.targetSurfaceId[navIndex] = 6;
      harness.world.surfaceNav.activeEdgeIndex[navIndex] = 7;
      harness.world.surfaceNav.pathCursor[navIndex] = 1;
      harness.world.surfaceNav.pathEdges[navIndex].addAll(<int>[7, 8]);

      harness.authority.queueTerrainGeometryReplacement(
        _terrainGeometry(version: 2),
      );
      harness.authority.prepareTick(
        harness.world,
        player: harness.player,
        currentTick: 2,
      );

      expect(harness.world.surfaceNav.graphVersion[navIndex], -1);
      expect(harness.world.surfaceNav.currentSurfaceId[navIndex], -1);
      expect(harness.world.surfaceNav.lastGroundSurfaceId[navIndex], -1);
      expect(harness.world.surfaceNav.targetSurfaceId[navIndex], -1);
      expect(harness.world.surfaceNav.activeEdgeIndex[navIndex], -1);
      expect(harness.world.surfaceNav.pathCursor[navIndex], 0);
      expect(harness.world.surfaceNav.pathEdges[navIndex], isEmpty);
    });

    test(
      'replacement cannot publish mid-tick and motion rejects stale support',
      () {
        final harness = _terrainHarness();
        harness.authority.prepareTick(
          harness.world,
          player: harness.player,
          currentTick: 1,
        );
        expect(
          () => harness.authority.queueTerrainGeometryReplacement(
            _terrainGeometry(version: 2),
          ),
          throwsStateError,
        );
        _stepAuthority(harness, currentTick: 1);

        harness.authority.queueTerrainGeometryReplacement(
          _terrainGeometry(version: 2),
        );
        harness.authority.prepareTick(
          harness.world,
          player: harness.player,
          currentTick: 2,
        );
        final contactIndex = harness.world.terrainContact.indexOf(
          harness.player,
        );
        harness.world.terrainContact.supportGeometryVersion[contactIndex] = 1;

        expect(
          () => _stepAuthority(harness, currentTick: 2),
          throwsA(
            isA<TerrainStaleRuntimeStateError>()
                .having((error) => error.supportVersion, 'supportVersion', 1)
                .having((error) => error.bundleVersion, 'bundleVersion', 2),
          ),
        );
      },
    );

    test('disabled, kinematic, dying, and falling bodies follow policy', () {
      final harness = _terrainHarness();
      final disabled = _spawnEnemy(
        harness.world,
        EnemyId.grojib,
        x: 130,
        velocityX: 60,
      );
      harness.world.body.enabled[harness.world.body.indexOf(disabled)] = false;
      final kinematic = _spawnEnemy(
        harness.world,
        EnemyId.hashash,
        x: 170,
        velocityX: 60,
      );
      harness.world.body.isKinematic[harness.world.body.indexOf(kinematic)] =
          true;
      final dying = _spawnEnemy(harness.world, EnemyId.grojib, x: 210);
      harness.world.deathState.add(
        dying,
        const DeathStateDef(phase: DeathPhase.deathAnim),
      );
      final falling = _spawnEnemy(
        harness.world,
        EnemyId.hashash,
        x: 250,
        bodyY: 40,
        velocityY: 120,
      );
      harness.world.deathState.add(
        falling,
        const DeathStateDef(phase: DeathPhase.fallingUntilGround),
      );
      final derf = _spawnEnemy(harness.world, EnemyId.derf, x: 280);
      final startFallingY = harness
          .world
          .transform
          .posY[harness.world.transform.indexOf(falling)];

      harness.authority.prepareTick(
        harness.world,
        player: harness.player,
        currentTick: 1,
      );
      _stepAuthority(harness, currentTick: 1);

      expect(harness.authority.lastIntegratedBodyCount, 3);
      for (final entity in <int>[disabled, kinematic]) {
        final resolvedIndex = harness.world.resolvedMotion.indexOf(entity);
        expect(harness.world.resolvedMotion.resolvedXTicks[resolvedIndex], 0);
        expect(
          harness.world.terrainContact.grounded[harness.world.terrainContact
              .indexOf(entity)],
          isFalse,
        );
      }
      expect(
        harness.world.transform.posY[harness.world.transform.indexOf(falling)],
        greaterThan(startFallingY),
      );
      expect(harness.world.terrainContact.has(dying), isTrue);
      expect(harness.world.worldContactCapsule.has(derf), isTrue);
      expect(harness.world.terrainContact.has(derf), isFalse);
    });

    test('inactive enemies cannot change player motion or distance', () {
      ({double x, double y, int rx, int ry, bool grounded, double distance})
      run(bool withInactiveEnemies) {
        final harness = _terrainHarness(sloped: true);
        if (withInactiveEnemies) {
          final disabled = _spawnEnemy(harness.world, EnemyId.grojib, x: 180);
          harness.world.body.enabled[harness.world.body.indexOf(disabled)] =
              false;
          _spawnEnemy(harness.world, EnemyId.derf, x: 220);
        }
        final transformIndex = harness.world.transform.indexOf(harness.player);
        harness.world.transform.velX[transformIndex] = 90;
        harness.authority.prepareTick(
          harness.world,
          player: harness.player,
          currentTick: 1,
        );
        final distance = _stepAuthority(harness, currentTick: 1);
        final resolvedIndex = harness.world.resolvedMotion.indexOf(
          harness.player,
        );
        return (
          x: harness.world.transform.posX[transformIndex],
          y: harness.world.transform.posY[transformIndex],
          rx: harness.world.resolvedMotion.resolvedXTicks[resolvedIndex],
          ry: harness.world.resolvedMotion.resolvedYTicks[resolvedIndex],
          grounded: harness.authority.playerGrounded(
            harness.world,
            harness.player,
          ),
          distance: distance,
        );
      }

      expect(run(true), run(false));
    });

    test('flying profile blocks on solids without publishing support', () {
      final harness = _terrainHarness();
      final unoco = _spawnEnemy(
        harness.world,
        EnemyId.unocoDemon,
        x: 170,
        bodyY: 40,
        velocityY: 6000,
      );
      harness.authority.prepareTick(
        harness.world,
        player: harness.player,
        currentTick: 1,
      );
      _stepAuthority(harness, currentTick: 1);

      final transformIndex = harness.world.transform.indexOf(unoco);
      final contactIndex = harness.world.terrainContact.indexOf(unoco);
      final collisionIndex = harness.world.collision.indexOf(unoco);
      expect(harness.world.transform.posY[transformIndex], lessThan(90));
      expect(harness.world.terrainContact.grounded[contactIndex], isFalse);
      expect(harness.world.terrainContact.supportEdgeId[contactIndex], isNull);
      expect(harness.world.collision.grounded[collisionIndex], isFalse);
    });

    test('enabled ballistic projectiles remain an explicit hard failure', () {
      final harness = _terrainHarness();
      final projectile = harness.world.createEntity();
      harness.world.body.add(projectile, const BodyDef());
      harness.world.projectile.add(
        projectile,
        const ProjectileEntityDef(
          projectileId: ProjectileId.unknown,
          faction: Faction.player,
          owner: 1,
          dirX: 1,
          dirY: 0,
          speedUnitsPerSecond: 10,
          damage100: 100,
          damageType: DamageType.physical,
          usePhysics: true,
        ),
      );

      expect(
        () => harness.authority.prepareTick(
          harness.world,
          player: harness.player,
          currentTick: 1,
        ),
        throwsA(
          isA<TerrainUnsupportedBodyError>().having(
            (error) => error.disposition,
            'disposition',
            TerrainBodyDisposition.ballisticProjectileUnsupported,
          ),
        ),
      );
    });

    test('later-phase body policies have explicit typed dispositions', () {
      final world = EcsWorld();
      final player = world.createEntity();
      world.body.add(player, const BodyDef());
      expect(
        terrainBodyDisposition(world, entity: player, terrainPlayer: player),
        TerrainBodyDisposition.terrainPlayer,
        reason:
            'Player identity selects its policy; store completeness is '
            'validated separately before preparation.',
      );

      int enemy(EnemyId id, {bool kinematic = false}) {
        final entity = world.createEntity();
        world.body.add(entity, BodyDef(isKinematic: kinematic));
        world.enemy.add(entity, EnemyDef(enemyId: id));
        return entity;
      }

      final grojib = enemy(EnemyId.grojib);
      final unoco = enemy(EnemyId.unocoDemon);
      final derf = enemy(EnemyId.derf, kinematic: true);
      final hashash = enemy(EnemyId.hashash);
      final projectile = world.createEntity();
      world.body.add(projectile, const BodyDef());
      world.projectile.add(
        projectile,
        const ProjectileEntityDef(
          projectileId: ProjectileId.unknown,
          faction: Faction.player,
          owner: 1,
          dirX: 1,
          dirY: 0,
          speedUnitsPerSecond: 10,
          damage100: 100,
          damageType: DamageType.physical,
          usePhysics: true,
        ),
      );

      expect(
        terrainBodyDisposition(world, entity: grojib, terrainPlayer: player),
        TerrainBodyDisposition.terrainGroundedEnemy,
      );
      expect(
        terrainBodyDisposition(world, entity: unoco, terrainPlayer: player),
        TerrainBodyDisposition.terrainFlyingEnemy,
      );
      expect(
        terrainBodyDisposition(world, entity: derf, terrainPlayer: player),
        TerrainBodyDisposition.kinematicPlacementEnemy,
      );
      expect(
        terrainBodyDisposition(world, entity: hashash, terrainPlayer: player),
        TerrainBodyDisposition.terrainGroundedEnemy,
      );
      expect(
        terrainBodyDisposition(
          world,
          entity: projectile,
          terrainPlayer: player,
        ),
        TerrainBodyDisposition.ballisticProjectileUnsupported,
      );
    });

    test('disable, kinematic ownership, and motion-stop clear support', () {
      for (final kinematic in <bool>[false, true]) {
        final harness = _terrainHarness();
        final bodyIndex = harness.world.body.indexOf(harness.player);
        if (kinematic) {
          harness.world.body.isKinematic[bodyIndex] = true;
        } else {
          harness.world.body.enabled[bodyIndex] = false;
        }

        harness.authority.prepareTick(
          harness.world,
          player: harness.player,
          currentTick: 1,
        );
        expect(
          harness.world.terrainContact.grounded[harness.world.terrainContact
              .indexOf(harness.player)],
          isFalse,
        );
        expect(
          harness.authority.step(
            harness.world,
            player: harness.player,
            movement: harness.movement,
            legacyStaticWorld: _legacyWorld,
            fixedPointPilotEnabled: false,
            fixedPointSubpixelScale: 1024,
            currentTick: 1,
          ),
          0,
        );
      }

      final stopped = _terrainHarness();
      stopped.authority.beforeBodyMotionStops(stopped.world, stopped.player);
      expect(
        stopped.world.terrainContact.grounded[stopped.world.terrainContact
            .indexOf(stopped.player)],
        isFalse,
      );
      expect(
        stopped.world.collision.grounded[stopped.world.collision.indexOf(
          stopped.player,
        )],
        isFalse,
      );
    });

    test(
      'move-locked and stunned slope support consumes gravity without drift',
      () {
        for (final lock in <int>[LockFlag.move, LockFlag.stun]) {
          final harness = _terrainHarness(sloped: true);
          final transformIndex = harness.world.transform.indexOf(
            harness.player,
          );
          final inputIndex = harness.world.playerInput.indexOf(harness.player);
          final startX = harness.world.transform.posX[transformIndex];
          final startY = harness.world.transform.posY[transformIndex];
          harness.world.playerInput.moveAxis[inputIndex] = 1;
          harness.world.controlLock.addLock(harness.player, lock, 10, 0);

          harness.authority.prepareTick(
            harness.world,
            player: harness.player,
            currentTick: 1,
          );
          PlayerMovementSystem().step(
            harness.world,
            harness.movement,
            currentTick: 1,
          );
          GravitySystem().step(
            harness.world,
            harness.movement,
            physics: const PhysicsTuning(),
          );
          harness.authority.step(
            harness.world,
            player: harness.player,
            movement: harness.movement,
            legacyStaticWorld: _legacyWorld,
            fixedPointPilotEnabled: false,
            fixedPointSubpixelScale: 1024,
            currentTick: 1,
          );

          expect(
            harness.world.transform.posX[transformIndex],
            closeTo(startX, 1 / 1024),
            reason: 'lock=$lock',
          );
          expect(
            harness.world.transform.posY[transformIndex],
            closeTo(startY, 1 / 1024),
            reason: 'lock=$lock',
          );
          expect(
            harness.authority.playerGrounded(harness.world, harness.player),
            isTrue,
          );
        }
      },
    );
  });
}

({
  EcsWorld world,
  int player,
  MovementTuningDerived movement,
  TerrainMultiBodyWorldMotionAuthority authority,
})
_terrainHarness({bool sloped = false}) {
  final world = EcsWorld(seed: 1);
  final movement = MovementTuningDerived.from(
    eloiseCharacter.tuning.movement,
    tickHz: 60,
  );
  final archetype = PlayerCatalogDerived.from(
    eloiseCharacter.catalog,
    movement: movement,
    resources: ResourceTuningDerived.from(eloiseCharacter.tuning.resource),
  ).archetype;
  final player = EntityFactory(world).createPlayer(
    posX: 100,
    posY: 0,
    velX: 0,
    velY: 0,
    facing: archetype.facing,
    grounded: false,
    body: archetype.body,
    collider: archetype.collider,
    health: archetype.health,
    mana: archetype.mana,
    stamina: archetype.stamina,
  );
  final geometry = _terrainGeometry(sloped: sloped);
  final authority = TerrainMultiBodyWorldMotionAuthority(
    geometry: geometry,
    playerProfile: archetype.terrainTraversalProfile,
  );
  authority.initializePlayer(world, player: player, archetype: archetype);
  return (
    world: world,
    player: player,
    movement: movement,
    authority: authority,
  );
}

double _stepAuthority(
  ({
    EcsWorld world,
    int player,
    MovementTuningDerived movement,
    TerrainMultiBodyWorldMotionAuthority authority,
  })
  harness, {
  required int currentTick,
}) => harness.authority.step(
  harness.world,
  player: harness.player,
  movement: harness.movement,
  legacyStaticWorld: _legacyWorld,
  fixedPointPilotEnabled: false,
  fixedPointSubpixelScale: 1024,
  currentTick: currentTick,
);

int _spawnEnemy(
  EcsWorld world,
  EnemyId id, {
  required double x,
  double? bodyY,
  double velocityX = 0,
  double velocityY = 0,
}) {
  final archetype = const EnemyCatalog().get(id);
  final entity = world.createEntity();
  final resolvedBodyY =
      bodyY ??
      (id == EnemyId.unocoDemon
          ? 50
          : 100 - archetype.collider.offsetY - archetype.collider.halfY);
  world.transform.add(
    entity,
    posX: x,
    posY: resolvedBodyY,
    velX: velocityX,
    velY: velocityY,
  );
  world.body.add(entity, archetype.body);
  world.colliderAabb.add(entity, archetype.collider);
  world.collision.add(entity);
  world.enemy.add(entity, EnemyDef(enemyId: id));
  if (id == EnemyId.grojib || id == EnemyId.hashash) {
    world.surfaceNav.add(entity);
  }
  return entity;
}

TerrainGeometry _terrainGeometry({bool sloped = false, int version = 1}) =>
    const TerrainCompiler().compile(
      sloped
          ? <TerrainPolygonInput>[
              TerrainPolygonInput.fromWorld(
                sourcePath: 'test/slope',
                identity: TerrainSourceIdentity(
                  chunkIndex: 0,
                  chunkKey: 'test',
                  shapeId: 'slope',
                ),
                vertices: <(double, double)>[
                  (0, 300),
                  (112, 106),
                  (250, 400),
                  (0, 400),
                ],
              ),
            ]
          : <TerrainPolygonInput>[
              TerrainPolygonInput.fromWorld(
                sourcePath: 'test/floor',
                identity: TerrainSourceIdentity(
                  chunkIndex: 0,
                  chunkKey: 'test',
                  shapeId: 'floor',
                ),
                vertices: <(double, double)>[
                  (0, 100),
                  (300, 100),
                  (300, 140),
                  (0, 140),
                ],
              ),
            ],
      geometryVersion: version,
    );

final StaticWorldGeometryIndex _legacyWorld = StaticWorldGeometryIndex.from(
  const StaticWorldGeometry(groundPlane: StaticGroundPlane(topY: 100)),
);
