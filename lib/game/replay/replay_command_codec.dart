import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/commands/command.dart';
import 'package:run_protocol/replay_blob.dart';

/// Converts replay protocol command frames into Core commands.
class ReplayCommandCodec {
  const ReplayCommandCodec._();

  static List<Command> commandsFromFrame(ReplayCommandFrameV1 frame) {
    final out = <Command>[];
    final tick = frame.tick;

    final moveAxis = frame.moveAxis;
    if (moveAxis != null && moveAxis != 0) {
      out.add(MoveAxisCommand(tick: tick, axis: moveAxis));
    }

    final aimX = frame.aimDirX;
    final aimY = frame.aimDirY;
    if (aimX != null && aimY != null) {
      out.add(AimDirCommand(tick: tick, x: aimX, y: aimY));
    }

    if (frame.jumpPressed) {
      out.add(JumpPressedCommand(tick: tick));
    }
    if (frame.dashPressed) {
      out.add(DashPressedCommand(tick: tick));
    }
    if (frame.strikePressed) {
      out.add(StrikePressedCommand(tick: tick));
    }
    if (frame.projectilePressed) {
      out.add(ProjectilePressedCommand(tick: tick));
    }
    if (frame.secondaryPressed) {
      out.add(SecondaryPressedCommand(tick: tick));
    }
    if (frame.spellPressed) {
      out.add(SpellPressedCommand(tick: tick));
    }

    final heldChangedMask = frame.abilitySlotHeldChangedMask;
    if (heldChangedMask != 0) {
      for (final slot in AbilitySlot.values) {
        final bit = 1 << slot.index;
        if ((heldChangedMask & bit) == 0) continue;
        final held = (frame.abilitySlotHeldValueMask & bit) != 0;
        out.add(AbilitySlotHeldCommand(tick: tick, slot: slot, held: held));
      }
    }

    return out;
  }
}
