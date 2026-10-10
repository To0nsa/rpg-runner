import 'package:runner_core/collision/terrain/terrain_motion_request.dart';
import 'package:runner_core/combat/control_lock.dart';
import 'package:runner_core/combat/shoggoth_pose_catalog.dart';
import 'package:runner_core/ecs/actor_facing.dart';
import 'package:runner_core/ecs/spatial/broadphase_grid.dart';
import 'package:runner_core/ecs/spatial/grid_index_2d.dart';
import 'package:runner_core/ecs/systems/hitbox_damage_system.dart';
import 'package:runner_core/ecs/systems/hitbox_follow_owner_system.dart';
import 'package:runner_core/ecs/systems/melee_strike_system.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:test/test.dart';

import '../test_support/combat_pose.dart';
import '../test_support/shoggoth_combat_fixture.dart';

void main() {
  for (final hz in [30, 60, 90]) {
    for (final side in [-1, 1]) {
      test(
        'sweep follows a retreating target and stops in recovery, side=$side at $hz Hz',
        () {
          final f = ShoggothCombatFixture(hz: hz, bossX: 300);
          f.placePlayer(f.x + side * 70);
          final start = f.x;
          f.tick(10);
          expect(f.action, 'shoggoth.tentacle_sweep');
          final active = f.world.activeAbility;
          final windup = active.windupTicks[f.ai];
          final recovery = windup + active.activeTicks[f.ai];
          final total = active.totalTicks[f.ai];
          double? recoveryX;
          final movingWindows = <int>{};
          final profile = ShoggothPoseCatalog.shoggothSweep;
          final grid = BroadphaseGrid(index: GridIndex2D(cellSize: 64));
          for (var age = 1; age < total; age++) {
            f.placePlayer(f.x + side * 60);
            final previousX = f.x;
            f.tick(10 + age);
            resolveCombatPoses(f.world, 10 + age, tickHz: hz);
            MeleeStrikeSystem().step(f.world, currentTick: 10 + age);
            HitboxFollowOwnerSystem(tickHz: hz)
                .step(f.world, currentTick: 10 + age);
            grid.rebuild(f.world);
            HitboxDamageSystem().step(f.world, grid, currentTick: 10 + age);
            expect(active.startTick[f.ai], 10);
            expect(f.action, 'shoggoth.tentacle_sweep');
            if (age < recovery) {
              expect((f.x - previousX) * side, greaterThan(0));
              final frame = profile.timing.frameAt(
                elapsed: age,
                windup: windup,
                active: active.activeTicks[f.ai],
                recovery: active.recoveryTicks[f.ai],
              );
              final window = profile.combo!.strikeWindowAt(frame);
              if (window > 0) movingWindows.add(window);
            } else {
              recoveryX ??= f.x;
              expect(f.x, recoveryX);
            }
          }
          expect(movingWindows, {1, 2, 3});
          expect(f.world.damageQueue.target, [f.player, f.player]);
          expect(f.world.damageQueue.comboHit.map((hit) => hit!.strike), [
            1,
            3,
          ]);
          expect((f.x - start) * side, greaterThan(24));
        },
      );

      test(
        'sweep stops at melee spacing without crossing the target, side=$side at $hz Hz',
        () {
          final f = ShoggothCombatFixture(hz: hz, bossX: 300);
          final targetX = f.x + side * 70;
          f.placePlayer(targetX);
          f.tick(10);
          final end = 10 + f.world.activeAbility.totalTicks[f.ai];
          for (var tick = 11; tick < end; tick++) {
            f.tick(tick);
            expect((targetX - f.x) * side, greaterThanOrEqualTo(44.99));
          }
          expect((targetX - f.x).abs(), inInclusiveRange(44.99, 51));
        },
      );
    }

    for (final stop in [
      'route',
      'move lock',
      'stunned',
      'suspended',
      'dead target',
    ]) {
      test('sweep pursuit stops for $stop at $hz Hz', () {
        final f = ShoggothCombatFixture(hz: hz);
        f.placePlayer(f.x + 70);
        f.tick(10);
        f.placePlayer(450);
        final activeStart = 10 + f.world.activeAbility.windupTicks[f.ai];
        for (var tick = 11; tick < activeStart; tick++) {
          f.tick(tick);
        }
        final x = f.x;
        switch (stop) {
          case 'route':
            f.direct = false;
          case 'move lock':
            f.world.controlLock.addLock(f.boss, LockFlag.move, hz, activeStart);
          case 'stunned':
            f.world.controlLock.addLock(f.boss, LockFlag.stun, hz, activeStart);
          case 'suspended':
            f.world.arenaSuspension.addEntity(f.boss);
          case 'dead target':
            f.world.health.hp[f.world.health.indexOf(f.player)] = 0;
        }
        final end = 10 + f.world.activeAbility.totalTicks[f.ai];
        for (var tick = activeStart; tick < end; tick++) {
          f.tick(tick);
          expect(f.x, x);
        }
      });
    }

    for (final wall in [false, true]) {
      test(
        'sweep pursuit obeys ${wall ? 'solid walls' : 'arena bounds'} at $hz Hz',
        () {
          final f = ShoggothCombatFixture(hz: hz, bossX: 280, wall: wall);
          f.placePlayer(330);
          if (!wall) {
            f.world.actorMotionBounds.add(
              f.boss,
              TerrainHorizontalBounds(minXTicks: 0, maxXTicks: 350 * 1024),
            );
          }
          f.tick(10);
          expect(f.action, 'shoggoth.tentacle_sweep');
          f.placePlayer(500);
          final end = 10 + f.world.activeAbility.totalTicks[f.ai];
          for (var tick = 11; tick < end; tick++) {
            f.tick(tick);
            expect(f.x, lessThanOrEqualTo(334.01));
          }
          expect(f.x, closeTo(334, 1));
        },
      );
    }

    test(
      'crossing behind a live sweep pauses pursuit until the next strike, $hz Hz',
      () {
        final f = ShoggothCombatFixture(hz: hz, bossX: 300);
        f.placePlayer(345);
        f.tick(10);
        final active = f.world.activeAbility;
        final profile = ShoggothPoseCatalog.shoggothSweep;
        final windup = active.windupTicks[f.ai];
        final recovery = windup + active.activeTicks[f.ai];
        var crossed = false;
        var followed = false;
        for (var age = 1; age < recovery; age++) {
          final frame = profile.timing.frameAt(
            elapsed: age,
            windup: windup,
            active: active.activeTicks[f.ai],
            recovery: active.recoveryTicks[f.ai],
          );
          final window = profile.combo!.strikeWindowAt(frame);
          // Cross after the first strike has already acquired its direction.
          if (age == windup + 1) {
            f.placePlayer(200);
            crossed = true;
          }
          final x = f.x;
          f.tick(10 + age);
          if (crossed && window == 1) {
            expect(actorFacing(f.world, f.boss), Facing.right);
            expect(f.x, x);
          }
          if (window == 2) {
            expect(actorFacing(f.world, f.boss), Facing.left);
            expect(f.x, lessThan(x));
            followed = true;
          }
        }
        expect(followed, isTrue);
      },
    );

    test(
      'sweeps turn between strikes without flipping a live arc or repeating damage, $hz Hz',
      () {
        final f = ShoggothCombatFixture(hz: hz);
        f.placePlayer(f.x + 45);
        f.decide(10);
        final grid = BroadphaseGrid(index: GridIndex2D(cellSize: 64));
        final profile = ShoggothPoseCatalog.shoggothSweep;
        final active = f.world.activeAbility;
        var previousWindow = 0;
        var expectedFacing = Facing.right;
        final windows = <int>{};
        for (var age = 0; age < active.totalTicks[f.ai]; age++) {
          final frame = profile.timing.frameAt(
            elapsed: age,
            windup: active.windupTicks[f.ai],
            active: active.activeTicks[f.ai],
            recovery: active.recoveryTicks[f.ai],
          );
          final window = profile.combo!.strikeWindowAt(frame);
          final newStrike =
              window != previousWindow && profile.frames[frame].isNotEmpty;
          if (newStrike) {
            expectedFacing = window.isOdd ? Facing.right : Facing.left;
            windows.add(window);
          }
          final direction = expectedFacing == Facing.right ? 1 : -1;
          final distance = window == 2 ? 25 : 45;
          f.placePlayer(f.x + (newStrike ? direction : -direction) * distance);
          f.decide(10 + age);
          f.locomote(10 + age);
          resolveCombatPoses(f.world, 10 + age, tickHz: hz);
          MeleeStrikeSystem().step(f.world, currentTick: 10 + age);
          HitboxFollowOwnerSystem(tickHz: hz)
              .step(f.world, currentTick: 10 + age);
          grid.rebuild(f.world);
          HitboxDamageSystem().step(f.world, grid, currentTick: 10 + age);
          if (profile.frames[frame].isNotEmpty) {
            expect(actorFacing(f.world, f.boss), expectedFacing);
          }
          previousWindow = window;
        }
        expect(windows, {1, 2, 3});
        expect(f.world.damageQueue.target, List.filled(3, f.player));
        expect(f.world.damageQueue.amount100, [700, 700, 700]);
      },
    );

    test(
      'charge tracks during warning, then holds its direction and travels 216 units, $hz Hz',
      () {
        final f = ShoggothCombatFixture(hz: hz, bossX: 300);
        f.placePlayer(450);
        f.tick(10);
        expect(f.action, 'shoggoth.spinning_charge');
        final windup = f.world.activeAbility.windupTicks[f.ai];
        final activeEnd = windup + f.world.activeAbility.activeTicks[f.ai];
        final end = f.world.activeAbility.totalTicks[f.ai];
        for (var age = 1; age < end; age++) {
          f.placePlayer(age < windup ? 150 : 450);
          f.tick(10 + age);
          expect(actorFacing(f.world, f.boss), Facing.left);
          if (age < windup) expect(f.x, 300);
          if (age >= activeEnd) expect(f.x, closeTo(84, .1));
        }
      },
    );

    for (final wall in [false, true]) {
      test(
        'charge obeys ${wall ? 'solid walls' : 'arena bounds'} at $hz Hz',
        () {
          final f = ShoggothCombatFixture(
            hz: hz,
            bossX: wall ? 150 : 440,
            wall: wall,
          );
          f.placePlayer(wall ? 300 : 580);
          f.tick(10);
          final end = 10 + f.world.activeAbility.totalTicks[f.ai];
          final boundary = wall ? 334.0 : 584.0;
          for (var tick = 11; tick < end; tick++) {
            f.tick(tick);
            expect(f.x, lessThanOrEqualTo(boundary + .01));
          }
          expect(f.x, closeTo(boundary, 1));
        },
      );
    }
  }
}
