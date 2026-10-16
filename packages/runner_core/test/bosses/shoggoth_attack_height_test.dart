import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/combat/damage.dart';
import 'package:runner_core/ecs/actor_facing.dart';
import 'package:runner_core/ecs/systems/damage_system.dart';
import 'package:runner_core/ecs/spatial/broadphase_grid.dart';
import 'package:runner_core/ecs/spatial/grid_index_2d.dart';
import 'package:runner_core/ecs/systems/enemy_melee_system.dart';
import 'package:runner_core/ecs/systems/hitbox_damage_system.dart';
import 'package:runner_core/ecs/systems/hitbox_follow_owner_system.dart';
import 'package:runner_core/ecs/systems/melee_strike_system.dart';
import 'package:runner_core/ecs/systems/projectile_hit_system.dart';
import 'package:runner_core/ecs/systems/projectile_launch_system.dart';
import 'package:runner_core/ecs/systems/projectile_pose_system.dart';
import 'package:runner_core/ecs/systems/projectile_system.dart';
import 'package:runner_core/ecs/world_support_view.dart';
import 'package:runner_core/players/characters/eloise.dart';
import 'package:runner_core/players/characters/eloise_wip.dart';
import 'package:runner_core/projectiles/projectile_catalog.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:test/test.dart';

import '../test_support/combat_pose.dart';
import '../test_support/shoggoth_combat_fixture.dart';

void main() {
  for (final hz in [30, 60, 90]) {
    for (final character in [eloiseCharacter, eloiseWipCharacter]) {
      for (final facing in Facing.values) {
        for (final distance in [0.0, 10.0, 20.0, 30.0, 35.0]) {
          test(
            'point-blank retaliation at $distance against ${character.id.name}, $facing, $hz Hz',
            () {
              final f = ShoggothCombatFixture(
                hz: hz,
                bossX: 300,
                character: character,
              );
              final direction = facing == Facing.right ? 1 : -1;
              f.placePlayer(f.x + direction * distance);
              setActorFacing(f.world, f.boss, facing);
              f.tick(10);
              expect(f.action, 'shoggoth.spinning_charge');
              final start = f.world.activeAbility.startTick[f.ai];
              final windup = f.world.activeAbility.windupTicks[f.ai];
              final total = f.world.activeAbility.totalTicks[f.ai];
              final grid = BroadphaseGrid(index: GridIndex2D(cellSize: 64));
              final damage = DamageSystem(
                invulnerabilityTicksOnHit: hz ~/ 4,
                rngSeed: 1,
                tickHz: hz,
              );
              final pi = f.world.health.indexOf(f.player);
              final initialHp = f.world.health.hp[pi];
              for (var age = 0; age < total; age++) {
                final tick = 10 + age;
                if (age > 0) f.tick(tick);
                resolveCombatPoses(f.world, tick, tickHz: hz);
                MeleeStrikeSystem().step(f.world, currentTick: tick);
                HitboxFollowOwnerSystem(tickHz: hz)
                    .step(f.world, currentTick: tick);
                grid.rebuild(f.world);
                HitboxDamageSystem().step(f.world, grid, currentTick: tick);
                // Continuous accepted incoming hits must not cancel retaliation.
                f.world.damageQueue.add(
                  DamageRequest(target: f.boss, source: f.player, amount100: 1),
                );
                damage.step(f.world, currentTick: tick);
                expect(f.world.activeAbility.startTick[f.ai], start);
                if (age < windup) expect(f.world.health.hp[pi], initialHp);
              }
              expect(f.world.health.hp[pi], lessThan(initialHp));
              expect(
                f.world.health.hp[f.world.health.indexOf(f.boss)],
                lessThan(30000),
              );
            },
          );
        }

        test('orb hits grounded ${character.id.name}, $facing, $hz Hz', () {
          final f = ShoggothCombatFixture(
            hz: hz,
            bossX: facing == Facing.right ? 100 : 500,
            character: character,
          );
          f.placePlayer(facing == Facing.right ? 400 : 200);
          f.tick(10);
          expect(f.action, 'shoggoth.orb');
          final execute = 10 + f.world.activeAbility.windupTicks[f.ai];
          final launch = ProjectileLaunchSystem(
            projectiles: const ProjectileCatalog(),
            tickHz: hz,
          );
          final grid = BroadphaseGrid(index: GridIndex2D(cellSize: 64));
          for (var tick = 11; tick <= execute + hz; tick++) {
            f.tick(tick);
            launch.step(f.world, currentTick: tick);
            ProjectileSystem().step(f.world, f.movement);
            ProjectilePoseSystem(tickHz: hz).step(f.world, currentTick: tick);
            resolveCombatPoses(f.world, tick, tickHz: hz);
            grid.rebuild(f.world);
            ProjectileHitSystem().step(f.world, grid, currentTick: tick);
          }
          expect(f.world.damageQueue.target, [f.player]);
          expect(f.world.damageQueue.amount100, [720]);
          expect(WorldSupportView(f.world).isGrounded(f.player), isTrue);
        });

        for (final key in [
          'shoggoth.tentacle_sweep',
          'shoggoth.spinning_charge',
          'shoggoth.return_charge',
        ]) {
          test('$key hits grounded ${character.id.name}, $facing, $hz Hz', () {
            final f = ShoggothCombatFixture(
              hz: hz,
              bossX: 300,
              character: character,
            );
            final direction = facing == Facing.right ? 1 : -1;
            final sweep = key == 'shoggoth.tentacle_sweep';
            final targetX = f.x + direction * (sweep ? 45 : 140);
            f.placePlayer(targetX);
            expect(
              AiMeleeCommitter(tickHz: hz).commit(
                f.world,
                actor: f.boss,
                abilityId: key,
                targetX: targetX,
                currentTick: 10,
              ),
              isNotNull,
            );
            final windup = f.world.activeAbility.windupTicks[f.ai];
            final total = f.world.activeAbility.totalTicks[f.ai];
            final grid = BroadphaseGrid(index: GridIndex2D(cellSize: 64));
            for (var age = 0; age < total; age++) {
              final tick = 10 + age;
              f.tick(tick);
              resolveCombatPoses(f.world, tick, tickHz: hz);
              MeleeStrikeSystem().step(f.world, currentTick: tick);
              HitboxFollowOwnerSystem(tickHz: hz)
                  .step(f.world, currentTick: tick);
              grid.rebuild(f.world);
              HitboxDamageSystem().step(f.world, grid, currentTick: tick);
              if (age < windup) expect(f.world.damageQueue.length, 0);
              // Victims stay on the actual floor throughout the attack, rather
              // than being raised to the boss's transform or a sampled pose.
              final pi = f.world.transform.indexOf(f.player);
              expect(WorldSupportView(f.world).isGrounded(f.player), isTrue);
              expect(
                f.world.transform.posY[pi],
                closeTo(
                  f.playerY -
                      terrainCollisionSkinTicks /
                          terrainPhysicsTicksPerWorldUnit,
                  1 / terrainPhysicsTicksPerWorldUnit,
                ),
              );
            }
            expect(f.world.damageQueue.target, everyElement(f.player));
            expect(
              f.world.damageQueue.length,
              // A target in front misses the sweep's rear-facing middle arc.
              sweep ? 2 : inInclusiveRange(1, 3),
            );
            expect(
              f.world.damageQueue.amount100,
              everyElement(sweep ? 700 : 600),
            );
          });
        }
      }
    }
  }
}
