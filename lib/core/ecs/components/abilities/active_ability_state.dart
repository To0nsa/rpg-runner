import 'package:rpg_runner/core/abilities/ability_def.dart';

class ActiveAbilityState {
  AbilityKey? abilityId; // null when idle
  AbilitySlot slot = AbilitySlot.primary;

  AbilityPhase phase = AbilityPhase.idle;
  int phaseTicksRemaining = 0;
  int totalDurationTicks = 0;

  int commitTick = 0; // Tick when the ability committed (costs paid)
  AimSnapshot aim = AimSnapshot.empty;
  
  bool get isIdle => phase == AbilityPhase.idle;
  bool get isBusy => phase != AbilityPhase.idle;

  void reset() {
    abilityId = null;
    slot = AbilitySlot.primary;
    phase = AbilityPhase.idle;
    phaseTicksRemaining = 0;
    totalDurationTicks = 0;
    commitTick = 0;
    aim = AimSnapshot.empty;
  }
}
