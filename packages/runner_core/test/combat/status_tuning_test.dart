import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/combat/control_lock.dart';
import 'package:runner_core/combat/damage.dart';
import 'package:runner_core/combat/damage_type.dart';
import 'package:runner_core/combat/hit_payload_builder.dart';
import 'package:runner_core/combat/status/status.dart';
import 'package:runner_core/ecs/stores/health_store.dart';
import 'package:runner_core/ecs/stores/combat/damage_resistance_store.dart';
import 'package:runner_core/ecs/stores/mana_store.dart';
import 'package:runner_core/ecs/stores/self_intent_store.dart';
import 'package:runner_core/ecs/systems/damage_system.dart';
import 'package:runner_core/ecs/systems/status_system.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/weapons/weapon_proc.dart';
import 'package:test/test.dart';

const _values = StatusApplicationTuning(magnitude: 1250, durationSeconds: 2.25);
const _cases = [
  (
    StatusProfileId.burnOnHit,
    StatusEffectType.dot,
    StatusProfileTuning(dot: _values),
  ),
  (
    StatusProfileId.slowOnHit,
    StatusEffectType.slow,
    StatusProfileTuning(slow: _values),
  ),
  (
    StatusProfileId.stunOnHit,
    StatusEffectType.stun,
    StatusProfileTuning(stun: _values),
  ),
  (
    StatusProfileId.speedBoost,
    StatusEffectType.haste,
    StatusProfileTuning(haste: _values),
  ),
  (
    StatusProfileId.arcaneWard,
    StatusEffectType.damageReduction,
    StatusProfileTuning(damageReduction: _values),
  ),
  (
    StatusProfileId.acidOnHit,
    StatusEffectType.vulnerable,
    StatusProfileTuning(vulnerable: _values),
  ),
  (
    StatusProfileId.weakenOnHit,
    StatusEffectType.weaken,
    StatusProfileTuning(weaken: _values),
  ),
  (
    StatusProfileId.drenchOnHit,
    StatusEffectType.drench,
    StatusProfileTuning(drench: _values),
  ),
  (
    StatusProfileId.silenceOnHit,
    StatusEffectType.silence,
    StatusProfileTuning(silence: _values),
  ),
  (
    StatusProfileId.restoreMana,
    StatusEffectType.resourceOverTime,
    StatusProfileTuning(resourceOverTime: _values),
  ),
  (
    StatusProfileId.focus,
    StatusEffectType.offenseBuff,
    StatusProfileTuning(offenseBuff: _values),
  ),
];

void main() {
  test('tuning matrix covers every status effect type', () {
    expect(_cases.map((c) => c.$2).toSet(), StatusEffectType.values.toSet());
  });
  for (final hz in [30, 60, 90]) {
    for (final (profile, type, tuning) in _cases) {
      test('$type uses local strength and duration at $hz Hz', () {
        final f = _Fixture(hz);
        f.apply(profile, tuning);
        final world = f.world;
        final ticks = (2.25 * hz).ceil();
        switch (type) {
          case StatusEffectType.dot:
            expect(world.dot.dps100.single.single, 1250);
            expect(world.dot.ticksLeft.single.single, ticks);
          case StatusEffectType.slow:
            expect(world.slow.magnitude.single, 1250);
            expect(world.slow.ticksLeft.single, ticks);
          case StatusEffectType.stun:
            expect(
              world.controlLock.isLocked(f.target, LockFlag.stun, ticks),
              isTrue,
            );
            expect(
              world.controlLock.isLocked(f.target, LockFlag.stun, ticks + 1),
              isFalse,
            );
          case StatusEffectType.haste:
            expect(world.haste.magnitude.single, 1250);
            expect(world.haste.ticksLeft.single, ticks);
          case StatusEffectType.damageReduction:
            expect(world.damageReduction.magnitude.single, 1250);
            expect(world.damageReduction.ticksLeft.single, ticks);
          case StatusEffectType.vulnerable:
            expect(world.vulnerable.magnitude.single, 1250);
            expect(world.vulnerable.ticksLeft.single, ticks);
          case StatusEffectType.weaken:
            expect(world.weaken.magnitude.single, 1250);
            expect(world.weaken.ticksLeft.single, ticks);
          case StatusEffectType.drench:
            expect(world.drench.magnitude.single, 1250);
            expect(world.drench.ticksLeft.single, ticks);
          case StatusEffectType.silence:
            expect(
              world.controlLock.isLocked(f.target, LockFlag.cast, ticks),
              isTrue,
            );
            expect(
              world.controlLock.isLocked(f.target, LockFlag.cast, ticks + 1),
              isFalse,
            );
          case StatusEffectType.resourceOverTime:
            expect(world.resourceOverTime.ticksLeft.single.single, ticks);
            for (var t = 0; t < ticks; t++) {
              f.status.tickExisting(world);
            }
            expect(world.mana.mana.single, 3250);
          case StatusEffectType.offenseBuff:
            expect(world.offenseBuff.powerBonusBp.single, 1250);
            expect(world.offenseBuff.critBonusBp.single, 1500);
            expect(world.offenseBuff.ticksLeft.single, ticks);
        }
      });
    }

    test(
      'compound poison tunes DoT cadence independently of slow at $hz Hz',
      () {
        final f = _Fixture(hz);
        f.apply(
          StatusProfileId.poisonOnHit,
          const StatusProfileTuning(
            dot: StatusApplicationTuning(
              magnitude: 600,
              durationSeconds: 2,
              periodSeconds: .5,
              dotDamageType: DamageType.dark,
            ),
            slow: StatusApplicationTuning(magnitude: 2000, durationSeconds: 3),
          ),
        );
        expect(f.world.dot.damageTypes.single.single, DamageType.dark);
        expect(f.world.slow.magnitude.single, 2000);
        expect(f.world.slow.ticksLeft.single, 3 * hz);
        final pulses = <int>[];
        for (var tick = 1; tick <= 2 * hz; tick++) {
          f.status.tickExisting(f.world);
          if (f.world.damageQueue.length > 0) {
            pulses.add(tick);
            expect(f.world.damageQueue.amount100.single, 300);
            f.world.damageQueue.clear();
          }
        }
        expect(pulses, [hz ~/ 2, hz, hz * 3 ~/ 2, 2 * hz]);
        expect(f.world.dot.has(f.target), isFalse);
        expect(f.world.slow.ticksLeft.single, hz);
      },
    );
  }

  test('resource type and immediate application can be tuned locally', () {
    final f = _Fixture(60);
    f.apply(
      StatusProfileId.restoreMana,
      const StatusProfileTuning(
        resourceOverTime: StatusApplicationTuning(
          magnitude: 1000,
          durationSeconds: 0,
          resourceType: StatusResourceType.health,
          applyOnApply: true,
        ),
      ),
    );
    expect(f.world.health.hp.single, 6000);
    expect(f.world.mana.mana.single, 2000);
    expect(f.world.resourceOverTime.has(f.target), isFalse);
  });

  test(
    'false scaling override preserves authored strength on a vulnerable target',
    () {
      for (final scale in [false, true]) {
        final f = _Fixture(60);
        f.world.damageResistance.add(
          f.target,
          const DamageResistanceDef(physicalBp: 10000),
        );
        f.apply(
          StatusProfileId.slowOnHit,
          StatusProfileTuning(
            slow: StatusApplicationTuning(
              magnitude: 1250,
              scaleByDamageType: scale,
            ),
          ),
        );
        expect(f.world.slow.magnitude.single, scale ? 2500 : 1250);
      }
    },
  );

  test('zero crit bonus replaces the shared focus bonus', () {
    final f = _Fixture(60);
    f.apply(
      StatusProfileId.focus,
      const StatusProfileTuning(
        offenseBuff: StatusApplicationTuning(critBonusBp: 0),
      ),
    );
    expect(f.world.offenseBuff.critBonusBp.single, 0);
    expect(f.world.offenseBuff.powerBonusBp.single, 2500);
  });

  test('ability proc tuning takes precedence over duplicate item proc', () {
    final f = _Fixture(60);
    final payload = HitPayloadBuilder.build(
      ability: AbilityDef(
        id: 'test.weaken',
        category: AbilityCategory.ranged,
        windupTicks: 0,
        activeTicks: 1,
        recoveryTicks: 0,
        cooldownTicks: 1,
        animKey: AnimKey.cast,
        baseDamage: 100,
        procs: const [
          WeaponProc(
            hook: ProcHook.onHit,
            statusProfileId: StatusProfileId.weakenOnHit,
            statusTuning: StatusProfileTuning(weaken: _values),
          ),
        ],
      ),
      source: f.world.createEntity(),
      weaponProcs: const [
        WeaponProc(
          hook: ProcHook.onHit,
          statusProfileId: StatusProfileId.weakenOnHit,
        ),
      ],
    );
    expect(payload.procs, hasLength(1));
    f.world.invulnerability.add(f.target);
    f.world.damageQueue.add(
      DamageRequest(
        target: f.target,
        amount100: payload.damage100,
        procs: payload.procs,
      ),
    );
    DamageSystem(
      invulnerabilityTicksOnHit: 15,
      rngSeed: 1,
    ).step(f.world, currentTick: 1, queueStatus: f.status.queue);
    f.status.applyQueued(f.world, currentTick: 1);
    expect(f.world.weaken.magnitude.single, 1250);
    expect(f.world.weaken.ticksLeft.single, 135);
    final defaults = const StatusProfileCatalog().get(
      StatusProfileId.weakenOnHit,
    );
    expect(defaults.applications.single.magnitude, 5000);
    expect(defaults.applications.single.durationSeconds, 5);
  });

  test('unknown effect tuning is rejected instead of silently ignored', () {
    expect(
      () => const StatusProfileCatalog().resolve(
        StatusProfileId.weakenOnHit,
        tuning: const StatusProfileTuning(slow: _values),
      ),
      throwsArgumentError,
    );
  });

  test('invalid local timing fails at authoring', () {
    expect(
      () => StatusApplicationTuning(durationSeconds: -1),
      throwsA(isA<AssertionError>()),
    );
    expect(
      () => StatusApplicationTuning(periodSeconds: 0),
      throwsA(isA<AssertionError>()),
    );
    expect(
      () => StatusApplicationTuning(durationSeconds: double.infinity),
      throwsA(isA<AssertionError>()),
    );
  });

  test(
    'self intent tuning survives swap removal and resets on entity reuse',
    () {
      final world = EcsWorld();
      final first = world.createEntity(), survivor = world.createEntity();
      world.selfIntent.add(first);
      world.selfIntent.add(survivor);
      world.selfIntent.set(
        survivor,
        const SelfIntentDef(
          abilityId: 'test.haste',
          slot: AbilitySlot.spell,
          selfStatusProfileId: StatusProfileId.speedBoost,
          selfStatusTuning: StatusProfileTuning(haste: _values),
          commitTick: 1,
          windupTicks: 0,
          activeTicks: 0,
          recoveryTicks: 0,
          cooldownTicks: 0,
          cooldownGroupId: 0,
          staminaCost100: 0,
          manaCost100: 0,
          tick: 1,
        ),
      );
      world.destroyEntity(first);
      expect(world.selfIntent.selfStatusTuning.single.haste, same(_values));
      world.destroyEntity(survivor);
      final recycled = world.createEntity();
      world.selfIntent.add(recycled);
      expect(world.selfIntent.selfStatusTuning.single.isEmpty, isTrue);
    },
  );
}

class _Fixture {
  _Fixture(int hz) : status = StatusSystem(tickHz: hz) {
    target = world.createEntity();
    world.health.add(
      target,
      const HealthDef(hp: 5000, hpMax: 10000, regenPerSecond100: 0),
    );
    world.mana.add(
      target,
      const ManaDef(mana: 2000, manaMax: 10000, regenPerSecond100: 0),
    );
    world.statModifier.add(target);
  }
  final world = EcsWorld();
  final StatusSystem status;
  late final int target;

  void apply(StatusProfileId profile, StatusProfileTuning tuning) {
    status.queue(
      StatusRequest(target: target, profileId: profile, tuning: tuning),
    );
    status.applyQueued(world, currentTick: 1);
  }
}
