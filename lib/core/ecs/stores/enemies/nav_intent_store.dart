import '../../entity_id.dart';
import '../../sparse_set.dart';

/// Navigation intent produced by pathfinding for ground enemies.
class NavIntentStore extends SparseSet {
  /// Target X used for path planning (player or predicted landing).
  final List<double> navTargetX = <double>[];

  /// Desired X from the navigator (immediate movement goal).
  final List<double> desiredX = <double>[];

  /// Whether the enemy should jump this tick.
  final List<bool> jumpNow = <bool>[];

  /// Whether a valid navigation plan exists.
  final List<bool> hasPlan = <bool>[];

  /// Committed move direction for plan execution (-1, 0, 1).
  final List<int> commitMoveDirX = <int>[];

  /// Safe surface bounds for no-plan movement.
  final List<double> safeSurfaceMinX = <double>[];
  final List<double> safeSurfaceMaxX = <double>[];
  final List<bool> hasSafeSurface = <bool>[];

  void add(EntityId entity) {
    final i = addEntity(entity);
    navTargetX[i] = 0.0;
    desiredX[i] = 0.0;
    jumpNow[i] = false;
    hasPlan[i] = false;
    commitMoveDirX[i] = 0;
    safeSurfaceMinX[i] = 0.0;
    safeSurfaceMaxX[i] = 0.0;
    hasSafeSurface[i] = false;
  }

  @override
  void onDenseAdded(int denseIndex) {
    navTargetX.add(0.0);
    desiredX.add(0.0);
    jumpNow.add(false);
    hasPlan.add(false);
    commitMoveDirX.add(0);
    safeSurfaceMinX.add(0.0);
    safeSurfaceMaxX.add(0.0);
    hasSafeSurface.add(false);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    navTargetX[removeIndex] = navTargetX[lastIndex];
    desiredX[removeIndex] = desiredX[lastIndex];
    jumpNow[removeIndex] = jumpNow[lastIndex];
    hasPlan[removeIndex] = hasPlan[lastIndex];
    commitMoveDirX[removeIndex] = commitMoveDirX[lastIndex];
    safeSurfaceMinX[removeIndex] = safeSurfaceMinX[lastIndex];
    safeSurfaceMaxX[removeIndex] = safeSurfaceMaxX[lastIndex];
    hasSafeSurface[removeIndex] = hasSafeSurface[lastIndex];

    navTargetX.removeLast();
    desiredX.removeLast();
    jumpNow.removeLast();
    hasPlan.removeLast();
    commitMoveDirX.removeLast();
    safeSurfaceMinX.removeLast();
    safeSurfaceMaxX.removeLast();
    hasSafeSurface.removeLast();
  }
}
