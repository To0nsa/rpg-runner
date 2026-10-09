import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_motion_request.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/combat/combat_combo.dart';
import 'package:runner_core/combat/control_lock.dart';
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
import 'package:test/test.dart';

import '../test_support/combat_pose.dart';
import 'ancient_god_arena_test.dart' show ancientGodTestCore;

void main() {
  test('player commands produce the same dodge and counter in two Core runs', () {
    final a = ancientGodTestCore(EnemyId.voidbornGoddess);
    final b = ancientGodTestCore(EnemyId.voidbornGoddess);
    var vanished = false;
    var countered = false;
    double? floorBodyY;
    for (var n = 0; n < 3000 && !a.gameOver; n++) {
      final before = a.buildSnapshot();
      final boss = before.entities
          .where((e) => e.enemyId == EnemyId.voidbornGoddess)
          .firstOrNull;
      final player = before.playerEntity!;
      final dx = boss == null ? 0.0 : boss.pos.x - player.pos.x;
      if (boss != null) floorBodyY ??= boss.pos.y;
      // Let the protected barrage and its uninterrupted return finish before
      // delivering the fourth eligible attack; return damage cannot trigger it.
      final attack =
          boss != null &&
          boss.anim != AnimKey.ranged &&
          boss.pos.y >= floorBodyY! - .01;
      final tick = a.tick + 1;
      final commands = <Command>[
        MoveAxisCommand(tick: tick, axis: dx.abs() > 20 ? dx.sign : 0),
        AimDirCommand(tick: tick, x: dx >= 0 ? 1 : -1, y: 0),
        if (attack && n % 20 == 0) StrikePressedCommand(tick: tick),
        if (attack && n % 45 == 0) ProjectilePressedCommand(tick: tick),
      ];
      for (final core in [a, b]) {
        core.applyCommands(commands);
        core.stepOneTick();
      }
      final after = a.buildSnapshot();
      final repeated = b.buildSnapshot();
      expect(repeated.hud.hp, after.hud.hp);
      expect(
        repeated.entities.map(
          (e) => [e.id, e.pos.x, e.pos.y, e.anim, e.animFrame],
        ),
        after.entities.map(
          (e) => [e.id, e.pos.x, e.pos.y, e.anim, e.animFrame],
        ),
      );
      final actor = after.entities
          .where((e) => e.enemyId == EnemyId.voidbornGoddess)
          .firstOrNull;
      if (actor?.anim == AnimKey.teleportOut) vanished = true;
      if (boss?.anim == AnimKey.teleportOut && actor?.anim == AnimKey.strike) {
        expect(
          (boss!.pos.x - player.pos.x) * (actor!.pos.x - player.pos.x),
          lessThan(0),
        );
        expect((actor.pos.x - player.pos.x).abs(), closeTo(35, 1));
        countered = true;
        break;
      }
    }
    expect(vanished, isTrue);
    expect(countered, isTrue);
  });

  for (final hz in [30, 60, 90]) {
    for (final bossX in [100.0, 400.0]) {
      test('fourth attack crosses player from $bossX at $hz Hz', () {
        final f = _Fixture(hz: hz, bossX: bossX);
        f.world.cooldown.setTicksLeft(f.boss, 0, hz * 5);
        for (var hit = 0; hit < 4; hit++) {
          f.queue();
        }
        f.damage(10);
        expect(
          f.hp,
          11700,
          reason:
              'only the fourth hit is canceled; ${f.combat.utilities.motion.lastSpawnPlacementDiagnostic}',
        );
        expect(f.action, 'goddess.dodge');
        expect(f.attacks, 0);
        final execute = 10 + (8 * hz / 60).ceil();
        final frames = <int>{};
        for (var tick = 10; tick < execute; tick++) {
          f.prepare(tick);
          resolveCombatPoses(f.world, tick, tickHz: hz);
          expect(f.x, bossX, reason: 'vanish precedes relocation');
          final anim = f.world.animState.indexOf(f.boss);
          expect(f.world.animState.anim[anim], AnimKey.teleportOut);
          frames.add(f.world.animState.animFrame[anim]);
        }
        expect(frames.length, 4, reason: 'the full vanish strip plays');
        f.prepare(execute);
        expect(f.x, bossX < 300 ? 335 : 265);
        expect(f.action, 'goddess.claw_combo');
        final active = f.world.activeAbility.indexOf(f.boss);
        expect(
          f.world.activeAbility.facing[active],
          bossX < 300 ? Facing.left : Facing.right,
        );
        expect(f.world.activeAbility.startTick[active], execute);
        expect(
          f.world.meleeIntent.tick[f.world.meleeIntent.indexOf(f.boss)],
          execute + (24 * hz / 60).ceil(),
        );
        expect(f.world.cooldown.getTicksLeft(f.boss, 0), hz * 5);
        expect(f.world.gravityControl.has(f.boss), isFalse);
        f.resolveCounterHits(execute);
        expect(f.world.damageQueue.target, List.filled(4, f.player));
        f.world.damageQueue.clear();
        // A completed counter leaves the cadence ready for another four attacks.
        f.prepare(execute + hz * 3);
        for (var hit = 0; hit < 4; hit++) {
          f.queue();
        }
        f.damage(execute + hz * 3);
        expect(f.hp, 11400);
        expect(f.action, 'goddess.dodge');
      });
    }
  }

  test('each player combo counts once and an evaded combo stays evaded', () {
    final f = _Fixture();
    for (var activation = 1; activation <= 4; activation++) {
      for (var strike = 1; strike <= 4; strike++) {
        f.queue(combo: f.combo(activation, strike));
        f.damage(activation * 10 + strike);
      }
    }
    expect(f.hp, 10800, reason: 'three complete combos land');
    expect(f.action, 'goddess.dodge');
    expect(f.attacks, 0);
    f.prepare(49);
    expect(f.action, 'goddess.claw_combo');
    f.queue(combo: f.combo(4, 5));
    f.damage(50);
    expect(f.hp, 10800);
    expect(f.attacks, 0);
  });

  test(
    'projectiles and direct spell impacts also advance the dodge cadence',
    () {
      final f = _Fixture();
      for (final kind in [
        DeathSourceKind.projectile,
        DeathSourceKind.spellImpact,
        DeathSourceKind.meleeHitbox,
        DeathSourceKind.projectile,
      ]) {
        f.queue(kind: kind);
      }
      f.damage(10);
      expect(f.hp, 11700);
      expect(f.action, 'goddess.dodge');
    },
  );

  test('damage over time and nonplayer sources do not count', () {
    final f = _Fixture();
    for (var hit = 0; hit < 4; hit++) {
      f.queue(kind: DeathSourceKind.statusEffect);
      f.queue(source: f.boss);
    }
    f.damage(10);
    expect(f.hp, 11200);
    expect(f.attacks, 0);
    expect(f.action, isNull);
  });

  for (final blocked in ['arena edge', 'gap', 'wall']) {
    test('$blocked rejects a dodge without spending its cadence', () {
      final f = _Fixture(blocked: blocked);
      for (var hit = 0; hit < 4; hit++) {
        f.queue();
      }
      f.damage(10);
      expect(f.hp, 11600);
      expect(f.attacks, 3);
      expect(f.action, isNull);
      expect(f.x, 100);
      f.world.transform.setPosXY(f.player, 200, f.playerY);
      f.queue();
      f.damage(11);
      expect(f.hp, 11600);
      expect(f.action, 'goddess.dodge');
    });
  }

  for (final reason in [
    'stun',
    'suspension',
    'player death',
    'blocked landing',
  ]) {
    test('$reason during vanish cancels pending placement and counter', () {
      final f = _Fixture();
      for (var hit = 0; hit < 4; hit++) {
        f.queue();
      }
      f.damage(10);
      f.prepare(11);
      switch (reason) {
        case 'stun':
          f.world.controlLock.addLock(f.boss, LockFlag.stun, 30, 12);
        case 'suspension':
          f.world.arenaSuspension.addEntity(f.boss);
        case 'player death':
          f.world.health.hp[f.world.health.indexOf(f.player)] = 0;
        case 'blocked landing':
          f.world.transform.setPosXY(f.player, 590, f.playerY);
      }
      f.prepare(18);
      expect(f.x, 100);
      expect(f.action, isNull);
      expect(f.world.gravityControl.has(f.boss), isFalse);
      expect(
        f.world.goddessDodge.executeTick[f.world.goddessDodge.indexOf(f.boss)],
        -1,
      );
    });
  }

  test('barrage cast and return never trigger a reactive dodge', () {
    final f = _Fixture();
    f.world.goddessBarrage.addEntity(f.boss);
    for (var hit = 0; hit < 4; hit++) {
      f.queue();
    }
    f.damage(10);
    expect(f.attacks, 0);
    expect(f.action, isNull);
  });

  test('destroying an actor clears its dodge cadence and combo ledger', () {
    final f = _Fixture();
    f.queue(combo: f.combo(1, 1));
    f.damage(10);
    f.world.destroyEntity(f.boss);
    expect(f.world.goddessDodge.has(f.boss), isFalse);
    final replacement = f.world.createEntity();
    expect(replacement, f.boss);
    final recycled = f.world.goddessDodge.addEntity(replacement);
    expect(f.world.goddessDodge.attacks[recycled], 0);
    expect(f.world.goddessDodge.comboDodged[recycled], isEmpty);
  });
}

final class _Fixture {
  _Fixture({this.hz = 60, double bossX = 100, String? blocked}) {
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
    final motion = TerrainMultiBodyWorldMotionAuthority(
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
  final world = EcsWorld(seed: 41);
  late final int boss;
  late final int player;
  late final double playerY;
  late final VoidbornGoddessCombatSystem combat;
  late final DamageMiddlewareSystem middleware;
  late final DamageSystem damageSystem;
  int get hp => world.health.hp[world.health.indexOf(boss)];
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
