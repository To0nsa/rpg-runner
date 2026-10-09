import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_motion_request.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/combat/combat_combo.dart';
import 'package:runner_core/combat/damage.dart';
import 'package:runner_core/combat/middleware/goddess_dodge_middleware.dart';
import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/spatial/broadphase_grid.dart';
import 'package:runner_core/ecs/spatial/grid_index_2d.dart';
import 'package:runner_core/ecs/systems/active_ability_phase_system.dart';
import 'package:runner_core/ecs/systems/boss_utility_system.dart';
import 'package:runner_core/ecs/systems/damage_middleware_system.dart';
import 'package:runner_core/ecs/systems/damage_system.dart';
import 'package:runner_core/ecs/systems/enemy_cast_system.dart';
import 'package:runner_core/ecs/systems/hitbox_damage_system.dart';
import 'package:runner_core/ecs/systems/hitbox_follow_owner_system.dart';
import 'package:runner_core/ecs/systems/melee_strike_system.dart';
import 'package:runner_core/ecs/systems/voidborn_goddess_combat_system.dart';
import 'package:runner_core/ecs/systems/world_motion_authority.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/players/characters/eloise.dart';
import 'package:runner_core/players/player_catalog.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/projectiles/projectile_catalog.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/spawn_service.dart';

import 'combat_pose.dart';

import 'package:runner_core/util/vec2.dart';

final class GoddessCombatFixture {
  GoddessCombatFixture({
    this.hz = 60,
    double bossX = 280,
    String? blocked,
    int seed = 41,
  }) : world = EcsWorld(seed: seed) {
    final tuning = eloiseCharacter.tuning;
    final archetype = PlayerCatalogDerived.from(
      eloiseCharacter.catalog,
      movement: MovementTuningDerived.from(tuning.movement, tickHz: hz),
      resources: ResourceTuningDerived.from(tuning.resource),
    ).archetype;
    final factory = EntityFactory(world);
    playerY = 500 - archetype.collider.offsetY - archetype.collider.halfY;
    player = factory.createPlayer(
      posX: blocked == 'arena edge' ? 580 : 300,
      posY: playerY,
      velX: 0,
      velY: 0,
      facing: archetype.facing,
      grounded: true,
      body: archetype.body,
      collider: archetype.collider,
      health: archetype.health,
      mana: archetype.mana,
      stamina: archetype.stamina,
    );
    final goddess = const EnemyCatalog().get(EnemyId.voidbornGoddess);
    boss = factory.createEnemy(
      enemyId: EnemyId.voidbornGoddess,
      posX: bossX,
      posY: 500 - goddess.collider.offsetY - goddess.collider.halfY,
      velX: 0,
      velY: 0,
      facing: Facing.left,
      artFacing: goddess.artFacingDir,
      body: goddess.body,
      collider: goddess.collider,
      health: goddess.health,
      mana: goddess.mana,
      stamina: goddess.stamina,
    );
    world.spawnState.removeEntity(boss);
    final geometry = const TerrainCompiler().compile([
      if (blocked == 'gap') ...[
        _rectangle('floor_left', 0, 500, 315, 600),
        _rectangle('floor_right', 355, 500, 600, 600),
      ] else
        _rectangle('floor', 0, 500, 600, 600),
      if (blocked == 'wall') _rectangle('wall', 325, 380, 345, 500),
    ], geometryVersion: 17);
    motion = TerrainMultiBodyWorldMotionAuthority(
      geometry: geometry,
      playerProfile: archetype.terrainTraversalProfile,
    );
    motion.initializePlayer(world, player: player, archetype: archetype);
    motion.prepareTick(world, player: player, currentTick: 1);
    world.actorMotionBounds.add(
      boss,
      TerrainHorizontalBounds(
        minXTicks: 0,
        maxXTicks: 600 * terrainPhysicsTicksPerWorldUnit,
      ),
    );
    combat = VoidbornGoddessCombatSystem(
      tickHz: hz,
      castCommitter: AiCastCommitter(
        tickHz: hz,
        projectiles: const ProjectileCatalog(),
        surfaceTarget: (x, y) => Vec2(x, 500),
      ),
      utilities: BossUtilitySystem(
        tickHz: hz,
        motion: motion,
        spawns: _NoSpawns(),
        groundTopY: 500,
      ),
    );
    middleware = DamageMiddlewareSystem(
      middlewares: [
        GoddessDodgeMiddleware(tryBeginDodge: combat.tryBeginDodge),
      ],
    );
    damageSystem = DamageSystem(
      invulnerabilityTicksOnHit: 0,
      rngSeed: 41,
      tickHz: hz,
    );
  }

  final int hz;
  final EcsWorld world;
  late final int boss;
  late final int player;
  late final double playerY;
  late final VoidbornGoddessCombatSystem combat;
  late final TerrainMultiBodyWorldMotionAuthority motion;
  late final DamageMiddlewareSystem middleware;
  late final DamageSystem damageSystem;
  int get hp => world.health.hp[world.health.indexOf(boss)];
  int get state => world.goddessDodge.indexOf(boss);
  int get interval => world.goddessDodge.attackInterval[state];
  double get x => world.transform.posX[world.transform.indexOf(boss)];
  String? get action =>
      world.activeAbility.abilityId[world.activeAbility.indexOf(boss)];
  int get attacks {
    final i = world.goddessDodge.tryIndexOf(boss);
    return i == null ? 0 : world.goddessDodge.attacks[i];
  }

  ComboHit combo(int activation, int strike) =>
      ComboHit(source: player, activation: activation, strike: strike);

  void queue({
    ComboHit? combo,
    int? source,
    DeathSourceKind kind = DeathSourceKind.meleeHitbox,
  }) => world.damageQueue.add(
    DamageRequest(
      target: boss,
      amount100: 100,
      source: source ?? player,
      sourceKind: kind,
      comboHit: combo,
    ),
  );

  void damage(int tick) {
    middleware.step(world, currentTick: tick);
    damageSystem.step(world, currentTick: tick);
  }

  void prepare(int tick) {
    const ActiveAbilityPhaseSystem().step(world, currentTick: tick);
    combat.prepareDodge(world, currentTick: tick);
  }

  void resolveCounterHits(int commit) {
    final grid = BroadphaseGrid(index: GridIndex2D(cellSize: 64));
    final ai = world.activeAbility.indexOf(boss);
    final execute = world.meleeIntent.tick[world.meleeIntent.indexOf(boss)];
    final end = commit + world.activeAbility.totalTicks[ai];
    for (var tick = execute; tick < end; tick++) {
      resolveCombatPoses(world, tick, tickHz: hz);
      MeleeStrikeSystem().step(world, currentTick: tick);
      HitboxFollowOwnerSystem(tickHz: hz).step(world, currentTick: tick);
      grid.rebuild(world);
      HitboxDamageSystem().step(world, grid, currentTick: tick);
    }
  }
}

final class _NoSpawns implements SpawnService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected spawn during dodge');
}

TerrainPolygonInput _rectangle(
  String id,
  double left,
  double top,
  double right,
  double bottom,
) => TerrainPolygonInput.fromWorld(
  sourcePath: 'test/$id',
  identity: TerrainSourceIdentity(chunkIndex: 0, chunkKey: 'test', shapeId: id),
  surfaceKind: id.startsWith('floor') ? 'ground' : 'obstacle',
  vertices: [(left, top), (right, top), (right, bottom), (left, bottom)],
);
