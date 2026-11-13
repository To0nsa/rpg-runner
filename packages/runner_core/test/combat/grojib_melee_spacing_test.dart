import 'package:runner_core/abilities/ability_catalog.dart';
import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/spatial/broadphase_grid.dart';
import 'package:runner_core/ecs/spatial/grid_index_2d.dart';
import 'package:runner_core/ecs/systems/active_ability_phase_system.dart';
import 'package:runner_core/ecs/systems/anim/anim_system.dart';
import 'package:runner_core/ecs/systems/combat_hurtbox_system.dart';
import 'package:runner_core/ecs/systems/enemy_engagement_system.dart';
import 'package:runner_core/ecs/systems/enemy_melee_system.dart';
import 'package:runner_core/ecs/systems/gravity_system.dart';
import 'package:runner_core/ecs/systems/ground_enemy_locomotion_system.dart';
import 'package:runner_core/ecs/systems/hitbox_damage_system.dart';
import 'package:runner_core/ecs/systems/hitbox_follow_owner_system.dart';
import 'package:runner_core/ecs/systems/melee_strike_system.dart';
import 'package:runner_core/ecs/systems/terrain_enemy_navigation_system.dart';
import 'package:runner_core/ecs/systems/world_motion_authority.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/navigation/terrain_surface_navigator.dart';
import 'package:runner_core/navigation/terrain_surface_pathfinder.dart';
import 'package:runner_core/players/player_catalog.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/tuning/ground_enemy_tuning.dart';
import 'package:runner_core/tuning/physics_tuning.dart';
import 'package:test/test.dart';

void main() {
  for (final character in PlayerCharacterRegistry.playable) {
    for (final facing in Facing.values) {
      for (final scenario in [
        for (final distance in [0.0, 12.0, 24.0, 39.0, 80.0])
          for (final combo in [false, true])
            for (final closingSpeed in [0.0, 300.0])
              (
                distance: distance,
                combo: combo,
                closingSpeed: closingSpeed,
                playerSpeed: 0.0,
                tickHz: 60,
              ),
        for (final tickHz in [30, 60, 90])
          for (final closingSpeed in [0.0, -300.0])
            (
              distance: 12.0,
              combo: false,
              closingSpeed: closingSpeed,
              playerSpeed: character.tuning.movement.maxSpeedX,
              tickHz: tickHz,
            ),
      ]) {
        final (:distance, :combo, :closingSpeed, :playerSpeed, :tickHz) =
            scenario;
        final stationary = playerSpeed == 0;
        final playerDirection = facing == Facing.left ? 1.0 : -1.0;
        test(
          '${character.id.name} ${stationary ? 'stationary' : 'running'}, '
          '$facing, distance=$distance, combo=$combo, closingSpeed=$closingSpeed, '
          'tickHz=$tickHz: ${stationary ? 'Grojib spaces before striking and hits once' : 'player passes Grojib during a slow backstep'}',
          () {
            final world = EcsWorld(seed: 7);
            final movement = MovementTuningDerived.from(
              character.tuning.movement,
              tickHz: tickHz,
            );
            final playerDef = PlayerCatalogDerived.from(
              character.catalog,
              movement: movement,
              resources: ResourceTuningDerived.from(character.tuning.resource),
            ).archetype;
            final player = EntityFactory(world).createPlayer(
              posX: 300,
              posY: stationary
                  ? 0
                  : 100 - playerDef.collider.offsetY - playerDef.collider.halfY,
              velX: playerDirection * playerSpeed,
              velY: 0,
              facing: Facing.right,
              grounded: false,
              body: playerDef.body,
              collider: playerDef.collider,
              health: playerDef.health,
              mana: playerDef.mana,
              stamina: playerDef.stamina,
            );
            final enemyDef = const EnemyCatalog().get(EnemyId.grojib);
            final enemy = EntityFactory(world).createEnemy(
              enemyId: EnemyId.grojib,
              posX: 300 + (facing == Facing.left ? distance : -distance),
              posY: 100 - enemyDef.collider.offsetY - enemyDef.collider.halfY,
              velX: facing == Facing.left ? -closingSpeed : closingSpeed,
              velY: 0,
              facing: facing,
              artFacing: enemyDef.artFacingDir,
              body: enemyDef.body,
              collider: enemyDef.collider,
              health: enemyDef.health,
              mana: enemyDef.mana,
              stamina: enemyDef.stamina,
            );
            world.meleeCombo.armed[world.meleeCombo.indexOf(enemy)] = combo;
            final authority = TerrainMultiBodyWorldMotionAuthority(
              geometry: _floor,
              playerProfile: playerDef.terrainTraversalProfile,
            );
            authority.initializePlayer(
              world,
              player: player,
              archetype: playerDef,
            );
            final tuning = GroundEnemyTuningDerived.from(
              const GroundEnemyTuning(),
              tickHz: tickHz,
            );
            final navigation = TerrainEnemyNavigationSystem(
              runtimeBundle: () => authority.terrainRuntimeBundle,
              navigator: TerrainSurfaceNavigator(
                pathfinder: TerrainSurfacePathfinder(maxExpandedNodes: 128),
              ),
              physics: const PhysicsTuning(),
              dtSeconds: 1 / tickHz,
            );
            final engagement = EnemyEngagementSystem(groundEnemyTuning: tuning);
            final melee = EnemyMeleeSystem(groundEnemyTuning: tuning);
            final locomotion = GroundEnemyLocomotionSystem(
              groundEnemyTuning: tuning,
            );
            final anim = AnimSystem(
              tickHz: tickHz,
              enemyCatalog: const EnemyCatalog(),
              playerMovement: movement,
              playerAnimTuning: AnimTuningDerived.from(
                character.tuning.anim,
                tickHz: tickHz,
              ),
            );
            final hurtboxes = CombatHurtboxSystem(
              tickHz: tickHz,
              playerCharacterId: character.id,
              playerRenderAnim: character.renderAnim,
            );
            final strikes = MeleeStrikeSystem();
            final follow = HitboxFollowOwnerSystem();
            final grid = BroadphaseGrid(index: GridIndex2D(cellSize: 64));
            final hits = HitboxDamageSystem();
            final gravity = GravitySystem();
            final playerTi = world.transform.indexOf(player);
            final enemyTi = world.transform.indexOf(enemy);
            final abilityId = combo ? 'grojib.strike2' : 'grojib.strike';
            final ability = AbilityCatalog.shared.resolve(abilityId)!;
            int? committedTick;
            var backedAway = false;
            var sawDirectWalk = false;
            var passedEnemy = false;
            var chasedFromBehind = false;
            final warmupTicks = stationary ? 0 : 6;

            if (!stationary) {
              world.transform.velX[enemyTi] = 0;
              for (var tick = 1; tick <= warmupTicks; tick++) {
                authority.prepareTick(world, player: player, currentTick: tick);
                gravity.step(world, movement, physics: const PhysicsTuning());
                authority.step(
                  world,
                  player: player,
                  movement: movement,
                  fixedPointPilotEnabled: false,
                  fixedPointSubpixelScale: terrainPhysicsTicksPerWorldUnit,
                  currentTick: tick,
                );
              }
              world.transform.velX[playerTi] = playerDirection * playerSpeed;
              world.transform.velX[enemyTi] = facing == Facing.left
                  ? -closingSpeed
                  : closingSpeed;
            }

            for (
              var tick = warmupTicks + 1;
              tick <= warmupTicks + 3 * tickHz;
              tick++
            ) {
              authority.prepareTick(world, player: player, currentTick: tick);
              const ActiveAbilityPhaseSystem().step(world, currentTick: tick);
              navigation.step(world, player: player, currentTick: tick);
              engagement.step(world, player: player, currentTick: tick);
              melee.step(world, player: player, currentTick: tick);
              final separation =
                  (world.transform.posX[playerTi] -
                          world.transform.posX[enemyTi])
                      .abs();
              if (committedTick == null &&
                  world.activeAbility.hasActiveAbility(enemy)) {
                committedTick = tick;
                expect(
                  world.activeAbility.abilityId[world.activeAbility.indexOf(
                    enemy,
                  )],
                  abilityId,
                );
                expect(separation, inInclusiveRange(34, 40));
              }
              locomotion.step(
                world,
                player: player,
                currentTick: tick,
                dtSeconds: 1 / tickHz,
              );
              final awaySpeed = world.transform.velX[enemyTi] * playerDirection;
              final enemyAhead =
                  (world.transform.posX[enemyTi] -
                          world.transform.posX[playerTi]) *
                      playerDirection >
                  0;
              if (!stationary && enemyAhead && awaySpeed > 0) {
                expect(
                  awaySpeed,
                  lessThanOrEqualTo(75.0),
                  reason: 'A close player must be able to catch the backstep',
                );
              }
              if (!stationary && passedEnemy && !enemyAhead && awaySpeed > 0) {
                chasedFromBehind |=
                    world.enemy.facing[world.enemy.indexOf(enemy)] ==
                    (playerDirection > 0 ? Facing.right : Facing.left);
              }
              if (separation < 34) {
                backedAway |=
                    world.transform.velX[enemyTi] *
                        (world.transform.posX[enemyTi] -
                            world.transform.posX[playerTi]) >
                    0;
              }
              sawDirectWalk |= world
                  .navIntent
                  .canWalkDirectlyToTarget[world.navIntent.indexOf(enemy)];
              gravity.step(world, movement, physics: const PhysicsTuning());
              authority.step(
                world,
                player: player,
                movement: movement,
                fixedPointPilotEnabled: false,
                fixedPointSubpixelScale: terrainPhysicsTicksPerWorldUnit,
                currentTick: tick,
              );
              strikes.step(world, currentTick: tick);
              final animIndex = world.animState.indexOf(enemy);
              final previousPhase =
                  world.animState.groundedLocomotionPhaseBp[animIndex];
              anim.step(world, player: player, currentTick: tick);
              if (!stationary &&
                  enemyAhead &&
                  awaySpeed > 1 &&
                  !world.activeAbility.hasActiveAbility(enemy)) {
                expect(world.animState.anim[animIndex], AnimKey.walk);
                expect(
                  world.animState.groundedLocomotionPhaseBp[animIndex] -
                      previousPhase,
                  lessThan(10000),
                  reason: 'Backsteps must not keep full running cadence',
                );
              }
              hurtboxes.step(world);
              grid.rebuild(world);
              follow.step(world, currentTick: tick);
              hits.step(world, grid, currentTick: tick);
              if (stationary) {
                expect(world.transform.posX[playerTi], 300);
              } else if (!passedEnemy &&
                  (world.transform.posX[playerTi] -
                              world.transform.posX[enemyTi]) *
                          playerDirection >
                      0) {
                expect(tick - warmupTicks, lessThanOrEqualTo(tickHz));
                passedEnemy = true;
              }
              if (stationary &&
                  committedTick != null &&
                  tick >=
                      committedTick +
                          ability.windupTicks +
                          ability.activeTicks) {
                break;
              }
            }
            expect(sawDirectWalk, isTrue);
            if (stationary) {
              expect(committedTick, isNotNull);
              if (distance > 0 && distance < 34) expect(backedAway, isTrue);
              expect(world.damageQueue.target, [player]);
              expect(world.damageQueue.amount100, [ability.baseDamage]);
            } else {
              expect(passedEnemy, isTrue);
              expect(chasedFromBehind, isTrue);
            }
          },
        );
      }
    }
  }
}

final _floor = const TerrainCompiler().compile([
  TerrainPolygonInput.fromWorld(
    sourcePath: 'test/grojib-spacing',
    identity: TerrainSourceIdentity(
      chunkIndex: 0,
      chunkKey: 'test',
      shapeId: 'floor',
    ),
    vertices: [(-1000, 100), (1600, 100), (1600, 160), (-1000, 160)],
  ),
], geometryVersion: 1);
