import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_motion_request.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/stores/enemies/shoggoth_tactics_store.dart';
import 'package:runner_core/ecs/systems/active_ability_phase_system.dart';
import 'package:runner_core/ecs/systems/boss_utility_system.dart';
import 'package:runner_core/ecs/systems/control_lock_system.dart';
import 'package:runner_core/ecs/systems/cooldown_system.dart';
import 'package:runner_core/ecs/systems/enemy_cast_system.dart';
import 'package:runner_core/ecs/systems/gravity_system.dart';
import 'package:runner_core/ecs/systems/boss_flight_system.dart';
import 'package:runner_core/ecs/systems/shoggoth_combat_system.dart';
import 'package:runner_core/ecs/systems/world_motion_authority.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/players/characters/eloise.dart';
import 'package:runner_core/players/player_catalog.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/projectiles/projectile_catalog.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/spawn_service.dart';
import 'package:runner_core/tuning/physics_tuning.dart';
import 'package:runner_core/util/vec2.dart';
import 'package:test/test.dart';

/// Runs production action clocks and terrain integration on a finite floor.
/// Tests control target placement and the navigation result explicitly; authored
/// arena integration separately exercises the production navigation system.
final class ShoggothCombatFixture {
  ShoggothCombatFixture({
    this.hz = 60,
    double bossX = 200,
    bool wall = false,
    bool ceiling = false,
    double wallX = 350,
    double wallWidth = 25,
    PlayerCharacterDefinition character = eloiseCharacter,
  }) {
    final tuning = character.tuning;
    movement = MovementTuningDerived.from(tuning.movement, tickHz: hz);
    final archetype = PlayerCatalogDerived.from(
      character.catalog,
      movement: movement,
      resources: ResourceTuningDerived.from(tuning.resource),
    ).archetype;
    final factory = EntityFactory(world);
    playerY = 500 - archetype.collider.offsetY - archetype.collider.halfY;
    player = factory.createPlayer(
      posX: 300,
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
    final spawns = _Spawns(world);
    boss = spawns.spawnGroundEnemy(
      enemyId: EnemyId.shoggoth,
      spawnX: bossX,
      groundTopY: 500,
    );
    world.spawnState.removeEntity(boss);
    motion = TerrainMultiBodyWorldMotionAuthority(
      geometry: const TerrainCompiler().compile([
        _rectangle('floor', 0, 500, 600, 600),
        if (wall) _rectangle('wall', wallX, 300, wallX + wallWidth, 500),
        if (ceiling) _rectangle('ceiling', 150, 300, 450, 320),
      ], geometryVersion: 17),
      playerProfile: archetype.terrainTraversalProfile,
    );
    motion.initializePlayer(world, player: player, archetype: archetype);
    world.actorMotionBounds.add(
      boss,
      TerrainHorizontalBounds(minXTicks: 0, maxXTicks: 600 * 1024),
    );
    utilities = BossUtilitySystem(
      tickHz: hz,
      motion: motion,
      spawns: spawns,
      groundTopY: 500,
    );
    combat = ShoggothCombatSystem(
      tickHz: hz,
      utilities: utilities,
      castCommitter: AiCastCommitter(
        tickHz: hz,
        projectiles: const ProjectileCatalog(),
        surfaceTarget: (x, y) => Vec2(x, 500),
      ),
    );
    locomotion = BossFlightSystem(tickHz: hz);
    for (var tick = 1; tick < 10; tick++) {
      motion.prepareTick(world, player: player, currentTick: tick);
      integrate(tick);
    }
  }

  final int hz;
  final world = EcsWorld(seed: 41);
  late final int player, boss;
  late final double playerY;
  late final MovementTuningDerived movement;
  late final TerrainMultiBodyWorldMotionAuthority motion;
  late final ShoggothCombatSystem combat;
  late final BossUtilitySystem utilities;
  late final BossFlightSystem locomotion;
  ShoggothTactics get state => world.shoggothTactics.stateFor(boss);
  int get ai => world.activeAbility.indexOf(boss);
  double get x => world.transform.posX[world.transform.indexOf(boss)];
  String? get action => world.activeAbility.abilityId[ai];
  set hp(int value) => world.health.hp[world.health.indexOf(boss)] = value;

  void placePlayer(double x, {double? y}) {
    final origin = motion.beginBodyTeleport(world, player);
    final placed = motion.tryCommitBodyTeleport(
      world,
      player,
      bodyX: x,
      bodyY: y ?? playerY,
      facing: Facing.right,
    );
    if (!placed) motion.cancelBodyTeleport(world, player, origin);
    expect(placed, isTrue);
  }

  void decide(int tick, {bool prepareMotion = false}) {
    utilities.prepare(world, player: player, currentTick: tick);
    if (prepareMotion) {
      motion.prepareTick(world, player: player, currentTick: tick);
    }
    CooldownSystem().step(world);
    ControlLockSystem().step(world, currentTick: tick);
    combat.prepare(world, currentTick: tick);
    const ActiveAbilityPhaseSystem().step(world, currentTick: tick);
    utilities.executeTeleports(world, player: player, currentTick: tick);
    combat.step(world, player: player, currentTick: tick);
  }

  void locomote(int tick) {
    locomotion.step(world, currentTick: tick);
  }

  void integrate(int tick) {
    GravitySystem().step(world, movement, physics: const PhysicsTuning());
    motion.step(
      world,
      player: player,
      movement: movement,
      fixedPointPilotEnabled: false,
      fixedPointSubpixelScale: 1024,
      currentTick: tick,
    );
  }

  void tick(int tick) {
    decide(tick, prepareMotion: true);
    locomote(tick);
    integrate(tick);
    combat.refreshOrbCast(world, player: player, currentTick: tick);
  }
}

final class _Spawns implements SpawnService {
  _Spawns(this.world);
  final EcsWorld world;

  @override
  int spawnGroundEnemy({
    EnemyId enemyId = EnemyId.grojib,
    required double spawnX,
    required double groundTopY,
    double? spawnBodyY,
    int? spawnTick,
  }) {
    final a = const EnemyCatalog().get(enemyId);
    return EntityFactory(world).createEnemy(
      enemyId: enemyId,
      posX: spawnX,
      posY: spawnBodyY ?? groundTopY - a.collider.offsetY - a.collider.halfY,
      velX: 0,
      velY: 0,
      facing: Facing.right,
      artFacing: a.artFacingDir,
      body: a.body,
      collider: a.collider,
      health: a.health,
      mana: a.mana,
      stamina: a.stamina,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected spawn');
}

TerrainPolygonInput _rectangle(
  String id,
  double l,
  double t,
  double r,
  double b,
) => TerrainPolygonInput.fromWorld(
  sourcePath: 'test/$id',
  identity: TerrainSourceIdentity(chunkIndex: 0, chunkKey: 'test', shapeId: id),
  surfaceKind: id == 'floor' ? 'ground' : 'obstacle',
  vertices: [(l, t), (r, t), (r, b), (l, b)],
);
