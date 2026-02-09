import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/combat/control_lock.dart';
import 'package:rpg_runner/core/ecs/systems/control_lock_system.dart';
import 'package:rpg_runner/core/ecs/world.dart';

void main() {
  test('addLock sets mask and expiry', () {
    final world = EcsWorld();
    final entity = world.createEntity();

    world.controlLock.addLock(entity, LockFlag.move, 10, 0);

    expect(world.controlLock.isLocked(entity, LockFlag.move, 0), isTrue);
    expect(world.controlLock.isLocked(entity, LockFlag.move, 9), isTrue);
    expect(world.controlLock.isLocked(entity, LockFlag.move, 10), isFalse);
    expect(world.controlLock.isLocked(entity, LockFlag.strike, 0), isFalse);

    // activeMask should be set immediately by addLock helper?
    // The store's helper `addLock` calls `refreshMask` internally?
    // Let's verify store behavior.
    expect(
      world.controlLock.activeMask[world.controlLock.indexOf(entity)] &
          LockFlag.move,
      equals(LockFlag.move),
    );
  });

  test('stun blocks all actions', () {
    final world = EcsWorld();
    final entity = world.createEntity();

    // Add stun (10 ticks)
    world.controlLock.addLock(entity, LockFlag.stun, 10, 0);

    // Stun flag is active
    expect(world.controlLock.isStunned(entity, 0), isTrue);

    expect(world.controlLock.isLocked(entity, LockFlag.strike, 5), isTrue);
    expect(world.controlLock.isLocked(entity, LockFlag.move, 5), isTrue);
    expect(world.controlLock.isLocked(entity, LockFlag.cast, 5), isTrue);
  });

  test('locks expire correctly', () {
    final world = EcsWorld();
    final system = ControlLockSystem();
    final entity = world.createEntity();

    world.controlLock.addLock(entity, LockFlag.cast, 5, 0);

    // Tick 0: Locked
    expect(world.controlLock.isLocked(entity, LockFlag.cast, 0), isTrue);

    // Tick 4: Locked
    expect(world.controlLock.isLocked(entity, LockFlag.cast, 4), isTrue);

    // Tick 5: Expired (since < untilTick)
    expect(world.controlLock.isLocked(entity, LockFlag.cast, 5), isFalse);

    // System step should clean up if all locks expired.
    // At tick 5, cast is expired.
    system.step(world, currentTick: 5);

    // Component should be removed if empty
    expect(world.controlLock.has(entity), isFalse);
  });

  test('refresh extends duration', () {
    final world = EcsWorld();
    final entity = world.createEntity();

    // Add lock until tick 10
    world.controlLock.addLock(entity, LockFlag.move, 10, 0);
    expect(
      world.controlLock.untilTickMove[world.controlLock.indexOf(entity)],
      10,
    );

    // Add overlapping lock until tick 15 (at tick 5, duration 10 => 5+10=15)
    world.controlLock.addLock(entity, LockFlag.move, 10, 5);
    expect(
      world.controlLock.untilTickMove[world.controlLock.indexOf(entity)],
      15,
    );

    // Add shorter lock (should not reduce duration)
    // At tick 6, add 2 ticks => until 8. Should stay 15.
    world.controlLock.addLock(entity, LockFlag.move, 2, 6);
    expect(
      world.controlLock.untilTickMove[world.controlLock.indexOf(entity)],
      15,
    );
  });

  test('stun start tick tracks continuous stun window', () {
    final world = EcsWorld();
    final entity = world.createEntity();

    world.controlLock.addLock(entity, LockFlag.stun, 8, 10);
    expect(world.controlLock.stunStartTickFor(entity, 10), 10);

    // Refreshing an active stun extends duration without resetting origin.
    world.controlLock.addLock(entity, LockFlag.stun, 6, 14);
    expect(world.controlLock.stunStartTickFor(entity, 14), 10);

    // Once expired, no active stun origin should be reported.
    expect(world.controlLock.stunStartTickFor(entity, 20), -1);
  });
}
