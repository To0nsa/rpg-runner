import 'dart:math' as math;

import 'package:runner_core/ecs/spatial/broadphase_grid.dart';
import 'package:runner_core/ecs/spatial/grid_index_2d.dart';
import 'package:runner_core/ecs/systems/combat_hurtbox_system.dart';
import 'package:runner_core/ecs/systems/projectile_hit_system.dart';
import 'package:runner_core/ecs/systems/projectile_launch_system.dart';
import 'package:runner_core/ecs/systems/projectile_pose_system.dart';
import 'package:runner_core/ecs/systems/projectile_system.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/projectiles/projectile_catalog.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:test/test.dart';

import '../test_support/goddess_combat_fixture.dart';

void main() {
  for (final hz in [30, 60, 90]) {
    for (final bossX in [100.0, 500.0]) {
      for (final height in [0.0, 150.0]) {
        test(
          'orb follows its aim line from x=$bossX height=$height at $hz Hz',
          () {
            final f = GoddessCombatFixture(hz: hz, bossX: bossX);
            final world = f.world;
            final bossTi = world.transform.indexOf(f.boss);
            world.transform.posY[bossTi] -= height;
            f.combat.step(world, player: f.player, currentTick: 10);
            expect(f.action, 'goddess.orb');
            final ii = world.projectileIntent.indexOf(f.boss);
            final release = world.projectileIntent.tick[ii];
            ProjectileLaunchSystem(
              projectiles: const ProjectileCatalog(),
              tickHz: hz,
            ).step(world, currentTick: release);
            final projectile = world.projectile.denseEntities.single;
            final pi = world.projectile.indexOf(projectile);
            final dx = world.projectile.dirX[pi];
            final dy = world.projectile.dirY[pi];
            expect(dx.sign, bossX < 300 ? 1 : -1);

            final poses = ProjectilePoseSystem(tickHz: hz);
            // Exercise startup and every flight pose, including their rotation.
            for (var age = 0; age < hz; age++) {
              poses.step(world, currentTick: release + age);
              final capsule = world.projectile.combatCapsule[pi]!;
              final cx = (capsule.ax + capsule.bx) / 2;
              final cy = (capsule.ay + capsule.by) / 2;
              expect((cx * -dy + cy * dx).abs(), lessThanOrEqualTo(1.6));
              expect(math.sqrt(cx * cx + cy * cy), lessThan(6));
            }

            CombatHurtboxSystem(tickHz: hz).step(world);
            final grid = BroadphaseGrid(index: GridIndex2D(cellSize: 32))
              ..rebuild(world);
            final target = grid.targets.entities.indexOf(f.player);
            final targetX = grid.targets.centerX[target];
            final targetY = grid.targets.centerY[target];
            final movement = MovementTuningDerived.from(
              const MovementTuning(),
              tickHz: hz,
            );
            final motion = ProjectileSystem();
            final hits = ProjectileHitSystem();
            final events = <ProjectileHitEvent>[];
            for (var tick = release; tick <= release + hz; tick++) {
              if (tick > release) motion.step(world, movement);
              poses.step(world, currentTick: tick);
              hits.step(
                world,
                grid,
                currentTick: tick,
                queueHitEvent: events.add,
              );
              if (events.isNotEmpty) break;
            }
            expect(world.damageQueue.target, [f.player]);
            expect(world.projectile.has(projectile), isFalse);
            final event = events.single;
            expect(event.projectileId, ProjectileId.goddessOrb);
            expect(event.targetCenter.x, targetX);
            expect(event.targetCenter.y, targetY);
            expect((event.pos.x - targetX).abs(), greaterThan(10));
          },
        );
      }
    }
  }
}
