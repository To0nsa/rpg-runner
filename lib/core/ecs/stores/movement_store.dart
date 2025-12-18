import '../../snapshots/enums.dart';
import '../entity_id.dart';
import '../sparse_set.dart';

/// Movement state for platformer-style motion (timers + grounded + facing).
class MovementStore extends SparseSet {
  final List<int> coyoteTicksLeft = <int>[];
  final List<int> jumpBufferTicksLeft = <int>[];

  final List<int> dashTicksLeft = <int>[];
  final List<int> dashCooldownTicksLeft = <int>[];
  final List<double> dashDirX = <double>[];

  final List<Facing> facing = <Facing>[];

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
    dashCooldownTicksLeft.add(0);
    dashDirX.add(1);
    facing.add(Facing.right);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    coyoteTicksLeft[removeIndex] = coyoteTicksLeft[lastIndex];
    jumpBufferTicksLeft[removeIndex] = jumpBufferTicksLeft[lastIndex];
    dashTicksLeft[removeIndex] = dashTicksLeft[lastIndex];
    dashCooldownTicksLeft[removeIndex] = dashCooldownTicksLeft[lastIndex];
    dashDirX[removeIndex] = dashDirX[lastIndex];
    facing[removeIndex] = facing[lastIndex];

    coyoteTicksLeft.removeLast();
    jumpBufferTicksLeft.removeLast();
    dashTicksLeft.removeLast();
    dashCooldownTicksLeft.removeLast();
    dashDirX.removeLast();
    facing.removeLast();
  }
}
