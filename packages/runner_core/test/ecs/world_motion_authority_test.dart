import 'package:runner_core/collision/static_world_geometry_index.dart';
import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/combat/control_lock.dart';
import 'package:runner_core/combat/damage_type.dart';
import 'package:runner_core/combat/faction.dart';
import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/stores/body_store.dart';
import 'package:runner_core/ecs/stores/enemies/enemy_store.dart';
import 'package:runner_core/ecs/stores/projectile_store.dart';
import 'package:runner_core/ecs/systems/gravity_system.dart';
import 'package:runner_core/ecs/systems/player_movement_system.dart';
import 'package:runner_core/ecs/systems/world_motion_authority.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/players/characters/eloise.dart';
import 'package:runner_core/players/player_catalog.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/tuning/physics_tuning.dart';
import 'package:test/test.dart';

void main() {
  group('world motion authority', () {
    test('terrain authority rejects every enabled dynamic non-player body', () {
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
            contains('requires its later-phase migration'),
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

    test('later-phase body policies have explicit typed dispositions', () {
      final world = EcsWorld();
      final player = world.createEntity();
      world.body.add(player, const BodyDef());
      expect(
        terrainPhase2BodyDisposition(
          world,
          entity: player,
          terrainPlayer: player,
        ),
        TerrainPhase2BodyDisposition.unsupportedDynamicBody,
        reason:
            'Player identity alone must not grant terrain integration; '
            'the complete authoritative capsule state routes the body.',
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
        terrainPhase2BodyDisposition(
          world,
          entity: grojib,
          terrainPlayer: player,
        ),
        TerrainPhase2BodyDisposition.groundedEnemyAwaitingProfile,
      );
      expect(
        terrainPhase2BodyDisposition(
          world,
          entity: unoco,
          terrainPlayer: player,
        ),
        TerrainPhase2BodyDisposition.flyingEnemyAwaitingContact,
      );
      expect(
        terrainPhase2BodyDisposition(
          world,
          entity: derf,
          terrainPlayer: player,
        ),
        TerrainPhase2BodyDisposition.derfKinematicClearanceDeferred,
      );
      expect(
        terrainPhase2BodyDisposition(
          world,
          entity: hashash,
          terrainPlayer: player,
        ),
        TerrainPhase2BodyDisposition.hashashTeleportClearanceDeferred,
      );
      expect(
        terrainPhase2BodyDisposition(
          world,
          entity: projectile,
          terrainPlayer: player,
        ),
        TerrainPhase2BodyDisposition.ballisticProjectileAwaitingSweptCircle,
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
      stopped.authority.beforePlayerMotionStops(stopped.world, stopped.player);
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
  TerrainPlayerWorldMotionAuthority authority,
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
  final geometry = const TerrainCompiler().compile(
    sloped
        ? [
            TerrainPolygonInput.fromWorld(
              sourcePath: 'test/slope',
              identity: TerrainSourceIdentity(
                chunkIndex: 0,
                chunkKey: 'test',
                shapeId: 'slope',
              ),
              vertices: [(0, 300), (112, 106), (250, 400), (0, 400)],
            ),
          ]
        : [
            TerrainPolygonInput.fromWorld(
              sourcePath: 'test/floor',
              identity: TerrainSourceIdentity(
                chunkIndex: 0,
                chunkKey: 'test',
                shapeId: 'floor',
              ),
              vertices: [(0, 100), (300, 100), (300, 140), (0, 140)],
            ),
          ],
    geometryVersion: 1,
  );
  final authority = TerrainPlayerWorldMotionAuthority(
    geometry: geometry,
    profile: archetype.terrainTraversalProfile,
  );
  authority.initializePlayer(world, player: player, archetype: archetype);
  return (
    world: world,
    player: player,
    movement: movement,
    authority: authority,
  );
}

final StaticWorldGeometryIndex _legacyWorld = StaticWorldGeometryIndex.from(
  const StaticWorldGeometry(groundPlane: StaticGroundPlane(topY: 100)),
);
