import '../../entity_id.dart';
import '../../sparse_set.dart';

enum BossFlightMode { hover, pursue, charge }

/// One-tick flight requests; missing or stale requests resolve to stationary hover.
/// Terrain owns integration and collision. Destruction clears requests with IDs.
final class BossFlightIntentStore extends SparseSet {
  final List<int> tick = [];
  final List<BossFlightMode> mode = [];
  final List<double> targetX = [], targetY = [], speedX = [], speedY = [];

  /// Targets and speeds use world units and world units/second respectively.
  /// Zero speed on an axis holds the actor's current position on that axis.
  void pursue(
    EntityId actor, {
    required int currentTick,
    required double x,
    required double y,
    required double horizontalSpeed,
    required double verticalSpeed,
  }) {
    final i = indexOf(actor);
    tick[i] = currentTick;
    mode[i] = BossFlightMode.pursue;
    targetX[i] = x;
    targetY[i] = y;
    speedX[i] = horizontalSpeed;
    speedY[i] = verticalSpeed;
  }

  /// A charge retains its signed horizontal world-units/second velocity.
  void charge(
    EntityId actor, {
    required int currentTick,
    required double velocityX,
  }) {
    final i = indexOf(actor);
    tick[i] = currentTick;
    mode[i] = BossFlightMode.charge;
    speedX[i] = velocityX;
  }

  void hover(EntityId actor, int currentTick) {
    final i = indexOf(actor);
    tick[i] = currentTick;
    mode[i] = BossFlightMode.hover;
  }

  @override
  void onDenseAdded(int denseIndex) {
    tick.add(-1);
    mode.add(BossFlightMode.hover);
    targetX.add(0);
    targetY.add(0);
    speedX.add(0);
    speedY.add(0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    tick[removeIndex] = tick[lastIndex];
    tick.removeLast();
    mode[removeIndex] = mode[lastIndex];
    mode.removeLast();
    for (final values in [targetX, targetY, speedX, speedY]) {
      values[removeIndex] = values[lastIndex];
      values.removeLast();
    }
  }
}
