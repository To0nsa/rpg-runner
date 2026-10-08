import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/combat/control_lock.dart';
import 'package:runner_core/combat/status/status.dart';
import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/stores/combat/damage_resistance_store.dart';
import 'package:runner_core/ecs/stores/combat/status_resistance_store.dart';
import 'package:runner_core/ecs/stores/health_store.dart';
import 'package:runner_core/ecs/stores/mana_store.dart';
import 'package:runner_core/ecs/systems/damage_system.dart';
import 'package:runner_core/ecs/systems/status_system.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:test/test.dart';

const _halfStrength = StatusResistanceDef(
  defaultDebuff: StatusEffectResistance(magnitudeScaleBp: 5000),
);

void main() {
  for (final hz in [30, 60, 90]) {
    for (final id in EnemyId.values.where((id) => id.isBoss)) {
      test('$id resists debuffs and ignores controls at $hz Hz', () {
        final world = EcsWorld();
        final a = const EnemyCatalog().get(id);
        final boss = EntityFactory(world).createEnemy(
          enemyId: id,
          posX: 0,
          posY: 0,
          velX: 0,
          velY: 0,
          facing: Facing.left,
          body: a.body,
          collider: a.collider,
          health: a.health,
          mana: a.mana,
          stamina: a.stamina,
          statusImmunity: a.statusImmunity,
          statusResistance: a.statusResistance,
        );
        world.activeAbility.set(
          boss,
          id: 'test.cast',
          slot: AbilitySlot.projectile,
          commitTick: 0,
          windupTicks: hz,
          activeTicks: 1,
          recoveryTicks: 1,
          facingDir: Facing.left,
        );
        final status = StatusSystem(tickHz: hz);
        for (final profile in [
          StatusProfileId.stunOnHit,
          StatusProfileId.silenceOnHit,
          StatusProfileId.slowOnHit,
          StatusProfileId.weakenOnHit,
          StatusProfileId.acidOnHit,
          StatusProfileId.drenchOnHit,
          StatusProfileId.burnOnHit,
          StatusProfileId.meleeBleed,
        ]) {
          status.queue(StatusRequest(target: boss, profileId: profile));
        }
        status.applyQueued(world, currentTick: 1);
        expect(
          world.controlLock.isLocked(boss, LockFlag.allActions, 1),
          isFalse,
        );
        expect(world.activeAbility.abilityId.single, 'test.cast');
        expect(world.slow.magnitude.single, 1250);
        expect(world.weaken.magnitude.single, 2500);
        expect(world.vulnerable.magnitude.single, 2500);
        expect(world.drench.magnitude.single, 2500);
        expect(world.dot.dps100.single, [150, 150]);
        expect(world.slow.ticksLeft.single, 5 * hz);
        expect(world.weaken.ticksLeft.single, 5 * hz);
        expect(world.vulnerable.ticksLeft.single, 5 * hz);
        expect(world.drench.ticksLeft.single, 5 * hz);
        expect(world.dot.ticksLeft.single, [5 * hz, 5 * hz]);
      });
    }

    test('source tuning, typed amplification, then resistance at $hz Hz', () {
      final f = _Fixture(hz);
      f.world.statusResistance.add(
        f.target,
        const StatusResistanceDef(
          defaultDebuff: StatusEffectResistance(magnitudeScaleBp: 5000),
          slow: StatusEffectResistance(
            magnitudeScaleBp: 2500,
            durationScaleBp: 5000,
          ),
        ),
      );
      f.world.damageResistance.add(
        f.target,
        const DamageResistanceDef(physicalBp: 5000),
      );
      f.apply(
        StatusProfileId.poisonOnHit,
        tuning: const StatusProfileTuning(
          dot: StatusApplicationTuning(magnitude: 600),
          slow: StatusApplicationTuning(magnitude: 3333, durationSeconds: 2.25),
        ),
      );
      expect(f.world.dot.dps100.single.single, 450);
      expect(f.world.dot.ticksLeft.single.single, 5 * hz);
      // Round down after each fixed-point operation; duration rounds up once.
      expect(f.world.slow.magnitude.single, 1249);
      expect(f.world.slow.ticksLeft.single, (1.125 * hz).ceil());
    });

    test('DoT keeps cadence, scales once and mitigates pulses at $hz Hz', () {
      final f = _Fixture(hz, resistance: _halfStrength);
      f.world.damageResistance.add(
        f.target,
        const DamageResistanceDef(fireBp: -5000),
      );
      f.apply(StatusProfileId.burnOnHit);
      final damage = DamageSystem(invulnerabilityTicksOnHit: 0, rngSeed: 1);
      var rawDamage = 0;
      final pulses = <int>[];
      for (var tick = 1; tick <= 5 * hz; tick++) {
        f.status.tickExisting(f.world);
        if (f.world.damageQueue.length > 0) {
          pulses.add(tick);
          rawDamage += f.world.damageQueue.amount100.single;
        }
        damage.step(f.world, currentTick: tick);
      }
      expect(pulses, [hz, 2 * hz, 3 * hz, 4 * hz, 5 * hz]);
      expect(rawDamage, 750);
      expect(f.world.health.hp.single, 5000 - 375);
      expect(f.world.dot.has(f.target), isFalse);
    });

    test('refresh retains reduced strength without stacking at $hz Hz', () {
      final f = _Fixture(hz, resistance: _halfStrength);
      f.apply(StatusProfileId.weakenOnHit);
      for (var tick = 0; tick < hz; tick++) {
        f.status.tickExisting(f.world);
      }
      f.apply(StatusProfileId.weakenOnHit);
      expect(f.world.weaken.magnitude.single, 2500);
      expect(f.world.weaken.ticksLeft.single, 5 * hz);
      f.apply(
        StatusProfileId.weakenOnHit,
        tuning: const StatusProfileTuning(
          weaken: StatusApplicationTuning(magnitude: 2000, durationSeconds: 10),
        ),
      );
      expect(f.world.weaken.magnitude.single, 2500);
      expect(f.world.weaken.ticksLeft.single, 5 * hz);
    });

    test('time-only controls scale duration, not magnitude at $hz Hz', () {
      for (final (profile, flag, seconds) in [
        (StatusProfileId.stunOnHit, LockFlag.stun, 1),
        (StatusProfileId.silenceOnHit, LockFlag.cast, 5),
      ]) {
        final f = _Fixture(
          hz,
          resistance: const StatusResistanceDef(
            defaultDebuff: StatusEffectResistance(
              magnitudeScaleBp: 0,
              durationScaleBp: 2500,
            ),
          ),
        );
        f.apply(profile);
        final ticks = (seconds * .25 * hz).ceil();
        expect(f.world.controlLock.isLocked(f.target, flag, ticks), isTrue);
        expect(
          f.world.controlLock.isLocked(f.target, flag, ticks + 1),
          isFalse,
        );
      }
    });
  }

  test('beneficial statuses ignore even complete debuff resistance', () {
    final f = _Fixture(
      60,
      resistance: const StatusResistanceDef(
        defaultDebuff: StatusEffectResistance(
          magnitudeScaleBp: 0,
          durationScaleBp: 0,
        ),
      ),
    );
    for (final profile in [
      StatusProfileId.speedBoost,
      StatusProfileId.arcaneWard,
      StatusProfileId.focus,
      StatusProfileId.restoreMana,
    ]) {
      f.apply(profile);
    }
    expect(f.world.haste.magnitude.single, 5000);
    expect(f.world.damageReduction.magnitude.single, 4000);
    expect(f.world.offenseBuff.powerBonusBp.single, 2500);
    expect(f.world.offenseBuff.critBonusBp.single, 1500);
    expect(f.world.haste.ticksLeft.single, 300);
    expect(f.world.damageReduction.ticksLeft.single, 300);
    expect(f.world.offenseBuff.ticksLeft.single, 300);
    expect(f.world.resourceOverTime.ticksLeft.single.single, 300);
    for (var i = 0; i < 300; i++) {
      f.status.tickExisting(f.world);
    }
    expect(f.world.mana.mana.single, 5500);
  });

  test('zero remaining magnitude or duration prevents harmful effects', () {
    for (final multiplier in [
      const StatusEffectResistance(magnitudeScaleBp: 0),
      const StatusEffectResistance(durationScaleBp: 0),
    ]) {
      final f = _Fixture(
        60,
        resistance: StatusResistanceDef(defaultDebuff: multiplier),
      );
      f.apply(StatusProfileId.poisonOnHit);
      f.apply(StatusProfileId.weakenOnHit);
      expect(f.world.dot.has(f.target), isFalse);
      expect(f.world.slow.has(f.target), isFalse);
      expect(f.world.weaken.has(f.target), isFalse);
      if (multiplier.durationScaleBp == 0) {
        f.apply(StatusProfileId.silenceOnHit);
        f.apply(StatusProfileId.stunOnHit);
        expect(f.world.controlLock.has(f.target), isFalse);
      }
    }
  });

  test('missing resistance and ordinary catalog defaults stay neutral', () {
    final f = _Fixture(60);
    f.apply(StatusProfileId.weakenOnHit);
    expect(f.world.weaken.magnitude.single, 5000);
    expect(f.world.weaken.ticksLeft.single, 300);
    for (final id in EnemyId.values.where((id) => !id.isBoss)) {
      final def = const EnemyCatalog().get(id).statusResistance;
      for (final type in StatusEffectType.values) {
        expect(def.forType(type).magnitudeScaleBp, 10000);
        expect(def.forType(type).durationScaleBp, 10000);
      }
    }
  });

  test('per-effect override replaces both default multipliers', () {
    final f = _Fixture(
      60,
      resistance: const StatusResistanceDef(
        defaultDebuff: StatusEffectResistance(
          magnitudeScaleBp: 5000,
          durationScaleBp: 5000,
        ),
        weaken: StatusEffectResistance(durationScaleBp: 2500),
      ),
    );
    f.apply(StatusProfileId.weakenOnHit);
    expect(f.world.weaken.magnitude.single, 5000);
    expect(f.world.weaken.ticksLeft.single, 75);
  });

  test('resistance changes only affect new applications', () {
    final f = _Fixture(60, resistance: _halfStrength);
    f.apply(StatusProfileId.weakenOnHit);
    f.world.statusResistance.add(f.target, const StatusResistanceDef());
    f.status.tickExisting(f.world);
    expect(f.world.weaken.magnitude.single, 2500);
    f.apply(StatusProfileId.weakenOnHit);
    expect(f.world.weaken.magnitude.single, 5000);
  });

  test(
    'swap removal preserves the survivor; recycled IDs have no resistance',
    () {
      final world = EcsWorld();
      final first = world.createEntity(), survivor = world.createEntity();
      world.statusResistance.add(first, const StatusResistanceDef());
      world.statusResistance.add(survivor, _halfStrength);
      world.destroyEntity(first);
      expect(world.statusResistance.forEntity(survivor), same(_halfStrength));
      world.destroyEntity(survivor);
      final recycled = world.createEntity();
      expect(recycled, survivor);
      expect(world.statusResistance.has(recycled), isFalse);
      expect(
        world.statusResistance
            .forEntity(recycled)
            .defaultDebuff
            .magnitudeScaleBp,
        10000,
      );
    },
  );
}

class _Fixture {
  _Fixture(int hz, {StatusResistanceDef? resistance})
    : status = StatusSystem(tickHz: hz) {
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
    if (resistance != null) world.statusResistance.add(target, resistance);
  }
  final world = EcsWorld();
  final StatusSystem status;
  late final int target;

  void apply(
    StatusProfileId profile, {
    StatusProfileTuning tuning = const StatusProfileTuning(),
  }) {
    status.queue(
      StatusRequest(target: target, profileId: profile, tuning: tuning),
    );
    status.applyQueued(world, currentTick: 1);
  }
}
