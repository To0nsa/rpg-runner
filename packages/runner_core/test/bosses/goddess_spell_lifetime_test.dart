import 'package:runner_core/abilities/ability_catalog.dart';
import 'package:runner_core/bosses/boss_arena_definition.dart';
import 'package:runner_core/bosses/boss_arena_system.dart';
import 'package:runner_core/camera/autoscroll_camera.dart';
import 'package:runner_core/combat/ai_cast_aim_policy.dart';
import 'package:runner_core/ecs/spatial/broadphase_grid.dart';
import 'package:runner_core/ecs/spatial/grid_index_2d.dart';
import 'package:runner_core/ecs/stores/death_state_store.dart';
import 'package:runner_core/ecs/stores/enemies/enemy_store.dart';
import 'package:runner_core/ecs/stores/hitbox_store.dart';
import 'package:runner_core/ecs/systems/control_lock_system.dart';
import 'package:runner_core/ecs/systems/damage_system.dart';
import 'package:runner_core/ecs/systems/enemy_cast_system.dart';
import 'package:runner_core/ecs/systems/hitbox_damage_system.dart';
import 'package:runner_core/ecs/systems/hitbox_follow_owner_system.dart';
import 'package:runner_core/ecs/systems/invulnerability_system.dart';
import 'package:runner_core/ecs/systems/lifetime_system.dart';
import 'package:runner_core/ecs/systems/projectile_hit_system.dart';
import 'package:runner_core/ecs/systems/projectile_launch_system.dart';
import 'package:runner_core/ecs/systems/projectile_pose_system.dart';
import 'package:runner_core/ecs/systems/projectile_system.dart';
import 'package:runner_core/ecs/systems/target_point_impact_system.dart';
import 'package:runner_core/enemies/death_behavior.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/projectiles/projectile_catalog.dart';
import 'package:runner_core/snapshots/boss_arena_snapshot.dart';
import 'package:runner_core/track/track_streamer.dart';
import 'package:runner_core/util/vec2.dart';
import 'package:test/test.dart';

import '../test_support/goddess_combat_fixture.dart';

void main() {
  for (final hz in [30, 60, 90]) {
    for (final removed in [false, true]) {
      test('orb hits after caster death (removed=$removed) at $hz Hz', () {
        final f = _Fixture(hz);
        final release = f.commit('goddess.orb');
        f.launch(release);
        final world = f.base.world;
        final orb = world.projectile.denseEntities.single;
        final ti = world.transform.indexOf(orb);
        final x = world.transform.posX[ti];
        f.defeat(removed: removed);
        final movement = MovementTuningDerived.from(
          const MovementTuning(),
          tickHz: hz,
        );
        final motion = ProjectileSystem();
        final grid = BroadphaseGrid(index: GridIndex2D(cellSize: 32));
        final poses = ProjectilePoseSystem(tickHz: hz);
        final hits = ProjectileHitSystem();
        motion.step(world, movement);
        expect(
          world.transform.posX[world.transform.indexOf(orb)],
          greaterThan(x),
        );
        for (var tick = release + 1; tick < release + hz; tick++) {
          f.arena.protectCombat(world, f.base.player);
          poses.step(world, currentTick: tick);
          grid.rebuild(world);
          hits.step(world, grid, currentTick: tick);
          if (!world.projectile.has(orb)) break;
          motion.step(world, movement);
        }
        expect(world.projectile.has(orb), isFalse);
        f.expectDamage(720, removed: removed);
      });

      test(
        'released hand keeps its warning and slap after death (removed=$removed) at $hz Hz',
        () {
          final f = _Fixture(hz);
          final release = f.commit('goddess.eruption');
          final world = f.base.world;
          TargetPointImpactSystem().step(world, currentTick: release);
          final hand = world.hitbox.denseEntities.single;
          final hi = world.hitbox.indexOf(hand);
          final step = world.hitbox.frameStepTicks[hi];
          final lifetime =
              world.lifetime.ticksLeft[world.lifetime.indexOf(hand)];
          f.defeat(removed: removed);
          final follow = HitboxFollowOwnerSystem(tickHz: hz);
          final hits = HitboxDamageSystem();
          final grid = BroadphaseGrid(index: GridIndex2D(cellSize: 32));
          for (var age = 0; age < lifetime; age++) {
            f.arena.protectCombat(world, f.base.player);
            follow.step(world, currentTick: release + age);
            grid.rebuild(world);
            hits.step(world, grid, currentTick: release + age);
            expect(world.damageQueue.length, age < 10 * step ? 0 : 1);
            LifetimeSystem().step(world);
            expect(world.hitbox.has(hand), age < lifetime - 1);
          }
          f.expectDamage(1200, removed: removed);
        },
      );
    }

    test(
      'death preserves orb expiry and cancels unlaunched casts at $hz Hz',
      () {
        final f = _Fixture(hz);
        final release = f.commit('goddess.orb');
        final world = f.base.world;
        f.defeat();
        f.launch(release);
        expect(world.projectile.denseEntities, isEmpty);

        final released = _Fixture(hz);
        released.launch(released.commit('goddess.orb'));
        final w = released.base.world;
        final orb = w.projectile.denseEntities.single;
        final remaining = w.lifetime.ticksLeft[w.lifetime.indexOf(orb)];
        released.defeat(removed: true);
        expect(w.lifetime.ticksLeft[w.lifetime.indexOf(orb)], remaining);
        // Isolate the expiry clock from motion and contact.
        for (var age = 1; age <= remaining; age++) {
          LifetimeSystem().step(w);
          expect(w.projectile.has(orb), age < remaining);
        }
      },
    );
  }

  test('defeat still cancels attached melee and other actors attacks', () {
    final f = _Fixture(60);
    f.launch(f.commit('goddess.orb'));
    final world = f.base.world;
    final orb = world.projectile.denseEntities.single;
    final melee = world.createEntity();
    world.hitbox.add(
      melee,
      HitboxDef(
        owner: f.base.boss,
        faction: world.projectile.faction[0],
        damage100: 500,
        damageType: world.projectile.damageType[0],
        dirX: 1,
        dirY: 0,
      ),
    );
    final other = world.createEntity();
    world.hitbox.add(
      other,
      HitboxDef(
        owner: f.base.player,
        faction: world.projectile.faction[0],
        damage100: 100,
        damageType: world.projectile.damageType[0],
        attachment: HitboxAttachment.worldAnchor,
        dirX: 1,
        dirY: 0,
      ),
    );
    f.defeat();
    expect(world.projectile.has(orb), isTrue);
    expect(world.hitbox.has(melee), isFalse);
    expect(world.hitbox.has(other), isFalse);
  });
}

final class _Fixture {
  _Fixture(this.hz)
    : base = GoddessCombatFixture(hz: hz, bossX: 100),
      arena = BossArenaSystem(tickHz: hz) {
    final world = base.world;
    arena.synchronize([
      ActiveTrackChunkSnapshot(
        index: 0,
        startX: 0,
        endX: 600,
        patternName: 'arena',
        chunkKey: 'arena',
        bossArena: BossArenaDefinition(
          id: 'test_goddess',
          enemyId: EnemyId.voidbornGoddess,
          spawnX: 100,
          minX: 24,
          maxX: 576,
        ),
      ),
    ], 600);
    arena.afterCamera(
      world,
      player: base.player,
      camera: CameraState(
        centerX: 300,
        targetX: 300,
        centerY: 135,
        targetY: 135,
        speedX: 0,
      ),
      tick: 1,
    );
    prepare(2);
    arena.control(world, player: base.player, tick: 2);
    ControlLockSystem().step(world, currentTick: start);
    prepare(start);
    InvulnerabilitySystem().step(world);
    InvulnerabilitySystem().step(world);
    arena.control(world, player: base.player, tick: start);
    world.spawnState.removeEntity(base.boss);
    expect(arena.snapshot(world)!.phase, BossArenaPhase.combat);
  }
  final int hz;
  final GoddessCombatFixture base;
  final BossArenaSystem arena;
  int get start => hz * 3 + 2;

  void prepare(int tick) => arena.prepare(
    base.world,
    player: base.player,
    tick: tick,
    spawn: (_, _) => base.boss,
  );

  int commit(String key) {
    final world = base.world;
    final ti = world.transform.indexOf(base.boss);
    expect(
      AiCastCommitter(
        tickHz: hz,
        projectiles: const ProjectileCatalog(),
        surfaceTarget: (x, y) => Vec2(x, 500),
      ).commit(
        world,
        actor: base.boss,
        castAbility: AbilityCatalog.shared.resolve(key)!,
        sourceX: world.transform.posX[ti],
        sourceY: world.transform.posY[ti],
        targetX: 300,
        targetY: base.playerY,
        targetVelX: 0,
        targetVelY: 0,
        aimPolicy: AiCastAimPolicy.targetCenter,
        currentTick: start + 1,
      ),
      isTrue,
    );
    return key == 'goddess.orb'
        ? world.projectileIntent.tick[world.projectileIntent.indexOf(base.boss)]
        : world.targetPointIntent.tick[world.targetPointIntent.indexOf(
            base.boss,
          )];
  }

  void launch(int tick) => ProjectileLaunchSystem(
    projectiles: const ProjectileCatalog(),
    tickHz: hz,
  ).step(base.world, currentTick: tick);

  void defeat({bool removed = false}) {
    final world = base.world;
    world.health.hp[world.health.indexOf(base.boss)] = 0;
    arena.resolve(world, playerDead: false);
    world.deathState.add(
      base.boss,
      DeathStateDef(
        phase: DeathPhase.deathAnim,
        deathStartTick: start,
        despawnTick: start + hz,
      ),
    );
    expect(arena.snapshot(world)!.phase, BossArenaPhase.defeated);
    arena.control(world, player: base.player, tick: start + 1);
    if (removed) {
      world.destroyEntity(base.boss);
      expect(world.createEntity(), base.boss);
      world.enemy.add(base.boss, const EnemyDef(enemyId: EnemyId.grojib));
      world.deathState.add(
        base.boss,
        const DeathStateDef(phase: DeathPhase.deathAnim),
      );
      prepare(start + hz + 1);
      expect(arena.snapshot(world), isNull);
    }
  }

  void expectDamage(int amount, {required bool removed}) {
    final world = base.world;
    expect(world.damageQueue.target, [base.player]);
    expect(world.damageQueue.amount100, [amount]);
    expect(world.damageQueue.sourceEnemyId, [EnemyId.voidbornGoddess]);
    expect(world.damageQueue.sourceEntity, [removed ? null : base.boss]);
    final hi = world.health.indexOf(base.player);
    final hp = world.health.hp[hi];
    DamageSystem(
      invulnerabilityTicksOnHit: 0,
      rngSeed: 7,
      tickHz: hz,
    ).step(world, currentTick: start + hz * 2);
    expect(
      world.health.hp[hi],
      lessThan(hp),
      reason: 'normal player defenses still apply',
    );
  }
}
