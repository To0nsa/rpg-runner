import '../../entity_id.dart';
import '../../sparse_set.dart';

/// Per-tick player input (authoritative commands decoded by the core).
///
/// This is reset/overwritten each tick by `GameCore.applyCommands`.
/// All actions are boolean or axis values used by `MovementSystem` and decision systems.
class PlayerInputStore extends SparseSet {
  final List<double> moveAxis = <double>[];
  final List<bool> jumpPressed = <bool>[];
  final List<bool> dashPressed = <bool>[];
  final List<bool> attackPressed = <bool>[];
  final List<double> projectileAimDirX = <double>[];
  final List<double> projectileAimDirY = <double>[];
  final List<double> meleeAimDirX = <double>[];
  final List<double> meleeAimDirY = <double>[];
  final List<bool> castPressed = <bool>[];
  final List<bool> rangedPressed = <bool>[];
  final List<double> rangedAimDirX = <double>[];
  final List<double> rangedAimDirY = <double>[];

  void add(EntityId entity) {
    addEntity(entity);
  }

  void resetTickInputs(EntityId entity) {
    final i = indexOf(entity);
    moveAxis[i] = 0;
    jumpPressed[i] = false;
    dashPressed[i] = false;
    attackPressed[i] = false;
    projectileAimDirX[i] = 0;
    projectileAimDirY[i] = 0;
    meleeAimDirX[i] = 0;
    meleeAimDirY[i] = 0;
    castPressed[i] = false;
    rangedPressed[i] = false;
    rangedAimDirX[i] = 0;
    rangedAimDirY[i] = 0;
  }

  @override
  void onDenseAdded(int denseIndex) {
    moveAxis.add(0);
    jumpPressed.add(false);
    dashPressed.add(false);
    attackPressed.add(false);
    projectileAimDirX.add(0);
    projectileAimDirY.add(0);
    meleeAimDirX.add(0);
    meleeAimDirY.add(0);
    castPressed.add(false);
    rangedPressed.add(false);
    rangedAimDirX.add(0);
    rangedAimDirY.add(0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    moveAxis[removeIndex] = moveAxis[lastIndex];
    jumpPressed[removeIndex] = jumpPressed[lastIndex];
    dashPressed[removeIndex] = dashPressed[lastIndex];
    attackPressed[removeIndex] = attackPressed[lastIndex];
    projectileAimDirX[removeIndex] = projectileAimDirX[lastIndex];
    projectileAimDirY[removeIndex] = projectileAimDirY[lastIndex];
    meleeAimDirX[removeIndex] = meleeAimDirX[lastIndex];
    meleeAimDirY[removeIndex] = meleeAimDirY[lastIndex];
    castPressed[removeIndex] = castPressed[lastIndex];
    rangedPressed[removeIndex] = rangedPressed[lastIndex];
    rangedAimDirX[removeIndex] = rangedAimDirX[lastIndex];
    rangedAimDirY[removeIndex] = rangedAimDirY[lastIndex];

    moveAxis.removeLast();
    jumpPressed.removeLast();
    dashPressed.removeLast();
    attackPressed.removeLast();
    projectileAimDirX.removeLast();
    projectileAimDirY.removeLast();
    meleeAimDirX.removeLast();
    meleeAimDirY.removeLast();
    castPressed.removeLast();
    rangedPressed.removeLast();
    rangedAimDirX.removeLast();
    rangedAimDirY.removeLast();
  }
}
