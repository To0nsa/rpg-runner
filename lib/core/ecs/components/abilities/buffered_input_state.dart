import 'package:rpg_runner/core/abilities/ability_def.dart';

class BufferedInputState {
  bool hasValue = false;
  AbilitySlot slot = AbilitySlot.primary;
  int pressedTick = 0;
  AimSnapshot aim = AimSnapshot.empty;

  void set(AbilitySlot s, int tick, AimSnapshot a) {
    hasValue = true;
    slot = s;
    pressedTick = tick;
    aim = a;
  }

  void clear() {
    hasValue = false;
    aim = AimSnapshot.empty;
  }
}
