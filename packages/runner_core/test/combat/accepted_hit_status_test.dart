import 'package:runner_core/combat/damage.dart';
import 'package:runner_core/combat/damage_type.dart';
import 'package:runner_core/combat/status/status.dart';
import 'package:runner_core/ecs/stores/combat/damage_resistance_store.dart';
import 'package:runner_core/ecs/stores/combat/status_immunity_store.dart';
import 'package:runner_core/ecs/stores/health_store.dart';
import 'package:runner_core/ecs/systems/damage_system.dart';
import 'package:runner_core/ecs/systems/status_system.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/weapons/weapon_proc.dart';
import 'package:test/test.dart';

void main() {
  for (final hook in [ProcHook.onHit, ProcHook.onCrit]) {
    test(
      '$hook retains eligibility without allowing later same-tick damage',
      () {
        final f = _Fixture();
        f.hit(hook: hook);
        f.world.damageQueue.add(
          DamageRequest(target: f.target, amount100: 1000),
        );
        f.apply();
        expect(f.world.slow.has(f.target), isTrue);
        expect(f.world.dot.has(f.target), isTrue);
        expect(f.hp, hook == ProcHook.onCrit ? 4850 : 4900);
        expect(f.world.invulnerability.ticksLeft.single, 15);
      },
    );
  }

  test('pre-existing invulnerability and canceled hits produce no status', () {
    for (final canceled in [false, true]) {
      final f = _Fixture();
      if (!canceled) f.world.invulnerability.ticksLeft[0] = 1;
      f.hit();
      if (canceled) f.world.damageQueue.cancel(0);
      f.apply();
      expect(f.hp, 5000);
      expect(f.world.slow.has(f.target), isFalse);
      expect(f.world.dot.has(f.target), isFalse);
    }
  });

  test(
    'accepted hit still obeys status immunity and accepts full resistance',
    () {
      final f = _Fixture();
      f.world.damageResistance.add(
        f.target,
        const DamageResistanceDef(fireBp: -10000),
      );
      f.world.statusImmunity.add(
        f.target,
        const StatusImmunityDef(mask: StatusImmunityMask.slow),
      );
      f.hit();
      f.apply();
      expect(f.hp, 5000);
      expect(f.world.slow.has(f.target), isFalse);
      expect(f.world.dot.has(f.target), isTrue);
    },
  );

  test(
    'standalone and delayed accepted-hit effects respect invulnerability',
    () {
      final f = _Fixture();
      f.world.invulnerability.ticksLeft[0] = 15;
      f.status.queue(
        StatusRequest(target: f.target, profileId: StatusProfileId.slowOnHit),
      );
      f.status.queue(
        StatusRequest(
          target: f.target,
          profileId: StatusProfileId.burnOnHit,
          acceptedHitTick: 0,
        ),
      );
      f.apply();
      expect(f.world.slow.has(f.target), isFalse);
      expect(f.world.dot.has(f.target), isFalse);
    },
  );

  test('lethal damage cannot apply status or accept another queued hit', () {
    final f = _Fixture();
    f.world.health.hp[0] = 50;
    f.hit();
    f.apply();
    expect(f.hp, 0);
    expect(f.world.slow.has(f.target), isFalse);
    expect(f.world.dot.has(f.target), isFalse);
  });

  test(
    'Fire pulses at each whole second including expiry, with no extra pulse',
    () {
      final f = _Fixture();
      f.status.queue(
        StatusRequest(target: f.target, profileId: StatusProfileId.burnOnHit),
      );
      f.status.applyQueued(f.world, currentTick: 0);
      final pulseTicks = <int>[];
      var total100 = 0;
      for (var tick = 1; tick <= 360; tick++) {
        f.status.tickExisting(f.world);
        if (f.world.damageQueue.length > 0) {
          pulseTicks.add(tick);
          total100 += f.world.damageQueue.amount100.single;
          f.world.damageQueue.clear();
        }
      }
      expect(pulseTicks, [60, 120, 180, 240, 300]);
      expect(total100, 1500);
      expect(f.world.dot.has(f.target), isFalse);
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
    world.invulnerability.add(target);
    world.statModifier.add(target);
  }
  final world = EcsWorld();
  final damage = DamageSystem(invulnerabilityTicksOnHit: 15, rngSeed: 1);
  final status = StatusSystem(tickHz: 60);
  late final int target;
  int get hp => world.health.hp[world.health.indexOf(target)];

  void hit({ProcHook hook = ProcHook.onHit}) => world.damageQueue.add(
    DamageRequest(
      target: target,
      amount100: 100,
      critChanceBp: hook == ProcHook.onCrit ? 10000 : 0,
      damageType: DamageType.fire,
      procs: [
        WeaponProc(hook: hook, statusProfileId: StatusProfileId.burnOnHit),
        WeaponProc(hook: hook, statusProfileId: StatusProfileId.slowOnHit),
      ],
    ),
  );

  void apply() {
    damage.step(world, currentTick: 1, queueStatus: status.queue);
    status.applyQueued(world, currentTick: 1);
  }
}
