import '../stores/damage_queue_store.dart';
import '../world.dart';

/// Applies combat rules to queued damage before it reaches [DamageSystem].
///
/// Middlewares can cancel, redirect, or modify queued damage requests.
/// This system never writes health directly.
class DamageMiddlewareSystem {
  DamageMiddlewareSystem({
    List<DamageMiddleware> middlewares = const <DamageMiddleware>[],
  }) : _middlewares = List<DamageMiddleware>.unmodifiable(middlewares);

  final List<DamageMiddleware> _middlewares;

  void step(EcsWorld world, {required int currentTick}) {
    if (_middlewares.isEmpty) return;

    final queue = world.damageQueue;
    final initialCount = queue.length;
    if (initialCount == 0) return;

    for (var i = 0; i < initialCount; i += 1) {
      if ((queue.flags[i] & DamageQueueFlags.canceled) != 0) continue;
      for (final middleware in _middlewares) {
        middleware.apply(world, queue, i, currentTick);
        if ((queue.flags[i] & DamageQueueFlags.canceled) != 0) {
          break;
        }
      }
    }
  }
}

/// Middleware hook for editing queued damage requests.
abstract class DamageMiddleware {
  void apply(EcsWorld world, DamageQueueStore queue, int index, int currentTick);
}
