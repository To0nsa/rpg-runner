import 'package:flutter_test/flutter_test.dart';

import 'package:walkscape_runner/core/combat/damage.dart';
import 'package:walkscape_runner/core/ecs/systems/damage_system.dart';
import 'package:walkscape_runner/core/ecs/world.dart';
import 'package:walkscape_runner/core/ecs/stores/health_store.dart';

void main() {
  test('DamageSystem clamps health and ignores missing targets', () {
    final world = EcsWorld();
    final damage = DamageSystem(invulnerabilityTicksOnHit: 0);

    final e = world.createEntity();
    world.health.add(
      e,
      const HealthDef(hp: 10, hpMax: 10, regenPerSecond: 0),
    );

    damage.queue(DamageRequest(target: 999, amount: 5));
    damage.queue(DamageRequest(target: e, amount: 3));
    damage.queue(DamageRequest(target: e, amount: 100));

    damage.step(world);

    final hi = world.health.indexOf(e);
    expect(world.health.hp[hi], closeTo(0.0, 1e-9));
  });
}
