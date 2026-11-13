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
      for (final distance in [0.0, 12.0, 24.0, 39.0, 80.0]) {
        for (final combo in [false, true]) {
          for (final closingSpeed in [0.0, 300.0]) {
            test(
              '${character.id.name} stationary, $facing, distance=$distance, '
              'combo=$combo, closingSpeed=$closingSpeed: Grojib spaces before striking and hits once',
              () {
                final world = EcsWorld(seed: 7);
                final movement = MovementTuningDerived.from(
                  character.tuning.movement,
                  tickHz: 60,
                );
                final playerDef = PlayerCatalogDerived.from(
                  character.catalog,
                  movement: movement,
                  resources: ResourceTuningDerived.from(
                    character.tuning.resource,
                  ),
                ).archetype;
                final player = EntityFactory(world).createPlayer(
                  posX: 300,
                  posY: 0,
                  velX: 0,
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
                  posY:
                      100 - enemyDef.collider.offsetY - enemyDef.collider.halfY,
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
                  tickHz: 60,
                );
                final navigation = TerrainEnemyNavigationSystem(
                  runtimeBundle: () => authority.terrainRuntimeBundle,
                  navigator: TerrainSurfaceNavigator(
                    pathfinder: TerrainSurfacePathfinder(maxExpandedNodes: 128),
                  ),
                  physics: const PhysicsTuning(),
                  dtSeconds: 1 / 60,
                );
                final engagement = EnemyEngagementSystem(
                  groundEnemyTuning: tuning,
                );
                final melee = EnemyMeleeSystem(groundEnemyTuning: tuning);
                final locomotion = GroundEnemyLocomotionSystem(
                  groundEnemyTuning: tuning,
                );
                final anim = AnimSystem(
                  tickHz: 60,
                  enemyCatalog: const EnemyCatalog(),
                  playerMovement: movement,
                  playerAnimTuning: AnimTuningDerived.from(
                    character.tuning.anim,
                    tickHz: 60,
                  ),
                );
                final hurtboxes = CombatHurtboxSystem(
                  tickHz: 60,
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

                for (var tick = 1; tick <= 180; tick++) {
                  authority.prepareTick(
                    world,
                    player: player,
                    currentTick: tick,
                  );
                  const ActiveAbilityPhaseSystem().step(
                    world,
                    currentTick: tick,
                  );
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
                    dtSeconds: 1 / 60,
                  );
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
                  anim.step(world, player: player, currentTick: tick);
                  hurtboxes.step(world);
                  grid.rebuild(world);
                  follow.step(world, currentTick: tick);
                  hits.step(world, grid, currentTick: tick);
                  expect(world.transform.posX[playerTi], 300);
                  if (committedTick != null &&
                      tick >=
                          committedTick +
                              ability.windupTicks +
                              ability.activeTicks) {
                    break;
                  }
                }
                expect(sawDirectWalk, isTrue);
                expect(committedTick, isNotNull);
                if (distance > 0 && distance < 34) expect(backedAway, isTrue);
                expect(world.damageQueue.target, [player]);
                expect(world.damageQueue.amount100, [ability.baseDamage]);
              },
            );
          }
        }
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
    vertices: [(0, 100), (600, 100), (600, 160), (0, 160)],
  ),
], geometryVersion: 1);
