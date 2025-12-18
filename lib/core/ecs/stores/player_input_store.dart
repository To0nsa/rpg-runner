import '../entity_id.dart';
import '../sparse_set.dart';

/// Per-tick player input (authoritative commands decoded by the core).
///
/// This is reset/overwritten each tick by `GameCore.applyCommands`.
class PlayerInputStore extends SparseSet {
  final List<double> moveAxis = <double>[];
  final List<bool> jumpPressed = <bool>[];
  final List<bool> dashPressed = <bool>[];
  final List<bool> attackPressed = <bool>[];
  final List<double> aimDirX = <double>[];
  final List<double> aimDirY = <double>[];
  final List<bool> castPressed = <bool>[];

  void add(EntityId entity) {
    addEntity(entity);
  }

  void resetTickInputs(EntityId entity) {
    final i = indexOf(entity);
    moveAxis[i] = 0;
    jumpPressed[i] = false;
    dashPressed[i] = false;
    attackPressed[i] = false;
    aimDirX[i] = 0;
    aimDirY[i] = 0;
    castPressed[i] = false;
  }

  @override
  void onDenseAdded(int denseIndex) {
    moveAxis.add(0);
    jumpPressed.add(false);
    dashPressed.add(false);
    attackPressed.add(false);
    aimDirX.add(0);
    aimDirY.add(0);
    castPressed.add(false);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    moveAxis[removeIndex] = moveAxis[lastIndex];
    jumpPressed[removeIndex] = jumpPressed[lastIndex];
    dashPressed[removeIndex] = dashPressed[lastIndex];
    attackPressed[removeIndex] = attackPressed[lastIndex];
    aimDirX[removeIndex] = aimDirX[lastIndex];
    aimDirY[removeIndex] = aimDirY[lastIndex];
    castPressed[removeIndex] = castPressed[lastIndex];

    moveAxis.removeLast();
    jumpPressed.removeLast();
    dashPressed.removeLast();
    attackPressed.removeLast();
    aimDirX.removeLast();
    aimDirY.removeLast();
    castPressed.removeLast();
  }
}
