import 'dart:math' as math;

import 'package:runner_core/abilities/ability_catalog.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_edge_index.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/combat/ai_cast_aim_policy.dart';
import 'package:runner_core/combat/faction.dart';
import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/spatial/broadphase_grid.dart';
import 'package:runner_core/ecs/spatial/grid_index_2d.dart';
import 'package:runner_core/ecs/systems/enemy_cast_system.dart';
import 'package:runner_core/ecs/systems/gravity_system.dart';
import 'package:runner_core/ecs/systems/lifetime_system.dart';
import 'package:runner_core/ecs/systems/projectile_hit_system.dart';
import 'package:runner_core/ecs/systems/projectile_launch_system.dart';
import 'package:runner_core/ecs/systems/projectile_pose_system.dart';
import 'package:runner_core/ecs/systems/projectile_system.dart';
import 'package:runner_core/ecs/systems/projectile_world_collision_system.dart';
import 'package:runner_core/ecs/systems/terrain_ballistic_projectile_system.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/npcs/npc_id.dart';
import 'package:runner_core/npcs/npc_catalog.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/projectiles/projectile_catalog.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/projectiles/spawn_projectile_item.dart';
import 'package:runner_core/traps/spawn_trap_dart.dart';
import 'package:runner_core/traps/trap_id.dart';
import 'package:runner_core/traps/trap_placement.dart';
import 'package:runner_core/tuning/physics_tuning.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:test/test.dart';

void main() {
  for (final hz in [30, 60, 120]) {
    for (final direction in [-1, 1]) {
      for (final spear in [true, false]) {
        test(
          '${spear ? 'spear' : 'dart'} curves and lands before expiry at $hz Hz / $direction',
          () {
            final scene = _Scene(hz);
            final world = scene.world;
            final projectile = spear
                ? _spawnSpear(world, hz, direction)
                : spawnTrapDart(
                    world,
                    source: const TrapSourceRef(
                      trapId: TrapId.poisonDarts,
                      chunkKey: 'test',
                      chunkIndex: 0,
                      placementOrdinal: 0,
                    ),
                    x: 0,
                    y: 190,
                    directionX: direction.toDouble(),
                    tick: 0,
                    tickHz: hz,
                  );
            LifetimeSystem().step(
              world,
            ); // Core also cleans up on the spawn tick.
            var rose = false;
            var fell = false;
            var landed = false;
            var travelTicks = 0;
            final samples = <(double, double, double, double)>[];
            while (world.projectile.has(projectile) && travelTicks < hz * 6) {
              scene.move(++travelTicks);
              final ti = world.transform.indexOf(projectile);
              final ci = world.collision.indexOf(projectile);
              final x = world.transform.posX[ti];
              final y = world.transform.posY[ti];
              final vy = world.transform.velY[ti];
              rose |= y < 190;
              fell |= vy > 0;
              samples.add((
                x,
                y,
                world.projectile.dirX.single,
                world.projectile.dirY.single,
              ));
              landed |= world.collision.grounded[ci];
              ProjectileWorldCollisionSystem().step(world);
              LifetimeSystem().step(world);
            }
            expect(landed, isTrue);
            expect(fell, isTrue);
            expect(rose, spear);
            expect(travelTicks, lessThan(hz * 2));
            expect(world.projectile.has(projectile), isFalse);
            expect(samples.last.$1.sign, direction);
            expect(samples.last.$2, lessThanOrEqualTo(222));
            expect(samples.any((s) => s.$4 > 0), isTrue);
          },
        );
      }
      for (final (distance, targetSpeed, gravity) in [
        (120.0, 0.0, 1200.0),
        (260.0, 0.0, 1200.0),
        (180.0, 40.0, 1200.0),
        (160.0, 0.0, 600.0),
        (120.0, 0.0, 1800.0),
      ]) {
        test(
          'Huntress hits at $distance px / $targetSpeed speed / $gravity gravity / $hz Hz / $direction',
          () {
            final scene = _Scene(hz, gravityY: gravity);
            final world = scene.world;
            final npc = EntityFactory(world).createNpc(
              npcId: NpcId.huntress,
              posX: 0,
              posY: 195,
              chunkStartX: -500,
              chunkEndX: 500,
            );
            world.worldContactCapsule.add(
              npc,
              const NpcCatalog().terrainContactProfile(NpcId.huntress).capsule,
            );
            final enemyDef = const EnemyCatalog().get(EnemyId.hashash);
            final targetX = direction * distance;
            final enemy = EntityFactory(world).createEnemy(
              enemyId: EnemyId.hashash,
              posX: targetX,
              posY: 193.5,
              velX: 0,
              velY: 0,
              facing: direction > 0 ? Facing.left : Facing.right,
              artFacing: enemyDef.artFacingDir,
              body: enemyDef.body,
              collider: enemyDef.collider,
              health: enemyDef.health,
              mana: enemyDef.mana,
              stamina: enemyDef.stamina,
            );
            world.worldContactCapsule.add(
              enemy,
              const EnemyCatalog()
                  .terrainContactProfile(EnemyId.hashash)
                  .capsule,
            );
            final committed =
                AiCastCommitter(
                  tickHz: hz,
                  projectiles: const ProjectileCatalog(),
                  physics: scene.physics,
                ).commit(
                  world,
                  actor: npc,
                  castAbility: AbilityCatalog.shared.resolve(
                    'npc_huntress.throw_spear',
                  )!,
                  sourceX: 0,
                  sourceY: 195,
                  targetX: targetX,
                  targetY: 200.5,
                  targetVelX: direction * targetSpeed,
                  targetVelY: 0,
                  aimPolicy: AiCastAimPolicy.predictedTargetCenter,
                  casterOriginOffset: 18,
                  casterOriginOffsetY: -31.5,
                  currentTick: 10,
                );
            expect(committed, isTrue);
            final release = world
                .projectileIntent
                .tick[world.projectileIntent.indexOf(npc)];
            world.transform.setPosXY(
              enemy,
              targetX + direction * targetSpeed * (release - 10) / hz,
              193.5,
            );
            ProjectileLaunchSystem(
              projectiles: const ProjectileCatalog(),
              tickHz: hz,
            ).step(world, currentTick: release);
            final projectile = world.projectile.denseEntities.single;
            final initial = world.transform.indexOf(projectile);
            expect(
              math.sqrt(
                math.pow(world.transform.velX[initial], 2) +
                    math.pow(world.transform.velY[initial], 2),
              ),
              closeTo(420, 1e-9),
            );
            final grid = BroadphaseGrid(index: GridIndex2D(cellSize: 64));
            for (
              var tick = release + 1;
              tick < release + hz * 2 && world.projectile.has(projectile);
              tick++
            ) {
              final ti = world.transform.indexOf(enemy);
              world.transform.posX[ti] += direction * targetSpeed / hz;
              scene.move(tick);
              grid.rebuild(world);
              ProjectileHitSystem().step(world, grid, currentTick: tick);
              ProjectileWorldCollisionSystem().step(world);
              LifetimeSystem().step(world);
            }
            expect(world.damageQueue.target, [enemy]);
            expect(world.damageQueue.amount100, [450]);
            expect(world.projectile.has(projectile), isFalse);
          },
        );
      }
    }
  }

  test(
    'unreachable ballistic casts leave resources and cooldowns untouched',
    () {
      final world = EcsWorld();
      final npc = EntityFactory(world).createNpc(
        npcId: NpcId.huntress,
        posX: 0,
        posY: 195,
        chunkStartX: -500,
        chunkEndX: 500,
      );
      final ability = AbilityCatalog.shared.resolve(
        'npc_huntress.throw_spear',
      )!;
      expect(
        AiCastCommitter(
          tickHz: 60,
          projectiles: const ProjectileCatalog(),
        ).commit(
          world,
          actor: npc,
          castAbility: ability,
          sourceX: 0,
          sourceY: 195,
          targetX: 1000,
          targetY: 200,
          targetVelX: 0,
          targetVelY: 0,
          aimPolicy: AiCastAimPolicy.predictedTargetCenter,
          casterOriginOffset: 18,
          casterOriginOffsetY: -31.5,
          currentTick: 1,
        ),
        isFalse,
      );
      expect(world.stamina.stamina[world.stamina.indexOf(npc)], 4000);
      expect(world.activeAbility.hasActiveAbility(npc), isFalse);
      expect(
        world.cooldown.isOnCooldown(
          npc,
          ability.effectiveCooldownGroup(AbilitySlot.projectile),
        ),
        isFalse,
      );
      expect(
        world.projectileIntent.tick[world.projectileIntent.indexOf(npc)],
        -1,
      );
    },
  );

  for (final spear in [true, false]) {
    test(
      '${spear ? 'spear' : 'dart'} retains bounded cleanup over a deep gap',
      () {
        final scene = _Scene(60, withGround: false);
        final world = scene.world;
        final projectile = spear
            ? _spawnSpear(world, 60, 1)
            : spawnTrapDart(
                world,
                source: const TrapSourceRef(
                  trapId: TrapId.poisonDarts,
                  chunkKey: 'gap',
                  chunkIndex: 0,
                  placementOrdinal: 0,
                ),
                x: 0,
                y: 190,
                directionX: 1,
                tick: 0,
                tickHz: 60,
              );
        final lifetime =
            world.lifetime.ticksLeft[world.lifetime.indexOf(projectile)];
        for (var tick = 0; tick < lifetime - 1; tick++) {
          scene.move(tick);
          LifetimeSystem().step(world);
        }
        expect(world.projectile.has(projectile), isTrue);
        expect(
          world.transform.posY[world.transform.indexOf(projectile)],
          greaterThan(222),
        );
        LifetimeSystem().step(world);
        expect(world.projectile.has(projectile), isFalse);
      },
    );
  }
}

int _spawnSpear(EcsWorld world, int hz, int direction) {
  final definition = const ProjectileCatalog().get(ProjectileId.npcSpear);
  return spawnProjectileFromCaster(
    world,
    tickHz: hz,
    currentTick: 0,
    projectileId: ProjectileId.npcSpear,
    projectile: definition,
    faction: Faction.player,
    owner: 0,
    casterX: 0,
    casterY: 190,
    originOffset: 0,
    dirX: direction.toDouble(),
    dirY: -.5,
    fallbackDirX: direction.toDouble(),
    fallbackDirY: 0,
    damage100: 450,
    critChanceBp: 0,
    damageType: definition.damageType,
    ballistic: definition.ballistic,
    gravityScale: definition.gravityScale,
  );
}

class _Scene {
  _Scene(this.hz, {double gravityY = 1200, bool withGround = true})
    : physics = PhysicsTuning(gravityY: gravityY),
      movement = MovementTuningDerived.from(
        const MovementTuning(),
        tickHz: hz,
      ) {
    final terrain = const TerrainCompiler().compile([
      TerrainPolygonInput.fromWorld(
        sourcePath: 'test/projectile-ground',
        identity: TerrainSourceIdentity(
          chunkIndex: 0,
          chunkKey: 'test',
          shapeId: 'floor',
        ),
        vertices: const [(-1000, 222), (1000, 222), (1000, 400), (-1000, 400)],
      ),
    ], geometryVersion: 1);
    motion = TerrainBallisticProjectileSystem(
      edgeIndex: TerrainEdgeIndex(edges: withGround ? terrain.edges : const []),
    );
  }
  final int hz;
  final world = EcsWorld();
  final PhysicsTuning physics;
  final MovementTuningDerived movement;
  late final TerrainBallisticProjectileSystem motion;

  void move(int tick) {
    ProjectileSystem().capturePhysicsPositions(world);
    GravitySystem().step(world, movement, physics: physics);
    motion.step(world, movement);
    ProjectileSystem().step(world, movement);
    ProjectilePoseSystem(tickHz: hz).step(world, currentTick: tick);
  }
}
