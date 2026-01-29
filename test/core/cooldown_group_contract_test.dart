import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/abilities/ability_def.dart';

import 'package:rpg_runner/core/ecs/world.dart';

void main() {
  group('Cooldown Group Contract', () {
    late EcsWorld world;

    setUp(() {
      world = EcsWorld();
    });

    test('Shared cooldown group blocks multiple abilities', () {
      final player = world.createEntity();
      world.cooldown.add(player);

      // Group 0 is active.
      world.cooldown.startCooldown(player, 0, 10);

      // Both check against Group 0.
      expect(world.cooldown.isOnCooldown(player, 0), isTrue);

      // If we had two abilities using Group 0, both would see isOnCooldown = true.
      // This confirms the shared state nature.
    });

    test('Different cooldown groups are independent', () {
      final player = world.createEntity();
      world.cooldown.add(player);

      // Start Group 0.
      world.cooldown.startCooldown(player, 0, 10);

      // Group 1 should be free.
      expect(world.cooldown.isOnCooldown(player, 0), isTrue);
      expect(world.cooldown.isOnCooldown(player, 1), isFalse);
    });

    test('startCooldown uses max-refresh semantics (non-shortening)', () {
      final player = world.createEntity();
      world.cooldown.add(player);

      // Start with 20 ticks.
      world.cooldown.startCooldown(player, 0, 20);
      expect(world.cooldown.getTicksLeft(player, 0), equals(20));

      // Attempt to set shorter cooldown (10 ticks). Should be ignored.
      world.cooldown.startCooldown(player, 0, 10);
      expect(world.cooldown.getTicksLeft(player, 0), equals(20));

      // Attempt to set longer cooldown (30 ticks). Should apply.
      world.cooldown.startCooldown(player, 0, 30);
      expect(world.cooldown.getTicksLeft(player, 0), equals(30));
    });

    test('Invalid group IDs throw assertions', () {
      final player = world.createEntity();
      world.cooldown.add(player);

      expect(
        () => world.cooldown.getTicksLeft(player, -1),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => world.cooldown.getTicksLeft(player, kMaxCooldownGroups),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
