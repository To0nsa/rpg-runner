import 'package:runner_core/abilities/ability_catalog.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/combat/ai_cast_aim_policy.dart';
import 'package:runner_core/combat/damage.dart';
import 'package:runner_core/ecs/spatial/broadphase_grid.dart';
import 'package:runner_core/ecs/spatial/grid_index_2d.dart';
import 'package:runner_core/ecs/stores/combat/damage_resistance_store.dart';
import 'package:runner_core/ecs/systems/damage_system.dart';
import 'package:runner_core/ecs/systems/enemy_cast_system.dart';
import 'package:runner_core/ecs/systems/enemy_melee_system.dart';
import 'package:runner_core/ecs/systems/hitbox_damage_system.dart';
import 'package:runner_core/ecs/systems/hitbox_follow_owner_system.dart';
import 'package:runner_core/ecs/systems/knockback_system.dart';
import 'package:runner_core/ecs/systems/melee_strike_system.dart';
import 'package:runner_core/ecs/systems/projectile_hit_system.dart';
import 'package:runner_core/ecs/systems/projectile_launch_system.dart';
import 'package:runner_core/ecs/systems/projectile_pose_system.dart';
import 'package:runner_core/ecs/systems/projectile_system.dart';
import 'package:runner_core/ecs/systems/status_system.dart';
import 'package:runner_core/ecs/systems/target_point_impact_system.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/projectiles/projectile_catalog.dart';
import 'package:runner_core/util/vec2.dart';
import 'package:test/test.dart';

import '../test_support/combat_pose.dart';
import '../test_support/goddess_combat_fixture.dart';
import '../test_support/shoggoth_combat_fixture.dart';

void main() {
  for (final hz in [30, 60, 90]) {
    for (final key in [
      'goddess.claw_combo',
      'shoggoth.tentacle_sweep',
      'shoggoth.spinning_charge',
      'shoggoth.return_charge',
    ]) {
      final hasFinisherPush = key != 'goddess.claw_combo';
      final pushRule = hasFinisherPush
          ? 'pushes only its final strike'
          : 'never pushes';
      for (final side in [-1, 1]) {
        for (final mode in ['all', 'miss finisher', 'finisher only']) {
          test('$key $pushRule, $mode side=$side at $hz Hz', () {
            final f = _Fixture(key, hz);
            // Isolate base damage from the fixture's equipment modifiers.
            f.world.equippedLoadout.removeEntity(f.player);
            f.place(side * 35);
            final ability = AbilityCatalog.shared.resolve(key)!;
            final profile = (ability.hitDelivery as MeleeHitDelivery).profile;
            final count = profile.combo!.strikeStartFrames.length;
            expect(count, hasFinisherPush ? 3 : 4);
            final damagePerHit = key == 'goddess.claw_combo'
                ? 500
                : key.endsWith('charge')
                ? 600
                : 700;
            final playerHi = f.world.health.indexOf(f.player);
            final hpBefore = f.world.health.hp[playerHi];
            expect(
              AiMeleeCommitter(tickHz: hz).commit(
                f.world,
                actor: f.boss,
                abilityId: key,
                targetX: f.playerX,
                currentTick: 10,
              ),
              isNotNull,
            );
            final active = f.world.activeAbility;
            final ai = active.indexOf(f.boss);
            final end = 10 + active.totalTicks[ai];
            final strikes = <int>[];
            var pushes = 0;
            for (var tick = 10; tick < end; tick++) {
              final frame = profile.timing.frameAt(
                elapsed: tick - 10,
                windup: active.windupTicks[ai],
                active: active.activeTicks[ai],
                recovery: active.recoveryTicks[ai],
              );
              final last = profile.combo!.strikeWindowAt(frame) == count;
              final miss =
                  mode == 'miss finisher' && last ||
                  mode == 'finisher only' && !last;
              // Sample the visible rear arc for the sweep's second strike;
              // all three spin windows can connect through the central body.
              final reach = key.endsWith('charge')
                  ? 20.0
                  : key == 'shoggoth.tentacle_sweep' && frame == 6
                  ? -25.0
                  : 35.0;
              f.place(side * (miss ? 250.0 : reach));
              resolveCombatPoses(f.world, tick, tickHz: hz);
              MeleeStrikeSystem().step(f.world, currentTick: tick);
              HitboxFollowOwnerSystem(tickHz: hz)
                  .step(f.world, currentTick: tick);
              f.grid.rebuild(f.world);
              HitboxDamageSystem().step(f.world, f.grid, currentTick: tick);
              final queue = f.world.damageQueue;
              for (var i = 0; i < queue.length; i++) {
                expect(queue.target[i], f.player);
                final strike = queue.comboHit[i]!.strike;
                strikes.add(strike);
                expect(queue.amount100[i], damagePerHit);
                expect(
                  queue.knockback[i] != null,
                  hasFinisherPush && strike == count,
                );
                if (queue.knockback[i] != null) {
                  pushes++;
                  expect(queue.knockback[i]!.directionX, side);
                }
              }
              f.damage.step(f.world, currentTick: tick);
              expect(f.world.knockback.has(f.player), pushes > 0);
            }
            expect(
              strikes,
              mode == 'finisher only'
                  ? [count]
                  : List.generate(
                      mode == 'miss finisher' ? count - 1 : count,
                      (i) => i + 1,
                    ),
            );
            expect(pushes, hasFinisherPush && mode != 'miss finisher' ? 1 : 0);
            expect(
              hpBefore - f.world.health.hp[playerHi],
              strikes.length * damagePerHit,
            );
            if (pushes > 0) {
              expect(f.world.knockback.signedDistance.single, side * 112);
            }
          });
        }
      }
    }
    for (final key in ['goddess.orb', 'goddess.eruption', 'shoggoth.orb']) {
      for (final side in [-1, 1]) {
        test(
          '$key applies dark Weaken and knockback, side=$side at $hz Hz',
          () {
            final f = _Fixture(key, hz)..place(side * 140);
            final hit = f.spellHit(key);
            expect(f.world.damageQueue.amount100, [
              key == 'goddess.eruption' ? 1200 : 720,
            ]);
            f.damage.step(
              f.world,
              currentTick: hit,
              queueStatus: f.status.queue,
            );
            f.status.applyQueued(f.world, currentTick: hit);
            final wi = f.world.weaken.indexOf(f.player);
            expect(f.world.weaken.magnitude[wi], 2500);
            expect(f.world.weaken.ticksLeft[wi], 3 * hz);
            final ki = f.world.knockback.indexOf(f.player);
            expect(f.world.knockback.signedDistance[ki], side * 112);
            expect(f.world.knockback.startTick[ki], hit + 1);
            expect(f.world.knockback.durationTicks[ki], (.28 * hz).ceil());
            KnockbackSystem(tickHz: hz).step(f.world, currentTick: hit + 1);
            expect(
              f.world.transform.velX[f.world.transform.indexOf(f.player)].sign,
              side,
            );
            final bossHp = f.world.health.indexOf(f.boss);
            final before = f.world.health.hp[bossHp];
            f.world.damageQueue.add(
              DamageRequest(target: f.boss, source: f.player, amount100: 1000),
            );
            f.damage.step(f.world, currentTick: hit + 1);
            expect(before - f.world.health.hp[bossHp], 750);
            for (var tick = 0; tick < 3 * hz; tick++) {
              f.status.tickExisting(f.world);
            }
            expect(f.world.weaken.has(f.player), isFalse);
          },
        );
      }
      for (final rejected in ['invulnerable', 'resisted', 'cancelled']) {
        test('$key $rejected hit respects effect gates at $hz Hz', () {
          final f = _Fixture(key, hz)..place(140);
          if (rejected == 'invulnerable') {
            f.world.invulnerability.protect(
              f.world.invulnerability.indexOf(f.player),
              10 * hz,
            );
          }
          if (rejected == 'resisted') {
            f.world.damageResistance.add(
              f.player,
              const DamageResistanceDef(darkBp: -10000),
            );
          }
          final hit = f.spellHit(key);
          if (rejected == 'cancelled') f.world.damageQueue.cancel(0);
          f.damage.step(f.world, currentTick: hit, queueStatus: f.status.queue);
          f.status.applyQueued(f.world, currentTick: hit);
          // Damage resistance and status immunity are separate shared rules.
          expect(f.world.weaken.has(f.player), rejected == 'resisted');
          expect(f.world.knockback.has(f.player), isFalse);
        });
      }
    }
  }
}

class _Fixture {
  _Fixture(String key, this.hz)
    : damage = DamageSystem(
        invulnerabilityTicksOnHit: hz ~/ 4,
        rngSeed: 1,
        tickHz: hz,
      ),
      status = StatusSystem(tickHz: hz) {
    if (key.startsWith('goddess.')) {
      final f = GoddessCombatFixture(hz: hz, bossX: 300);
      world = f.world;
      boss = f.boss;
      player = f.player;
      refresh = (tick) =>
          f.combat.refreshOrbCast(world, player: player, currentTick: tick);
    } else {
      final f = ShoggothCombatFixture(hz: hz, bossX: 300);
      world = f.world;
      boss = f.boss;
      player = f.player;
      refresh = (tick) =>
          f.combat.refreshOrbCast(world, player: player, currentTick: tick);
    }
  }
  final int hz;
  final DamageSystem damage;
  final StatusSystem status;
  late final EcsWorld world;
  late final int boss, player;
  late final void Function(int) refresh;
  final grid = BroadphaseGrid(index: GridIndex2D(cellSize: 32));
  double get playerX => world.transform.posX[world.transform.indexOf(player)];
  void place(double dx) =>
      world.transform.posX[world.transform.indexOf(player)] =
          world.transform.posX[world.transform.indexOf(boss)] + dx;

  int spellHit(String key) {
    final ability = AbilityCatalog.shared.resolve(key)!;
    final bi = world.transform.indexOf(boss),
        pi = world.transform.indexOf(player);
    expect(
      AiCastCommitter(
        tickHz: hz,
        projectiles: const ProjectileCatalog(),
        surfaceTarget: (x, y) => Vec2(x, 500),
      ).commit(
        world,
        actor: boss,
        castAbility: ability,
        sourceX: world.transform.posX[bi],
        sourceY: world.transform.posY[bi],
        targetX: playerX,
        targetY: world.transform.posY[pi],
        targetVelX: 0,
        targetVelY: 0,
        aimPolicy: AiCastAimPolicy.targetCenter,
        casterOriginOffset: 30,
        currentTick: 10,
      ),
      isTrue,
    );
    final projectile = ability.hitDelivery is ProjectileHitDelivery;
    final release = projectile
        ? world.projectileIntent.tick[world.projectileIntent.indexOf(boss)]
        : world.targetPointIntent.tick[world.targetPointIntent.indexOf(boss)];
    refresh(release);
    if (projectile) {
      ProjectileLaunchSystem(
        projectiles: const ProjectileCatalog(),
        tickHz: hz,
      ).step(world, currentTick: release);
    } else {
      TargetPointImpactSystem().step(world, currentTick: release);
    }
    final movement = MovementTuningDerived.from(
      const MovementTuning(),
      tickHz: hz,
    );
    for (var tick = release; tick < release + 3 * hz; tick++) {
      if (tick > release) ProjectileSystem().step(world, movement);
      resolveCombatPoses(world, tick, tickHz: hz);
      ProjectilePoseSystem(tickHz: hz).step(world, currentTick: tick);
      HitboxFollowOwnerSystem(tickHz: hz).step(world, currentTick: tick);
      grid.rebuild(world);
      ProjectileHitSystem().step(world, grid, currentTick: tick);
      HitboxDamageSystem().step(world, grid, currentTick: tick);
      if (world.damageQueue.length > 0) {
        expect(world.damageQueue.target, [player]);
        return tick;
      }
    }
    fail('Spell did not hit: $key');
  }
}
