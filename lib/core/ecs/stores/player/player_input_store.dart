import '../../../abilities/ability_def.dart';
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
  final List<bool> strikePressed = <bool>[];
  final List<double> projectileAimDirX = <double>[];
  final List<double> projectileAimDirY = <double>[];
  final List<bool> projectileChargeTicksSet = <bool>[];
  final List<int> projectileChargeTicks = <int>[];
  final List<double> meleeAimDirX = <double>[];
  final List<double> meleeAimDirY = <double>[];
  final List<bool> projectilePressed = <bool>[];
  final List<bool> secondaryPressed = <bool>[];
  final List<bool> bonusPressed = <bool>[];
  final List<bool> hasAbilitySlotPressed = <bool>[];
  final List<AbilitySlot> lastAbilitySlotPressed = <AbilitySlot>[];

  void add(EntityId entity) {
    addEntity(entity);
  }

  void resetTickInputs(EntityId entity) {
    final i = indexOf(entity);
    moveAxis[i] = 0;
    jumpPressed[i] = false;
    dashPressed[i] = false;
    strikePressed[i] = false;
    projectileAimDirX[i] = 0;
    projectileAimDirY[i] = 0;
    projectileChargeTicksSet[i] = false;
    projectileChargeTicks[i] = 0;
    meleeAimDirX[i] = 0;
    meleeAimDirY[i] = 0;
    projectilePressed[i] = false;
    secondaryPressed[i] = false;
    bonusPressed[i] = false;
    hasAbilitySlotPressed[i] = false;
  }

  @override
  void onDenseAdded(int denseIndex) {
    moveAxis.add(0);
    jumpPressed.add(false);
    dashPressed.add(false);
    strikePressed.add(false);
    projectileAimDirX.add(0);
    projectileAimDirY.add(0);
    projectileChargeTicksSet.add(false);
    projectileChargeTicks.add(0);
    meleeAimDirX.add(0);
    meleeAimDirY.add(0);
    projectilePressed.add(false);
    secondaryPressed.add(false);
    bonusPressed.add(false);
    hasAbilitySlotPressed.add(false);
    lastAbilitySlotPressed.add(AbilitySlot.primary);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    moveAxis[removeIndex] = moveAxis[lastIndex];
    jumpPressed[removeIndex] = jumpPressed[lastIndex];
    dashPressed[removeIndex] = dashPressed[lastIndex];
    strikePressed[removeIndex] = strikePressed[lastIndex];
    projectileAimDirX[removeIndex] = projectileAimDirX[lastIndex];
    projectileAimDirY[removeIndex] = projectileAimDirY[lastIndex];
    projectileChargeTicksSet[removeIndex] = projectileChargeTicksSet[lastIndex];
    projectileChargeTicks[removeIndex] = projectileChargeTicks[lastIndex];
    meleeAimDirX[removeIndex] = meleeAimDirX[lastIndex];
    meleeAimDirY[removeIndex] = meleeAimDirY[lastIndex];
    projectilePressed[removeIndex] = projectilePressed[lastIndex];
    secondaryPressed[removeIndex] = secondaryPressed[lastIndex];
    bonusPressed[removeIndex] = bonusPressed[lastIndex];
    hasAbilitySlotPressed[removeIndex] = hasAbilitySlotPressed[lastIndex];
    lastAbilitySlotPressed[removeIndex] = lastAbilitySlotPressed[lastIndex];

    moveAxis.removeLast();
    jumpPressed.removeLast();
    dashPressed.removeLast();
    strikePressed.removeLast();
    projectileAimDirX.removeLast();
    projectileAimDirY.removeLast();
    projectileChargeTicksSet.removeLast();
    projectileChargeTicks.removeLast();
    meleeAimDirX.removeLast();
    meleeAimDirY.removeLast();
    projectilePressed.removeLast();
    secondaryPressed.removeLast();
    bonusPressed.removeLast();
    hasAbilitySlotPressed.removeLast();
    lastAbilitySlotPressed.removeLast();
  }
}
