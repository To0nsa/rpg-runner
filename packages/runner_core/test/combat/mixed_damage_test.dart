import 'package:runner_core/abilities/ability_catalog.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/combat/combat_combo.dart';
import 'package:runner_core/combat/damage.dart';
import 'package:runner_core/combat/damage_type.dart';
import 'package:runner_core/combat/hit_payload_builder.dart';
import 'package:runner_core/combat/middleware/ward_middleware.dart';
import 'package:runner_core/combat/middleware/parry_middleware.dart';
import 'package:runner_core/combat/status/status.dart';
import 'package:runner_core/ecs/stores/combat/damage_resistance_store.dart';
import 'package:runner_core/ecs/stores/health_store.dart';
import 'package:runner_core/ecs/stores/status/damage_reduction_store.dart';
import 'package:runner_core/ecs/stores/status/weaken_store.dart';
import 'package:runner_core/ecs/systems/damage_system.dart';
import 'package:runner_core/ecs/systems/active_ability_phase_system.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/weapons/weapon_proc.dart';
import 'package:test/test.dart';

const _mix = DamageTypeMix(physical: 1, dark: 1);

void main() {
  test('mixed authoring requires positive, nonnegative shares', () {
    expect(() => DamageTypeMix(), throwsA(isA<AssertionError>()));
    expect(
      () => DamageTypeMix(physical: -1, dark: 2),
      throwsA(isA<AssertionError>()),
    );
  });

  test('all single types retain their complete damage amount', () {
    for (final type in DamageType.values) {
      expect(type.split(1001), [(type: type, amount100: 1001)]);
      expect(type.primaryType, type);
    }
  });

  test(
    'three types preserve the total and deterministic remainder ordering',
    () {
      const mix = DamageTypeMix(physical: 2, fire: 1, dark: 3);
      expect(mix.split(1001), [
        (type: DamageType.physical, amount100: 333),
        (type: DamageType.fire, amount100: 167),
        (type: DamageType.dark, amount100: 501),
      ]);
      expect(mix.primaryType, DamageType.dark);
      expect(_mix.primaryType, DamageType.physical);
      expect(_mix.split(1), [(type: DamageType.dark, amount100: 1)]);
      expect(_mix.split(0), isEmpty);
    },
  );

  test('item conversion changes only physical and merges matching shares', () {
    final converted = _mix.withPhysicalType(DamageType.fire);
    expect(converted.split(2200), [
      (type: DamageType.fire, amount100: 1100),
      (type: DamageType.dark, amount100: 1100),
    ]);
    expect(_mix.withPhysicalType(DamageType.dark).split(2200), [
      (type: DamageType.dark, amount100: 2200),
    ]);
    expect(DamageType.ice.withPhysicalType(DamageType.fire), DamageType.ice);
  });

  test(
    'Scythe Sweep snapshots power and conversion without multiplying damage',
    () {
      final ability = const AbilityCatalog().resolve('bringer.scythe_sweep')!;
      expect(ability.baseDamage, 2200);
      expect(ability.baseDamageType.split(ability.baseDamage), [
        (type: DamageType.physical, amount100: 1100),
        (type: DamageType.dark, amount100: 1100),
      ]);
      final payload = HitPayloadBuilder.build(
        ability: ability,
        source: 1,
        globalPowerBonusBp: 5000,
        weaponDamageType: DamageType.fire,
      );
      expect(payload.damage100, 3300);
      expect(payload.damageType.split(payload.damage100), [
        (type: DamageType.fire, amount100: 1650),
        (type: DamageType.dark, amount100: 1650),
      ]);
    },
  );

  test('typed resistance and vulnerability apply independently to one hit', () {
    final f = _Fixture();
    f.world.damageResistance.add(
      f.target,
      const DamageResistanceDef(physicalBp: -5000, darkBp: 2500),
    );
    f.queue();
    f.apply();
    expect(f.hp, 10000 - 550 - 1375);
    expect(f.world.reactiveDamageEventQueue.length, 1);
    expect(f.world.invulnerability.ticksLeft.single, 15);
    f.queue();
    f.apply();
    expect(
      f.hp,
      8075,
      reason: 'post-hit protection covers the entire next hit',
    );
  });

  test(
    'weaken and one crit scale both shares; proc and feedback fire once',
    () {
      final f = _Fixture();
      f.world.weaken.add(
        f.source,
        const WeakenDef(ticksLeft: 60, magnitude: 5000),
      );
      f.world.damageResistance.add(
        f.target,
        const DamageResistanceDef(darkBp: -10000),
      );
      f.queue(
        amount100: 2000,
        critChanceBp: 10000,
        procs: const [
          WeaponProc(
            hook: ProcHook.onHit,
            statusProfileId: StatusProfileId.weakenOnHit,
          ),
          WeaponProc(
            hook: ProcHook.onCrit,
            statusProfileId: StatusProfileId.stunOnHit,
          ),
        ],
      );
      final statuses = <StatusRequest>[];
      var callbacks = 0;
      f.damage.step(
        f.world,
        currentTick: 1,
        queueStatus: statuses.add,
        onDamageApplied:
            ({
              required target,
              required source,
              required appliedAmount100,
              required sourceKind,
              required damageType,
              required credit,
            }) {
              callbacks++;
              expect(appliedAmount100, 750);
              expect(damageType, DamageType.physical);
            },
      );
      expect(f.hp, 9250);
      expect(callbacks, 1);
      expect(statuses.map((s) => s.profileId), [
        StatusProfileId.weakenOnHit,
        StatusProfileId.stunOnHit,
      ]);
      expect(statuses.every((s) => s.acceptedHitTick == 1), isTrue);
      expect(f.world.reactiveDamageEventQueue.length, 1);
    },
  );

  test('ward scales the total before the split and typed resistance', () {
    final f = _Fixture();
    f.world.damageReduction.add(
      f.target,
      const DamageReductionDef(ticksLeft: 60, magnitude: 2500),
    );
    f.world.damageResistance.add(
      f.target,
      const DamageResistanceDef(physicalBp: -5000),
    );
    f.queue();
    const WardMiddleware().apply(f.world, f.world.damageQueue, 0, 1);
    expect(f.world.damageQueue.amount100.single, 1650);
    f.apply();
    expect(f.hp, 10000 - 412 - 825);
  });

  test('guard reduces both shares and grants one riposte', () {
    final f = _Fixture();
    f.world.activeAbility.add(f.target);
    f.world.activeAbility.set(
      f.target,
      id: 'eloise.aegis_riposte',
      slot: AbilitySlot.secondary,
      commitTick: 1,
      windupTicks: 0,
      activeTicks: 18,
      recoveryTicks: 0,
      facingDir: Facing.right,
    );
    ActiveAbilityPhaseSystem().step(f.world, currentTick: 1);
    f.world.damageResistance.add(
      f.target,
      const DamageResistanceDef(darkBp: -10000),
    );
    f.queue(amount100: 2000);
    ParryMiddleware(abilityIds: {'eloise.aegis_riposte'})
        .apply(f.world, f.world.damageQueue, 0, 1);
    expect(f.world.damageQueue.amount100.single, 1000);
    f.apply();
    expect(f.hp, 9500);
    expect(f.world.riposte.denseEntities, [f.target]);
  });

  test(
    'fully resisted mixed hit preserves on-hit semantics without HP events',
    () {
      final f = _Fixture();
      f.world.damageResistance.add(
        f.target,
        const DamageResistanceDef(physicalBp: -15000, darkBp: -10000),
      );
      f.queue(
        procs: const [
          WeaponProc(
            hook: ProcHook.onHit,
            statusProfileId: StatusProfileId.weakenOnHit,
          ),
        ],
      );
      final statuses = <StatusRequest>[];
      f.damage.step(f.world, currentTick: 1, queueStatus: statuses.add);
      expect(f.hp, 10000);
      expect(statuses, hasLength(1));
      expect(f.world.reactiveDamageEventQueue.length, 0);
      expect(f.world.invulnerability.lastComboHit.single, isNull);
    },
  );

  test('mixed combo bypass belongs only to its source and activation', () {
    final f = _Fixture();
    f.queue(comboHit: ComboHit(source: f.source, activation: 1, strike: 0));
    f.apply();
    f.queue(comboHit: ComboHit(source: f.source, activation: 2, strike: 1));
    f.queue(comboHit: ComboHit(source: f.source, activation: 1, strike: 0));
    f.queue(comboHit: ComboHit(source: f.source, activation: 1, strike: 1));
    f.apply();
    expect(f.hp, 5600);
    expect(f.world.reactiveDamageEventQueue.length, 2);
    expect(f.world.invulnerability.lastComboHit.single?.strike, 1);
  });
}

class _Fixture {
  _Fixture() {
    source = world.createEntity();
    target = world.createEntity();
    world.health.add(
      target,
      const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
    );
    world.invulnerability.add(target);
  }

  final world = EcsWorld();
  final damage = DamageSystem(invulnerabilityTicksOnHit: 15, rngSeed: 1);
  late final int source;
  late final int target;
  int get hp => world.health.hp[world.health.indexOf(target)];

  void queue({
    int amount100 = 2200,
    int critChanceBp = 0,
    List<WeaponProc> procs = const [],
    ComboHit? comboHit,
  }) {
    world.damageQueue.add(
      DamageRequest(
        target: target,
        source: source,
        amount100: amount100,
        damageType: _mix,
        critChanceBp: critChanceBp,
        procs: procs,
        comboHit: comboHit,
      ),
    );
  }

  void apply() => damage.step(world, currentTick: 1);
}
