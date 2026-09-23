import 'package:runner_core/combat/damage.dart';
import 'package:runner_core/combat/damage_type.dart';
import 'package:runner_core/combat/middleware/ward_middleware.dart';
import 'package:runner_core/combat/status/status.dart';
import 'package:runner_core/ecs/stores/combat/damage_resistance_store.dart';
import 'package:runner_core/ecs/stores/combat/status_immunity_store.dart';
import 'package:runner_core/ecs/stores/health_store.dart';
import 'package:runner_core/ecs/stores/status/dot_store.dart';
import 'package:runner_core/ecs/systems/damage_middleware_system.dart';
import 'package:runner_core/ecs/systems/damage_system.dart';
import 'package:runner_core/ecs/systems/status_system.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/traps/trap_id.dart';
import 'package:runner_core/traps/trap_placement.dart';
import 'package:runner_core/weapons/weapon_proc.dart';
import 'package:test/test.dart';

const first = TrapSourceRef(
  trapId: TrapId.poisonDarts,
  chunkKey: 'a',
  chunkIndex: 1,
  placementOrdinal: 0,
);
const second = TrapSourceRef(
  trapId: TrapId.poisonDarts,
  chunkKey: 'b',
  chunkIndex: 2,
  placementOrdinal: 0,
);

void main() {
  for (final resistance in [0, -5000, -10000]) {
    test(
      'accepted dart applies Poison and Slow with Acid modifier $resistance',
      () {
        final f = _Fixture();
        f.world.damageResistance.add(
          f.target,
          DamageResistanceDef(acidBp: resistance),
        );
        f.hit();
        expect(f.world.dot.dps100.single.single, 200);
        expect(f.world.slow.magnitude.single, 2500);
        expect(f.world.invulnerability.ticksLeft.single, 15);
        expect(f.world.vulnerable.has(f.target), isFalse);
        final pulses = <int>[];
        for (var t = 1; t <= 360; t++) {
          f.tick(
            t,
            beforeDamage: () {
              if (f.world.damageQueue.length > 0) {
                pulses.add(t);
                expect(f.world.damageQueue.sourceTrap.single, first);
              }
            },
          );
        }
        expect(pulses, [60, 120, 180, 240, 300]);
        expect(f.hp, 5000 - (1100 * (10000 + resistance) ~/ 10000));
        expect(f.world.dot.has(f.target), isFalse);
        expect(f.world.slow.has(f.target), isFalse);
      },
    );
  }

  test(
    'blocked dart and independent status immunities remain authoritative',
    () {
      final blocked = _Fixture();
      blocked.world.invulnerability.ticksLeft[0] = 1;
      blocked.hit();
      expect(blocked.world.dot.has(blocked.target), isFalse);
      expect(blocked.world.slow.has(blocked.target), isFalse);
      final immune = _Fixture();
      immune.world.statusImmunity.add(
        immune.target,
        const StatusImmunityDef(mask: StatusImmunityMask.dot),
      );
      immune.hit();
      expect(immune.world.dot.has(immune.target), isFalse);
      expect(immune.world.slow.has(immune.target), isTrue);
    },
  );

  test(
    'equal refresh retains pulse phase and changes source only on extension',
    () {
      final f = _Fixture();
      f.applyPoison(first, 0);
      f.applyPoison(second, 0);
      expect(f.world.dot.sourceTrap.single.single, first);
      for (var t = 1; t <= 30; t++) {
        f.tick(t);
      }
      f.applyPoison(second, 30);
      expect(f.world.dot.sourceTrap.single.single, second);
      expect(f.world.dot.periodTicksLeft.single.single, 30);
      final pulses = <int>[];
      for (var t = 31; t <= 360; t++) {
        f.tick(
          t,
          beforeDamage: () {
            if (f.world.damageQueue.length > 0) {
              pulses.add(t);
              expect(f.world.damageQueue.sourceTrap.single, second);
            }
          },
        );
      }
      expect(pulses, [60, 120, 180, 240, 300]);
      expect(f.world.dot.has(f.target), isFalse);
    },
  );

  test(
    'weaker application preserves source; stronger replaces source and phase',
    () {
      final f = _Fixture();
      f.world.dot.add(
        f.target,
        const DotDef(
          damageType: DamageType.poison,
          ticksLeft: 100,
          periodTicks: 60,
          dps100: 300,
          sourceTrap: first,
        ),
      );
      f.applyPoison(second, 0);
      expect(f.world.dot.sourceTrap.single.single, first);
      expect(f.world.dot.ticksLeft.single.single, 100);
      f.world.dot.dps100[0][0] = 100;
      f.world.dot.periodTicksLeft[0][0] = 10;
      f.applyPoison(second, 1);
      expect(f.world.dot.sourceTrap.single.single, second);
      expect(f.world.dot.periodTicksLeft.single.single, 60);
      expect(f.world.dot.ticksLeft.single.single, 300);
    },
  );

  test(
    'Fire and Poison use independent channels; generic DoTs have no trap',
    () {
      final f = _Fixture();
      f.applyPoison(first, 0);
      f.status.queue(
        StatusRequest(target: f.target, profileId: StatusProfileId.burnOnHit),
      );
      f.status.applyQueued(f.world, currentTick: 0);
      for (var t = 1; t < 60; t++) {
        f.tick(t);
      }
      f.status.tickExisting(f.world);
      expect(f.world.damageQueue.damageType.toSet(), {
        DamageType.poison,
        DamageType.fire,
      });
      final poisonIndex = f.world.damageQueue.damageType.indexOf(
        DamageType.poison,
      );
      final fireIndex = f.world.damageQueue.damageType.indexOf(DamageType.fire);
      expect(f.world.damageQueue.sourceTrap[poisonIndex], first);
      expect(f.world.damageQueue.sourceTrap[fireIndex], isNull);
    },
  );

  test('ward cancels pulses while cleanse removes both Poison and Slow', () {
    final f = _Fixture();
    f.applyPoison(first, 0);
    f.status.queue(
      StatusRequest(target: f.target, profileId: StatusProfileId.arcaneWard),
    );
    f.status.applyQueued(f.world, currentTick: 0);
    for (var t = 1; t <= 60; t++) {
      f.tick(t);
    }
    expect(f.hp, 5000);
    expect(f.world.dot.has(f.target), isTrue);
    f.status.queuePurge(
      PurgeRequest(target: f.target, profileId: PurgeProfileId.cleanse),
    );
    f.tick(61);
    expect(f.world.dot.has(f.target), isFalse);
    expect(f.world.slow.has(f.target), isFalse);
  });

  test(
    'lethal pulse retains immutable source; later generic damage clears it',
    () {
      final f = _Fixture();
      f.applyPoison(second, 0);
      f.world.health.hp[0] = 100;
      for (var t = 1; t <= 60; t++) {
        f.tick(t);
      }
      expect(f.hp, 0);
      expect(f.world.lastDamage.kind.single, DeathSourceKind.statusEffect);
      expect(f.world.lastDamage.sourceTrap.single, second);
      f.world.health.hp[0] = 1000;
      f.world.invulnerability.ticksLeft[0] = 0;
      f.world.damageQueue.add(DamageRequest(target: f.target, amount100: 1));
      f.damage.step(f.world, currentTick: 61);
      expect(f.world.lastDamage.sourceTrap.single, isNull);
    },
  );
}

class _Fixture {
  _Fixture() {
    target = world.createEntity();
    world.health.add(
      target,
      const HealthDef(hp: 5000, hpMax: 5000, regenPerSecond100: 0),
    );
    world.statModifier.add(target);
    world.invulnerability.add(target);
    world.lastDamage.add(target);
  }
  final world = EcsWorld();
  final status = StatusSystem(tickHz: 60);
  final damage = DamageSystem(invulnerabilityTicksOnHit: 15, rngSeed: 1);
  final middleware = DamageMiddlewareSystem(
    middlewares: [const WardMiddleware()],
  );
  late final int target;
  int get hp => world.health.hp[world.health.indexOf(target)];
  void hit() {
    world.damageQueue.add(
      DamageRequest(
        target: target,
        amount100: 100,
        damageType: DamageType.poison,
        sourceKind: DeathSourceKind.projectile,
        sourceTrap: first,
        procs: const [
          WeaponProc(
            hook: ProcHook.onHit,
            statusProfileId: StatusProfileId.poisonOnHit,
          ),
        ],
      ),
    );
    damage.step(world, currentTick: 0, queueStatus: status.queue);
    status.applyQueued(world, currentTick: 0);
  }

  void applyPoison(TrapSourceRef source, int tick) {
    status.queue(
      StatusRequest(
        target: target,
        profileId: StatusProfileId.poisonOnHit,
        damageType: DamageType.poison,
        sourceTrap: source,
      ),
    );
    status.applyQueued(world, currentTick: tick);
  }

  void tick(int tick, {void Function()? beforeDamage}) {
    final invuln = world.invulnerability;
    if (invuln.ticksLeft[0] > 0) invuln.ticksLeft[0]--;
    status.tickExisting(world);
    beforeDamage?.call();
    middleware.step(world, currentTick: tick);
    damage.step(world, currentTick: tick, queueStatus: status.queue);
    status.applyQueued(world, currentTick: tick);
  }
}
