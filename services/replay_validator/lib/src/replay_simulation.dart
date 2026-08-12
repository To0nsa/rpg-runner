import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/game_core.dart';
import 'package:run_protocol/replay_blob.dart';

/// Result of applying one validated replay command stream to Core.
final class ReplaySimulationResult {
  const ReplaySimulationResult({
    required this.ticksExecuted,
    required this.runEnded,
  });

  final int ticksExecuted;
  final RunEndedEvent? runEnded;
}

/// Replays protocol command frames through the normal deterministic Core loop.
///
/// The validator and its throughput benchmark share this function so command
/// conversion, event draining, checkpoint cadence, and early run termination
/// cannot diverge.
ReplaySimulationResult runReplaySimulation({
  required GameCore core,
  required int totalTicks,
  required List<ReplayCommandFrameV1> commandStream,
  void Function(int tick)? onCheckpoint,
}) {
  final frameByTick = <int, ReplayCommandFrameV1>{
    for (final frame in commandStream) frame.tick: frame,
  };
  RunEndedEvent? runEnded;
  var ticksExecuted = 0;
  for (var tick = 1; tick <= totalTicks; tick += 1) {
    if (tick == 1 || tick % 256 == 0) {
      onCheckpoint?.call(tick);
    }
    final frame = frameByTick[tick];
    core.applyCommands(
      frame == null ? const <Command>[] : _commandsFromReplayFrame(frame),
    );
    core.stepOneTick();
    ticksExecuted = tick;
    runEnded = latestRunEndedEvent(core.drainEvents()) ?? runEnded;
    if (runEnded != null && core.gameOver) {
      break;
    }
  }
  return ReplaySimulationResult(
    ticksExecuted: ticksExecuted,
    runEnded: runEnded,
  );
}

/// Returns the last run-end event in an already ordered Core event batch.
RunEndedEvent? latestRunEndedEvent(List<GameEvent> events) {
  RunEndedEvent? result;
  for (final event in events) {
    if (event is RunEndedEvent) {
      result = event;
    }
  }
  return result;
}

List<Command> _commandsFromReplayFrame(ReplayCommandFrameV1 frame) {
  final out = <Command>[];
  final tick = frame.tick;
  final moveAxis = frame.moveAxis;
  if (moveAxis != null && moveAxis != 0) {
    out.add(MoveAxisCommand(tick: tick, axis: moveAxis));
  }
  final aimDirX = frame.aimDirX;
  final aimDirY = frame.aimDirY;
  if (aimDirX != null && aimDirY != null) {
    out.add(AimDirCommand(tick: tick, x: aimDirX, y: aimDirY));
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
  final changedMask = frame.abilitySlotHeldChangedMask;
  if (changedMask != 0) {
    for (final slot in AbilitySlot.values) {
      final bit = 1 << slot.index;
      if ((changedMask & bit) == 0) continue;
      out.add(
        AbilitySlotHeldCommand(
          tick: tick,
          slot: slot,
          held: (frame.abilitySlotHeldValueMask & bit) != 0,
        ),
      );
    }
  }
  return out;
}
