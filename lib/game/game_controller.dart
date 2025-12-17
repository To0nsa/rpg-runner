// Bridge between Core simulation and the Flutter/Flame runtime.
//
// Responsibilities:
// - Owns the `GameCore` instance
// - Queues tick-stamped input commands
// - Runs a fixed-tick simulation loop using an accumulator
// - Exposes (`prevSnapshot`, `snapshot`, `alpha`) for render interpolation
// - Buffers transient `GameEvent`s for Render/UI to consume
import 'dart:math';

import '../core/commands/command.dart';
import '../core/events/game_event.dart';
import '../core/game_core.dart';
import '../core/snapshots/game_state_snapshot.dart';

/// Owns the simulation clock and provides a stable interface to UI/renderer.
class GameController {
  GameController({
    required GameCore core,
    this.tickHz = 60,
    this.inputLead = 1,
  }) : _core = core {
    if (tickHz <= 0) {
      throw ArgumentError.value(tickHz, 'tickHz', 'must be > 0');
    }
    if (inputLead < 1) {
      throw ArgumentError.value(inputLead, 'inputLead', 'must be >= 1');
    }
    _curr = _core.buildSnapshot();
    _prev = _curr;
  }

  final GameCore _core;

  /// Fixed simulation tick frequency.
  final int tickHz;

  /// How many ticks ahead local input is scheduled by default.
  ///
  /// `1` means "next tick".
  final int inputLead;

  /// Buffered commands keyed by their target tick.
  final Map<int, List<Command>> _commandsByTick = <int, List<Command>>{};
  /// Buffered transient events produced by the core.
  final List<GameEvent> _events = <GameEvent>[];

  late GameStateSnapshot _prev;
  late GameStateSnapshot _curr;
  /// Accumulated time for fixed-tick simulation.
  double _accumulatorSeconds = 0;

  /// Current simulation tick (authoritative).
  int get tick => _core.tick;

  /// Latest snapshot produced by the core.
  GameStateSnapshot get snapshot => _curr;

  /// Previous snapshot (used for render interpolation).
  GameStateSnapshot get prevSnapshot => _prev;

  /// Interpolation factor between `prevSnapshot` and `snapshot` for rendering.
  double get alpha {
    final dtTick = 1.0 / tickHz;
    return (_accumulatorSeconds / dtTick).clamp(0, 1);
  }

  /// Enqueues a command to be applied at its declared tick.
  void enqueue(Command command) {
    final list = _commandsByTick.putIfAbsent(command.tick, () => <Command>[]);
    list.add(command);
  }

  /// Helper to schedule a command for the next tick (plus `inputLead`).
  void enqueueForNextTick(Command Function(int tick) factory) {
    enqueue(factory(tick + inputLead));
  }

  /// Drains and clears all buffered transient events.
  List<GameEvent> drainEvents() {
    if (_events.isEmpty) return const <GameEvent>[];
    final drained = List<GameEvent>.unmodifiable(_events);
    _events.clear();
    return drained;
  }

  /// Pauses/unpauses the simulation.
  void setPaused(bool value) {
    if (_core.paused == value) return;
    _core.paused = value;
    _accumulatorSeconds = 0;
    _prev = _core.buildSnapshot();
    _curr = _prev;
  }

  /// Advances the simulation clock based on a variable frame delta.
  ///
  /// This uses an accumulator to execute a fixed number of simulation ticks.
  /// `dtSeconds` is clamped to avoid "spiral of death" after app resumes.
  void advanceFrame(double dtSeconds, {double dtFrameMaxSeconds = 0.1}) {
    if (dtSeconds.isNaN || dtSeconds.isInfinite) return;
    if (_core.paused) {
      _accumulatorSeconds = 0;
      return;
    }

    final clamped = max(0.0, min(dtSeconds, dtFrameMaxSeconds));
    _accumulatorSeconds += clamped;

    final dtTick = 1.0 / tickHz;

    while (_accumulatorSeconds >= dtTick) {
      final nextTick = _core.tick + 1;
      final commands = _commandsByTick.remove(nextTick) ?? const <Command>[];
      _core.applyCommands(commands);
      _core.stepOneTick();

      _prev = _curr;
      _curr = _core.buildSnapshot();
      _accumulatorSeconds -= dtTick;
    }
  }
}
