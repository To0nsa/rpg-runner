import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/ecs/systems/lifetime_system.dart';
import 'package:rpg_runner/core/ecs/stores/lifetime_store.dart';
import 'package:rpg_runner/core/ecs/world.dart';

void main() {
  test('LifetimeSystem decrements and despawns at 0', () {
    final world = EcsWorld();
    final system = LifetimeSystem();

    final a = world.createEntity();
    world.lifetime.add(a, const LifetimeDef(ticksLeft: 2));

    final b = world.createEntity();
    world.lifetime.add(b, const LifetimeDef(ticksLeft: 1));

    system.step(world);
    expect(world.lifetime.has(a), isTrue);
    expect(world.lifetime.ticksLeft[world.lifetime.indexOf(a)], 1);
    expect(world.lifetime.has(b), isFalse);

    system.step(world);
    expect(world.lifetime.has(a), isFalse);
  });
}

