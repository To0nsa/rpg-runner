import 'package:runner_core/combat/control_lock.dart';
import 'package:runner_core/ecs/systems/active_ability_phase_system.dart';
import 'package:runner_core/ecs/systems/boss_flight_system.dart';
import 'package:runner_core/ecs/systems/control_lock_system.dart';
import 'package:runner_core/ecs/systems/cooldown_system.dart';
import 'package:runner_core/ecs/systems/enemy_death_state_system.dart';
import 'package:runner_core/ecs/systems/enemy_melee_system.dart';
import 'package:runner_core/ecs/systems/gravity_system.dart';
import 'package:runner_core/ecs/systems/world_motion_authority.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/ecs/world_support_view.dart';
import 'package:runner_core/enemies/death_behavior.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/enemies/enemy_terrain_profile.dart';
import 'package:runner_core/players/characters/eloise.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/tuning/physics_tuning.dart';
import 'package:test/test.dart';

import '../test_support/goddess_combat_fixture.dart';
import '../test_support/shoggoth_combat_fixture.dart';

void main() {
  for (final id in [EnemyId.shoggoth, EnemyId.voidbornGoddess]) {
    test('$id uses flight physics without ground navigation', () {
      final f = _FlightHarness(id, 60);
      final profile = const EnemyCatalog().terrainContactProfile(id);
      expect(profile.motionKind, EnemyTerrainMotionKind.flyingDynamic);
      expect(profile.canGround, isFalse);
      expect(profile.traversal.collideCeilings, isTrue);
      expect(f.world.body.useGravity[f.world.body.indexOf(f.boss)], isFalse);
      expect(f.world.surfaceNav.has(f.boss), isFalse);
      expect(f.world.navIntent.has(f.boss), isFalse);
      expect(f.world.bossFlightIntent.has(f.boss), isTrue);
    });
    for (final hz in [30, 60, 90]) {
      for (final side in [-1, 1]) {
        test(
          '$id follows rising/falling targets then hovers in recovery, $side $hz Hz',
          () {
            final f = _FlightHarness(id, hz)..combo(side);
            final ai = f.world.activeAbility.indexOf(f.boss);
            final activeEnd =
                10 +
                f.world.activeAbility.windupTicks[ai] +
                f.world.activeAbility.activeTicks[ai];
            final end = 10 + f.world.activeAbility.totalTicks[ai];
            final start = f.y;
            var rose = false, descended = false;
            double? recoveryY;
            for (var tick = 11; tick < end; tick++) {
              final age = (tick - 10) / hz;
              final height = age < .3
                  ? 80.0
                  : age < .55
                  ? 40.0
                  : 100.0;
              f.placePlayer(f.x + side * f.reach, f.playerY - height);
              final y = f.y;
              f.tick(tick);
              expect((f.y - y).abs(), lessThanOrEqualTo(300 / hz + .01));
              expect(f.world.activeAbility.startTick[ai], 10);
              expect(WorldSupportView(f.world).isGrounded(f.boss), isFalse);
              if (tick < activeEnd) {
                rose |= f.y < y - .1;
                descended |= f.y > y + .1;
              } else {
                recoveryY ??= y;
                expect(f.y, recoveryY);
              }
            }
            expect(rose, isTrue);
            expect(descended, isTrue);
            expect(f.y, lessThan(start - 30));
            expect(recoveryY, isNotNull);
          },
        );
      }

      for (final stop in [
        'cancelled',
        'replaced',
        'move lock',
        'stunned',
        'suspended',
        'dead target',
        'dead boss',
      ]) {
        test('$id stays airborne after $stop at $hz Hz', () {
          final f = _FlightHarness(id, hz)..combo(1);
          for (var tick = 11; tick < 10 + hz ~/ 4; tick++) {
            f.placePlayer(f.x + f.reach, f.playerY - 100);
            f.tick(tick);
          }
          final tick = 10 + hz ~/ 4;
          final y = f.y;
          final x = f.x;
          expect(y, lessThan(f.playerY - 40));
          switch (stop) {
            case 'cancelled':
              f.world.activeAbility.clear(f.boss);
              f.world.cooldown.setTicksLeft(f.boss, 0, hz * 3);
            case 'replaced':
              f.world.activeAbility.abilityId[f.world.activeAbility.indexOf(
                f.boss,
              )] = id == EnemyId.shoggoth
                  ? 'shoggoth.orb'
                  : 'goddess.orb';
            case 'move lock':
              f.world.controlLock.addLock(f.boss, LockFlag.move, hz, tick);
            case 'stunned':
              f.world.controlLock.addLock(f.boss, LockFlag.stun, hz, tick);
            case 'suspended':
              f.world.arenaSuspension.addEntity(f.boss);
            case 'dead target':
              f.world.health.hp[f.world.health.indexOf(f.player)] = 0;
            case 'dead boss':
              f.world.health.hp[f.world.health.indexOf(f.boss)] = 0;
          }
          // Cancellation removes the request; a living boss can intentionally
          // choose a new pursuit later. Here no new decision is admitted.
          for (var t = tick; t < tick + hz ~/ 2; t++) {
            if (stop == 'cancelled') {
              f.flight.step(f.world, currentTick: t);
              f.integrate(t);
            } else {
              f.tick(t);
            }
            expect(f.x, x);
            expect(f.y, y);
          }
        });
      }

      test(
        '$id collides with ceilings without acquiring support at $hz Hz',
        () {
          final f = _FlightHarness(id, hz, ceiling: true)..combo(1);
          var touched = false;
          final end =
              10 +
              f.world.activeAbility.totalTicks[f.world.activeAbility.indexOf(
                f.boss,
              )];
          for (var tick = 11; tick < end; tick++) {
            f.placePlayer(f.x + f.reach, 220);
            f.tick(tick);
            final ci = f.world.colliderAabb.indexOf(f.boss);
            final top =
                f.y +
                f.world.colliderAabb.offsetY[ci] -
                f.world.colliderAabb.halfY[ci];
            expect(top, greaterThanOrEqualTo(320));
            touched |=
                f.world.collision.hitCeiling[f.world.collision.indexOf(f.boss)];
            expect(WorldSupportView(f.world).isGrounded(f.boss), isFalse);
          }
          expect(touched, isTrue);
        },
      );

      test(
        '$id dies in the air and clears flight state on recycling at $hz Hz',
        () {
          final f = _FlightHarness(id, hz);
          f.motion.beginBodyTeleport(f.world, f.boss);
          expect(
            f.motion.tryCommitBodyTeleport(
              f.world,
              f.boss,
              bodyX: 280,
              bodyY: 300,
              facing: Facing.right,
            ),
            isTrue,
          );
          f.world.health.hp[f.world.health.indexOf(f.boss)] = 0;
          EnemyDeathStateSystem(tickHz: hz).step(f.world, currentTick: 10);
          expect(
            f.world.deathState.phase[f.world.deathState.indexOf(f.boss)],
            DeathPhase.deathAnim,
          );
          for (var tick = 10; tick < 10 + hz; tick++) {
            f.flight.step(f.world, currentTick: tick);
            f.integrate(tick);
            expect(f.y, 300);
          }
          final old = f.boss;
          f.world.destroyEntity(old);
          expect(f.world.createEntity(), old);
          expect(f.world.bossFlightIntent.has(old), isFalse);
        },
      );
    }
  }
}

/// Reuses both boss fixtures, with one production flight/gravity/terrain phase.
final class _FlightHarness {
  _FlightHarness(this.id, this.hz, {bool ceiling = false}) {
    if (id == EnemyId.shoggoth) {
      final f = ShoggothCombatFixture(hz: hz, bossX: 280, ceiling: ceiling);
      world = f.world;
      motion = f.motion;
      boss = f.boss;
      player = f.player;
      playerY = f.playerY;
      decide = (tick) => f.decide(tick);
    } else {
      final f = GoddessCombatFixture(
        hz: hz,
        blocked: ceiling ? 'ceiling' : null,
      );
      world = f.world;
      motion = f.motion;
      boss = f.boss;
      player = f.player;
      playerY = f.playerY;
      decide = (tick) {
        CooldownSystem().step(world);
        ControlLockSystem().step(world, currentTick: tick);
        const ActiveAbilityPhaseSystem().step(world, currentTick: tick);
        f.combat.prepareTactics(world, player: player, currentTick: tick);
        f.combat.step(world, player: player, currentTick: tick);
      };
      _preparedTick = 1;
      for (var tick = 1; tick < 10; tick++) {
        integrate(tick);
      }
    }
  }
  final EnemyId id;
  final int hz;
  late final EcsWorld world;
  late final TerrainMultiBodyWorldMotionAuthority motion;
  late final int boss, player;
  late final double playerY;
  late final void Function(int) decide;
  late final flight = BossFlightSystem(tickHz: hz);
  late final movement = MovementTuningDerived.from(
    eloiseCharacter.tuning.movement,
    tickHz: hz,
  );
  double get x => world.transform.posX[world.transform.indexOf(boss)];
  double get y => world.transform.posY[world.transform.indexOf(boss)];
  double get reach => id == EnemyId.shoggoth ? 45 : 35;

  void combo(int side) {
    placePlayer(x + side * reach, playerY);
    expect(
      AiMeleeCommitter(tickHz: hz).commit(
        world,
        actor: boss,
        abilityId: id == EnemyId.shoggoth
            ? 'shoggoth.tentacle_sweep'
            : 'goddess.claw_combo',
        targetX: x + side * reach,
        currentTick: 10,
      ),
      isNotNull,
    );
  }

  void placePlayer(double x, double y) {
    motion.beginBodyTeleport(world, player);
    expect(
      motion.tryCommitBodyTeleport(
        world,
        player,
        bodyX: x,
        bodyY: y,
        facing: Facing.right,
      ),
      isTrue,
    );
  }

  int _preparedTick = -1;
  void prepare(int tick) {
    if (_preparedTick == tick) return;
    motion.prepareTick(world, player: player, currentTick: tick);
    _preparedTick = tick;
  }

  void tick(int tick) {
    prepare(tick);
    decide(tick);
    flight.step(world, currentTick: tick);
    integrate(tick);
  }

  void integrate(int tick) {
    prepare(tick);
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
}
