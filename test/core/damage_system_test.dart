import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/combat/damage.dart';
import 'package:rpg_runner/core/ecs/systems/damage_system.dart';
import 'package:rpg_runner/core/ecs/world.dart';
import 'package:rpg_runner/core/ecs/stores/health_store.dart';

void main() {
  test('DamageSystem clamps health and ignores missing targets', () {
    final world = EcsWorld();
    final damage = DamageSystem(invulnerabilityTicksOnHit: 0, rngSeed: 1);

    final e = world.createEntity();
    world.health.add(
      e,
      const HealthDef(hp: 1000, hpMax: 1000, regenPerSecond100: 0),
    );

    damage.queue(const DamageRequest(target: 999, amount100: 500));
    damage.queue(DamageRequest(target: e, amount100: 300));
    damage.queue(DamageRequest(target: e, amount100: 10000));

    damage.step(world, currentTick: 1);

    final hi = world.health.indexOf(e);
    expect(world.health.hp[hi], equals(0));
  });
}
