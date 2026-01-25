import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/combat/damage.dart';
import 'package:rpg_runner/core/combat/damage_type.dart';
import 'package:rpg_runner/core/combat/status/status.dart';
import 'package:rpg_runner/core/ecs/stores/health_store.dart';
import 'package:rpg_runner/core/ecs/stores/combat/damage_resistance_store.dart';
import 'package:rpg_runner/core/ecs/systems/damage_system.dart';
import 'package:rpg_runner/core/ecs/systems/status_system.dart';
import 'package:rpg_runner/core/ecs/world.dart';

void main() {
  test('DamageSystem applies resistance and vulnerability modifiers', () {
    final world = EcsWorld();
    final damage = DamageSystem(invulnerabilityTicksOnHit: 0, rngSeed: 1);

    final target = world.createEntity();
    world.health.add(
      target,
      const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
    );
    world.damageResistance.add(
      target,
      const DamageResistanceDef(fireBp: -5000, iceBp: 5000),
    );

    damage.queue(
      DamageRequest(
        target: target,
        amount100: 1000,
        damageType: DamageType.fire,
      ),
    );
    damage.step(world, currentTick: 1);

    expect(world.health.hp[world.health.indexOf(target)], equals(9500));

    damage.queue(
      DamageRequest(
        target: target,
        amount100: 1000,
        damageType: DamageType.ice,
      ),
    );
    damage.step(world, currentTick: 2);

    expect(world.health.hp[world.health.indexOf(target)], equals(8000));
  });

  test('status applies even when damage is fully resisted', () {
    final world = EcsWorld();
    final damage = DamageSystem(invulnerabilityTicksOnHit: 0, rngSeed: 1);
    final status = StatusSystem(tickHz: 60);

    final target = world.createEntity();
    world.health.add(
      target,
      const HealthDef(hp: 5000, hpMax: 5000, regenPerSecond100: 0),
    );
    world.damageResistance.add(
      target,
      const DamageResistanceDef(iceBp: -10000),
    );
    world.invulnerability.add(target);
    world.statusImmunity.add(target);
    world.statModifier.add(target);

    damage.queue(
      DamageRequest(
        target: target,
        amount100: 1000,
        damageType: DamageType.ice,
        statusProfileId: StatusProfileId.iceBolt,
      ),
    );
    damage.step(world, currentTick: 1, queueStatus: status.queue);
    status.applyQueued(world, currentTick: 1);

    expect(world.health.hp[world.health.indexOf(target)], equals(5000));
    expect(world.slow.has(target), isTrue);
  });

  test('bleed ticks damage on its period', () {
    final world = EcsWorld();
    final damage = DamageSystem(invulnerabilityTicksOnHit: 0, rngSeed: 1);
    final status = StatusSystem(tickHz: 10);

    final target = world.createEntity();
    world.health.add(
      target,
      const HealthDef(hp: 2000, hpMax: 2000, regenPerSecond100: 0),
    );
    world.damageResistance.add(target, const DamageResistanceDef());
    world.invulnerability.add(target);
    world.statusImmunity.add(target);

    status.queue(
      StatusRequest(
        target: target,
        profileId: StatusProfileId.meleeBleed,
      ),
    );
    status.applyQueued(world, currentTick: 0);

    for (var tick = 1; tick <= 10; tick += 1) {
      status.tickExisting(world, damage.queue);
      damage.step(world, currentTick: tick);
    }

    expect(world.health.hp[world.health.indexOf(target)], equals(1700));
  });
}
