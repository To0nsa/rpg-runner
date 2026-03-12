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
  final List<double> aimDirX = <double>[];
  final List<double> aimDirY = <double>[];
  final List<bool> projectilePressed = <bool>[];
  final List<bool> secondaryPressed = <bool>[];
  final List<bool> spellPressed = <bool>[];
  final List<bool> hasAbilitySlotPressed = <bool>[];
  final List<AbilitySlot> lastAbilitySlotPressed = <AbilitySlot>[];
  final List<int> heldAbilitySlotMask = <int>[];

  void add(EntityId entity) {
    addEntity(entity);
  }

  void resetTickInputs(EntityId entity) {
    final i = indexOf(entity);
    moveAxis[i] = 0;
    jumpPressed[i] = false;
    dashPressed[i] = false;
    strikePressed[i] = false;
    aimDirX[i] = 0;
    aimDirY[i] = 0;
    projectilePressed[i] = false;
    secondaryPressed[i] = false;
    spellPressed[i] = false;
    hasAbilitySlotPressed[i] = false;
  }

  bool isAbilitySlotHeld(EntityId entity, AbilitySlot slot) {
    if (!has(entity)) return false;
    final i = indexOf(entity);
    final bit = 1 << slot.index;
    return (heldAbilitySlotMask[i] & bit) != 0;
  }

  void setAbilitySlotHeld(EntityId entity, AbilitySlot slot, bool held) {
    final i = indexOf(entity);
    final bit = 1 << slot.index;
    if (held) {
      // Only one held slot is allowed at a time; latest hold wins.
      heldAbilitySlotMask[i] = bit;
    } else {
      heldAbilitySlotMask[i] &= ~bit;
    }
  }

  @override
  void onDenseAdded(int denseIndex) {
    moveAxis.add(0);
    jumpPressed.add(false);
    dashPressed.add(false);
    strikePressed.add(false);
    aimDirX.add(0);
    aimDirY.add(0);
    projectilePressed.add(false);
    secondaryPressed.add(false);
    spellPressed.add(false);
    hasAbilitySlotPressed.add(false);
    lastAbilitySlotPressed.add(AbilitySlot.primary);
    heldAbilitySlotMask.add(0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    moveAxis[removeIndex] = moveAxis[lastIndex];
    jumpPressed[removeIndex] = jumpPressed[lastIndex];
    dashPressed[removeIndex] = dashPressed[lastIndex];
    strikePressed[removeIndex] = strikePressed[lastIndex];
    aimDirX[removeIndex] = aimDirX[lastIndex];
    aimDirY[removeIndex] = aimDirY[lastIndex];
    projectilePressed[removeIndex] = projectilePressed[lastIndex];
    secondaryPressed[removeIndex] = secondaryPressed[lastIndex];
    spellPressed[removeIndex] = spellPressed[lastIndex];
    hasAbilitySlotPressed[removeIndex] = hasAbilitySlotPressed[lastIndex];
    lastAbilitySlotPressed[removeIndex] = lastAbilitySlotPressed[lastIndex];
    heldAbilitySlotMask[removeIndex] = heldAbilitySlotMask[lastIndex];

    moveAxis.removeLast();
    jumpPressed.removeLast();
    dashPressed.removeLast();
    strikePressed.removeLast();
    aimDirX.removeLast();
    aimDirY.removeLast();
    projectilePressed.removeLast();
    secondaryPressed.removeLast();
    spellPressed.removeLast();
    hasAbilitySlotPressed.removeLast();
    lastAbilitySlotPressed.removeLast();
    heldAbilitySlotMask.removeLast();
  }
}
