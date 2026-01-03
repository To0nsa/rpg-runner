// Bridge between Core simulation and the Flutter/Flame runtime.
//
// Responsibilities:
// - Owns the `GameCore` instance
// - Queues tick-stamped input commands
// - Runs a fixed-tick simulation loop using an accumulator
// - Exposes (`prevSnapshot`, `snapshot`, `alpha`) for render interpolation
// - Buffers transient `GameEvent`s for Render/UI to consume
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/commands/command.dart';
import '../core/events/game_event.dart';
import '../core/game_core.dart';
import '../core/snapshots/game_state_snapshot.dart';
import 'tick_input_frame.dart';

/// Owns the simulation clock and provides a stable interface to UI/renderer.
class GameController extends ChangeNotifier {
  GameController({required GameCore core, this.tickHz = 60, this.inputLead = 1})
    : _core = core {
    if (tickHz <= 0) {
      throw ArgumentError.value(tickHz, 'tickHz', 'must be > 0');
    }
    if (inputLead < 1) {
      throw ArgumentError.value(inputLead, 'inputLead', 'must be >= 1');
    }
    if (tickHz != _core.tickHz) {
      throw ArgumentError(
        'GameController.tickHz ($tickHz) must match GameCore.tickHz (${_core.tickHz}).',
      );
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
  final Map<int, TickInputFrame> _inputsByTick = <int, TickInputFrame>{};

  final List<Command> _commandScratch = <Command>[];
  final TickInputFrame _frameScratch = TickInputFrame();

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
    final frame = _inputsByTick.putIfAbsent(command.tick, () => TickInputFrame());
    frame.apply(command);
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
    notifyListeners();
  }

  /// Permanently stops this controller for the current session.
  ///
  /// Use this when leaving the mini-game route (dispose), NOT for backgrounding
  /// (that's what [setPaused] is for).
  ///
  /// What it does:
  /// - pauses the core
  /// - clears queued commands (prevents "stuck input" on next mount)
  /// - clears buffered transient events
  /// - resets interpolation state (accumulator + snapshots)
  void shutdown() {
    // Pause regardless of current state (do NOT early-return like setPaused()).
    _core.paused = true;

    // Drop any in-flight fixed-tick accumulation.
    _accumulatorSeconds = 0;

    // Kill transient buffers so nothing leaks across sessions.
    _inputsByTick.clear();
    _events.clear();

    // Make snapshots consistent with the paused state.
    _curr = _core.buildSnapshot();
    _prev = _curr;
    notifyListeners();
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
    var didStep = false;

    while (_accumulatorSeconds >= dtTick) {
      if (_core.paused) {
        _accumulatorSeconds = 0;
        break;
      }
      final nextTick = _core.tick + 1;
      final input = _inputsByTick.remove(nextTick) ?? _frameScratch;
      _applyTickInput(nextTick, input);
      _core.stepOneTick();
      _events.addAll(_core.drainEvents());

      _prev = _curr;
      _curr = _core.buildSnapshot();
      _accumulatorSeconds -= dtTick;
      didStep = true;

      // If the core became paused during the tick (e.g. game over), stop consuming
      // accumulator to avoid an infinite loop.
      if (_core.paused) {
        _accumulatorSeconds = 0;
        break;
      }
    }
    if (didStep) {
      notifyListeners();
    }
  }

  void _applyTickInput(int tick, TickInputFrame input) {
    _commandScratch.clear();

    final axis = input.moveAxis;
    if (axis != 0) {
      _commandScratch.add(MoveAxisCommand(tick: tick, axis: axis));
    }

    if (input.aimDirSet) {
      _commandScratch.add(
        AimDirCommand(
          tick: tick,
          x: input.aimDirX,
          y: input.aimDirY,
        ),
      );
    }
    if (input.jumpPressed) {
      _commandScratch.add(JumpPressedCommand(tick: tick));
    }
    if (input.dashPressed) {
      _commandScratch.add(DashPressedCommand(tick: tick));
    }
    if (input.attackPressed) {
      _commandScratch.add(AttackPressedCommand(tick: tick));
    }
    if (input.castPressed) {
      _commandScratch.add(CastPressedCommand(tick: tick));
    }

    _core.applyCommands(_commandScratch);

    // If this is a scratch fallback, it will be reset by the next use anyway.
    // For frames stored in the map we drop the instance after remove().
    input.reset();
  }
}
