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
    test(
      'sweep advances at most 24 units in windup and holds through strikes/recovery, $hz Hz',
      () {
        final f = ShoggothCombatFixture(hz: hz);
        final start = f.x;
        f.tick(10);
        expect(f.action, 'shoggoth.tentacle_sweep');
        final active = f.world.activeAbility;
        final windup = active.windupTicks[f.ai];
        final total = active.totalTicks[f.ai];
        double? attackX;
        for (var age = 1; age < total; age++) {
          f.placePlayer(450);
          f.tick(10 + age);
          expect(f.x, lessThanOrEqualTo(start + 24.01));
          if (age >= windup) {
            attackX ??= f.x;
            expect(f.x, attackX);
          }
        }
        expect(f.x - start, greaterThan(15));
      },
    );

    test(
      'sweeps turn between strikes without flipping a live arc or repeating damage, $hz Hz',
      () {
        final f = ShoggothCombatFixture(hz: hz);
        f.placePlayer(f.x + 65);
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
            expectedFacing = window == 1 ? Facing.right : Facing.left;
            windows.add(window);
          }
          final direction = expectedFacing == Facing.right ? 1 : -1;
          f.placePlayer(f.x + (newStrike ? direction : -direction) * 65);
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
        expect(windows, {1, 2});
        expect(f.world.damageQueue.target, [f.player, f.player]);
        expect(f.world.damageQueue.amount100, [700, 700]);
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
          final boundary = wall ? 326.0 : 576.0;
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
