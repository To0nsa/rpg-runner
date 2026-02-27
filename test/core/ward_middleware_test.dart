import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/combat/damage.dart';
import 'package:rpg_runner/core/combat/middleware/ward_middleware.dart';
import 'package:rpg_runner/core/ecs/stores/damage_queue_store.dart';
import 'package:rpg_runner/core/ecs/stores/health_store.dart';
import 'package:rpg_runner/core/ecs/stores/status/damage_reduction_store.dart';
import 'package:rpg_runner/core/ecs/systems/damage_middleware_system.dart';
import 'package:rpg_runner/core/ecs/systems/damage_system.dart';
import 'package:rpg_runner/core/ecs/world.dart';
import 'package:rpg_runner/core/events/game_event.dart';

void main() {
  test('WardMiddleware reduces direct hits and cancels DoT without guard phase', () {
    final world = EcsWorld();
    final target = world.createEntity();
    world.health.add(
      target,
      const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
    );
    world.damageReduction.add(
      target,
      const DamageReductionDef(ticksLeft: 120, magnitude: 4000),
    );

    world.damageQueue.add(
      DamageRequest(
        target: target,
        amount100: 1000,
        sourceKind: DeathSourceKind.meleeHitbox,
      ),
    );
    world.damageQueue.add(
      DamageRequest(
        target: target,
        amount100: 700,
        sourceKind: DeathSourceKind.statusEffect,
      ),
    );
    world.damageQueue.add(
      DamageRequest(
        target: target,
        amount100: 1,
        sourceKind: DeathSourceKind.projectile,
      ),
    );

    final middleware = DamageMiddlewareSystem(
      middlewares: const <DamageMiddleware>[WardMiddleware()],
    );
    middleware.step(world, currentTick: 10);

    expect(world.damageQueue.amount100[0], equals(600));
    expect(world.damageQueue.flags[0] & DamageQueueFlags.canceled, equals(0));
    expect(world.damageQueue.flags[1] & DamageQueueFlags.canceled, equals(1));
    expect(world.damageQueue.flags[2] & DamageQueueFlags.canceled, equals(1));

    final damage = DamageSystem(invulnerabilityTicksOnHit: 0, rngSeed: 1);
    damage.step(world, currentTick: 10);
    expect(world.health.hp[world.health.indexOf(target)], equals(9400));
  });

  test('WardMiddleware does not change damage when ward is expired', () {
    final world = EcsWorld();
    final target = world.createEntity();
    world.health.add(
      target,
      const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
    );
    world.damageReduction.add(
      target,
      const DamageReductionDef(ticksLeft: 0, magnitude: 4000),
    );

    world.damageQueue.add(
      DamageRequest(
        target: target,
        amount100: 1000,
        sourceKind: DeathSourceKind.meleeHitbox,
      ),
    );

    final middleware = DamageMiddlewareSystem(
      middlewares: const <DamageMiddleware>[WardMiddleware()],
    );
    middleware.step(world, currentTick: 10);

    expect(world.damageQueue.amount100.single, equals(1000));
    expect(
      world.damageQueue.flags.single & DamageQueueFlags.canceled,
      equals(0),
    );
  });
}
