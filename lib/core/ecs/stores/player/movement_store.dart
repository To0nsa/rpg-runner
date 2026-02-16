import '../../../snapshots/enums.dart';
import '../../entity_id.dart';
import '../../sparse_set.dart';

/// Movement state for platformer-style motion (timers + grounded + facing).
///
/// Contains transient state counters for precise movement tech:
/// - Coyote time (jump after leaving ledge)
/// - Jump buffer (press before landing)
/// - Active dash state (duration, direction)
///
/// **Note**: Dash *cooldown* is now managed by [CooldownStore] using
/// [CooldownGroup.mobility]. This store only tracks active dash execution.
class MovementStore extends SparseSet {
  final List<int> coyoteTicksLeft = <int>[];
  final List<int> jumpBufferTicksLeft = <int>[];

  /// Ticks remaining in active dash. 0 = not dashing.
  final List<int> dashTicksLeft = <int>[];

  /// Direction of current dash (-1.0 or 1.0).
  final List<double> dashDirX = <double>[];
  final List<double> dashDirY = <double>[];

  /// Dash speed multiplier sampled at commit-time.
  final List<double> dashSpeedScale = <double>[];
  final List<double> mobilitySpeedX = <double>[];

  final List<Facing> facing = <Facing>[];
  final List<int> facingLockTicksLeft = <int>[];

  void add(EntityId entity, {required Facing facing}) {
    final i = addEntity(entity);
    this.facing[i] = facing;
  }

  bool isDashing(EntityId entity) => dashTicksLeft[indexOf(entity)] > 0;

  @override
  void onDenseAdded(int denseIndex) {
    coyoteTicksLeft.add(0);
    jumpBufferTicksLeft.add(0);
    dashTicksLeft.add(0);
    dashDirX.add(1);
    dashDirY.add(0);
    dashSpeedScale.add(1.0);
    mobilitySpeedX.add(0.0);
    facing.add(Facing.right);
    facingLockTicksLeft.add(0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    coyoteTicksLeft[removeIndex] = coyoteTicksLeft[lastIndex];
    jumpBufferTicksLeft[removeIndex] = jumpBufferTicksLeft[lastIndex];
    dashTicksLeft[removeIndex] = dashTicksLeft[lastIndex];
    dashDirX[removeIndex] = dashDirX[lastIndex];
    dashDirY[removeIndex] = dashDirY[lastIndex];
    dashSpeedScale[removeIndex] = dashSpeedScale[lastIndex];
    mobilitySpeedX[removeIndex] = mobilitySpeedX[lastIndex];
    facing[removeIndex] = facing[lastIndex];
    facingLockTicksLeft[removeIndex] = facingLockTicksLeft[lastIndex];

    coyoteTicksLeft.removeLast();
    jumpBufferTicksLeft.removeLast();
    dashTicksLeft.removeLast();
    dashDirX.removeLast();
    dashDirY.removeLast();
    dashSpeedScale.removeLast();
    mobilitySpeedX.removeLast();
    facing.removeLast();
    facingLockTicksLeft.removeLast();
  }
}
