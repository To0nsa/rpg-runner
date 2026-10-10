import 'dart:math' as math;

import 'package:runner_core/combat/control_lock.dart';
import 'package:runner_core/ecs/actor_facing.dart';
import 'package:runner_core/ecs/systems/projectile_launch_system.dart';
import 'package:runner_core/enemies/shoggoth_render_catalog.dart';
import 'package:runner_core/players/characters/eloise.dart';
import 'package:runner_core/projectiles/projectile_catalog.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:test/test.dart';

import '../test_support/combat_pose.dart';
import '../test_support/shoggoth_combat_fixture.dart';

void main() {
  for (final hz in [30, 60, 90]) {
    for (final (initial, targetHeight) in [
      for (final facing in Facing.values)
        for (final height in [0.0, -100.0]) (facing, height),
    ]) {
      test(
        'orb follows the casting hand and turns through release, $hz Hz $initial height=$targetHeight',
        () {
          final f = ShoggothCombatFixture(hz: hz, bossX: 300);
          final firstX = initial == Facing.left ? 20.0 : 580.0;
          f.placePlayer(firstX);
          f.tick(10);
          expect(f.action, 'shoggoth.orb');
          final intent = f.world.projectileIntent;
          final pi = intent.indexOf(f.boss);
          final release = intent.tick[pi];
          final start = f.world.activeAbility.startTick[f.ai];
          for (var tick = 11; tick < release; tick++) {
            f.placePlayer(tick.isEven ? 20 : 580);
            f.tick(tick);
            expect(
              actorFacing(f.world, f.boss),
              tick.isEven ? Facing.left : Facing.right,
            );
            expect(intent.tick[pi], release);
            expect(f.world.activeAbility.startTick[f.ai], start);
            expect(f.world.projectile.denseEntities, isEmpty);
          }

          // Cross after the decision/movement phases on the release tick. The
          // final cast refresh must observe the same positions as the renderer.
          f.placePlayer(firstX);
          f.decide(release, prepareMotion: true);
          f.locomote(release);
          f.integrate(release);
          f.placePlayer(600 - firstX, y: f.playerY + targetHeight);
          f.combat.refreshOrbCast(
            f.world,
            player: f.player,
            currentTick: release,
          );
          final facing = initial == Facing.left ? Facing.right : Facing.left;
          expect(actorFacing(f.world, f.boss), facing);
          expect(f.world.activeAbility.facing[f.ai], facing);
          resolveCombatPoses(f.world, release, tickHz: hz);
          final anim = f.world.animState.indexOf(f.boss);
          expect(f.world.animState.anim[anim], AnimKey.cast);
          final frameTicks =
              (ShoggothRenderCatalog.actor.stepTimeSecondsByKey[AnimKey.cast]! *
                      hz)
                  .round();
          expect(f.world.animState.animFrame[anim] ~/ frameTicks, 8);

          final launch = ProjectileLaunchSystem(
            projectiles: const ProjectileCatalog(),
            tickHz: hz,
          );
          launch.step(f.world, currentTick: release);
          final orb = f.world.projectile.denseEntities.single;
          final oi = f.world.projectile.indexOf(orb);
          final ti = f.world.transform.indexOf(orb);
          final bi = f.world.transform.indexOf(f.boss);
          final playerTi = f.world.transform.indexOf(f.player);
          final originX =
              f.world.transform.posX[bi] + (facing == Facing.left ? -35 : 35);
          final originY = f.world.transform.posY[bi] + 14;
          expect(f.world.transform.posX[ti], originX);
          expect(f.world.transform.posY[ti], originY);
          final dx =
              f.world.transform.posX[playerTi] +
              eloiseCatalog.colliderOffsetX -
              originX;
          final dy =
              f.world.transform.posY[playerTi] +
              eloiseCatalog.colliderOffsetY -
              originY;
          final length = math.sqrt(dx * dx + dy * dy);
          expect(f.world.projectile.dirX[oi], closeTo(dx / length, 1e-12));
          expect(f.world.projectile.dirY[oi], closeTo(dy / length, 1e-12));

          final dirX = f.world.projectile.dirX[oi];
          final dirY = f.world.projectile.dirY[oi];
          f.placePlayer(firstX);
          f.tick(release + 1);
          launch.step(f.world, currentTick: release + 1);
          expect(actorFacing(f.world, f.boss), initial);
          expect(f.world.projectile.denseEntities, [orb]);
          expect(f.world.projectile.dirX[oi], dirX);
          expect(f.world.projectile.dirY[oi], dirY);
        },
      );
    }

    for (final reason in [
      'cancel',
      'replace',
      'death',
      'stun',
      'suspend',
      'target death',
    ]) {
      test('$reason cancels the pending hand release, $hz Hz', () {
        final f = ShoggothCombatFixture(hz: hz, bossX: 100);
        f.placePlayer(500);
        f.tick(10);
        final pi = f.world.projectileIntent.indexOf(f.boss);
        final tick = f.world.projectileIntent.tick[pi];
        switch (reason) {
          case 'cancel':
            f.world.activeAbility.clear(f.boss);
          case 'replace':
            f.world.activeAbility.startTick[f.ai]++;
          case 'death':
            f.hp = 0;
          case 'stun':
            f.world.controlLock.addLock(f.boss, LockFlag.stun, hz, tick);
          case 'suspend':
            f.world.arenaSuspension.addEntity(f.boss);
          case 'target death':
            f.world.health.hp[f.world.health.indexOf(f.player)] = 0;
        }
        f.combat.refreshOrbCast(f.world, player: f.player, currentTick: tick);
        ProjectileLaunchSystem(
          projectiles: const ProjectileCatalog(),
          tickHz: hz,
        ).step(f.world, currentTick: tick);
        expect(f.world.projectile.denseEntities, isEmpty);
        expect(f.world.projectileIntent.tick[pi], -1);
      });
    }
  }

  test('body-relative projectile origins survive swap removal and reset on ID reuse', () {
    final f = ShoggothCombatFixture();
    final other = f.world.createEntity();
    final intents = f.world.projectileIntent;
    intents.add(other);
    intents.sourceOffsetX[intents.indexOf(other)] = 37;
    intents.sourceOffsetY[intents.indexOf(other)] = 12;
    f.world.destroyEntity(f.boss);
    expect(intents.sourceOffsetX[intents.indexOf(other)], 37);
    expect(intents.sourceOffsetY[intents.indexOf(other)], 12);
    final recycled = f.world.createEntity();
    expect(recycled, f.boss);
    intents.add(recycled);
    expect(intents.sourceOffsetX[intents.indexOf(recycled)], 0);
    expect(intents.sourceOffsetY[intents.indexOf(recycled)], 0);
  });
}
