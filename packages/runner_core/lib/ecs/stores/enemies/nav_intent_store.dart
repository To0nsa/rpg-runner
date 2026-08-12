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

  /// Active planned jump data shared with locomotion by either navigator.
  final List<bool> hasActiveJumpTraversal = <bool>[];
  final List<double> activeJumpTakeoffX = <double>[];
  final List<double> activeJumpLandingX = <double>[];
  final List<int> activeJumpCommitDirX = <int>[];
  final List<int> activeJumpTravelTicks = <int>[];

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
    clearActiveJumpTraversalAt(i);
  }

  void setActiveJumpTraversalAt(
    int index, {
    required double takeoffX,
    required double landingX,
    required int commitDirectionX,
    required int travelTicks,
  }) {
    hasActiveJumpTraversal[index] = true;
    activeJumpTakeoffX[index] = takeoffX;
    activeJumpLandingX[index] = landingX;
    activeJumpCommitDirX[index] = commitDirectionX;
    activeJumpTravelTicks[index] = travelTicks;
  }

  void clearActiveJumpTraversalAt(int index) {
    hasActiveJumpTraversal[index] = false;
    activeJumpTakeoffX[index] = 0;
    activeJumpLandingX[index] = 0;
    activeJumpCommitDirX[index] = 0;
    activeJumpTravelTicks[index] = 0;
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
    hasActiveJumpTraversal.add(false);
    activeJumpTakeoffX.add(0);
    activeJumpLandingX.add(0);
    activeJumpCommitDirX.add(0);
    activeJumpTravelTicks.add(0);
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
    hasActiveJumpTraversal[removeIndex] = hasActiveJumpTraversal[lastIndex];
    activeJumpTakeoffX[removeIndex] = activeJumpTakeoffX[lastIndex];
    activeJumpLandingX[removeIndex] = activeJumpLandingX[lastIndex];
    activeJumpCommitDirX[removeIndex] = activeJumpCommitDirX[lastIndex];
    activeJumpTravelTicks[removeIndex] = activeJumpTravelTicks[lastIndex];

    navTargetX.removeLast();
    desiredX.removeLast();
    jumpNow.removeLast();
    hasPlan.removeLast();
    commitMoveDirX.removeLast();
    safeSurfaceMinX.removeLast();
    safeSurfaceMaxX.removeLast();
    hasSafeSurface.removeLast();
    hasActiveJumpTraversal.removeLast();
    activeJumpTakeoffX.removeLast();
    activeJumpLandingX.removeLast();
    activeJumpCommitDirX.removeLast();
    activeJumpTravelTicks.removeLast();
  }
}
