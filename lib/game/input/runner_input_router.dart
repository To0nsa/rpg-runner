import 'dart:math';

import '../../core/commands/command.dart';
import '../game_controller.dart';
import 'aim_quantizer.dart';

/// Shared input scheduler for multiple input sources (touch + keyboard + mouse).
///
/// - Holds the current continuous inputs (move axis, projectile aim direction).
/// - Schedules them into the GameController for upcoming ticks so Core receives
///   tick-stamped Commands.
/// - Schedules edge-triggered presses (jump/dash/attack/cast) for the next tick.
///
/// The router distinguishes between:
/// - **Continuous inputs** (movement axis, aim directions): held state is pumped
///   each frame via [pumpHeldInputs], scheduling commands for upcoming ticks.
/// - **Edge-triggered inputs** (jump, dash, attack, cast): one-shot events
///   scheduled immediately for the next tick via [pressJump], [pressDash], etc.
class RunnerInputRouter {
  /// Creates a router bound to the given [controller].
  RunnerInputRouter({required this.controller});

  /// The game controller that receives scheduled commands.
  final GameController controller;

  /// Input buffering window in seconds.
  ///
  /// This determines how far ahead continuous inputs (move, aim) are scheduled
  /// to smooth over frame rate hitches.
  static const double _inputBufferSeconds = 0.1;

  // ─────────────────────────────────────────────────────────────────────────
  // Movement axis state
  // ─────────────────────────────────────────────────────────────────────────

  /// Current horizontal movement axis in [-1, 1]. Set by touch/keyboard input.
  double _moveAxis = 0;

  /// Last axis value that was scheduled, used to detect changes.
  double _lastScheduledAxis = 0;

  /// Highest tick for which axis commands have been enqueued.
  int _axisScheduledThroughTick = 0;

  // ─────────────────────────────────────────────────────────────────────────
  // Aim state channels
  // ─────────────────────────────────────────────────────────────────────────

  final _AimInputChannel _projectileAim = _AimInputChannel();

  final _AimInputChannel _meleeAim = _AimInputChannel();

  // ─────────────────────────────────────────────────────────────────────────
  // Public setters for continuous inputs
  // ─────────────────────────────────────────────────────────────────────────

  /// Sets the horizontal movement axis (clamped to [-1, 1]).
  ///
  /// Called by joystick or keyboard handlers. The value is held until changed
  /// and pumped to the controller each frame via [pumpHeldInputs].
  void setMoveAxis(double axis) {
    _moveAxis = axis.clamp(-1.0, 1.0);
  }

  /// Sets the projectile aim direction (should be normalized or near-normalized).
  ///
  /// The direction is quantized to reduce floating-point noise. If the quantized
  /// value matches the current aim, the call is a no-op to avoid redundant updates.
  void setProjectileAimDir(double x, double y) => _projectileAim.set(x, y);

  /// Clears the projectile aim direction.
  ///
  /// Called when the player releases the aim input. Subsequent [pumpHeldInputs]
  /// calls will schedule [ClearProjectileAimDirCommand] for upcoming ticks.
  void clearProjectileAimDir() => _projectileAim.clear();

  /// Sets the melee aim direction (should be normalized or near-normalized).
  ///
  /// Quantized similarly to [setProjectileAimDir] to reduce jitter.
  void setMeleeAimDir(double x, double y) => _meleeAim.set(x, y);

  /// Clears the melee aim direction.
  ///
  /// Called when the player releases the melee aim input.
  void clearMeleeAimDir() => _meleeAim.clear();

  // ─────────────────────────────────────────────────────────────────────────
  // Edge-triggered (one-shot) input methods
  // ─────────────────────────────────────────────────────────────────────────

  /// Schedules a jump press for the next tick.
  void pressJump() =>
      controller.enqueueForNextTick((tick) => JumpPressedCommand(tick: tick));

  /// Schedules a dash press for the next tick.
  void pressDash() =>
      controller.enqueueForNextTick((tick) => DashPressedCommand(tick: tick));

  /// Schedules a melee attack press for the next tick.
  void pressAttack() =>
      controller.enqueueForNextTick((tick) => AttackPressedCommand(tick: tick));

  /// Schedules a cast (projectile) press for the next tick.
  void pressCast() =>
      controller.enqueueForNextTick((tick) => CastPressedCommand(tick: tick));

  // ─────────────────────────────────────────────────────────────────────────
  // Combined action methods (aim + action in a single tick)
  // ─────────────────────────────────────────────────────────────────────────

  /// Presses cast on the next tick and ensures the projectile aim direction is set
  /// for the same tick.
  ///
  /// Unlike [pressCast], this guarantees the aim and cast commands share the same
  /// tick, which is important for aimed projectile attacks.
  void pressCastWithAim() {
    commitCastWithAim(clearAim: false);
  }

  /// Commits cast on the next tick using the current projectile aim dir (if set).
  ///
  /// When [clearAim] is true, clear commands are delayed until after the cast
  /// tick to avoid overwriting the aimed cast.
  void commitCastWithAim({required bool clearAim}) {
    final tick = controller.tick + controller.inputLead;
    final hadAim = _projectileAim.isSet;
    if (hadAim) {
      controller.enqueue(
        ProjectileAimDirCommand(
          tick: tick,
          x: _projectileAim.x,
          y: _projectileAim.y,
        ),
      );
    }

    controller.enqueue(CastPressedCommand(tick: tick));

    if (clearAim) {
      _projectileAim.clear();
      if (hadAim) {
        // Prevent immediate clear command from overwriting the aim we just committed
        _projectileAim.blockClearThrough(tick);
      }
    }
  }

  /// Commits a melee attack on the next tick using the current melee aim dir.
  void commitMeleeAttack() {
    final tick = controller.tick + controller.inputLead;
    final hadAim = _meleeAim.isSet;
    if (hadAim) {
      controller.enqueue(
        MeleeAimDirCommand(tick: tick, x: _meleeAim.x, y: _meleeAim.y),
      );
    } else {
      controller.enqueue(ClearMeleeAimDirCommand(tick: tick));
    }
    controller.enqueue(AttackPressedCommand(tick: tick));

    // Clear aim after commit (release behavior).
    _meleeAim.clear();
    if (hadAim) {
      _meleeAim.blockClearThrough(tick);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Frame pump: schedule continuous inputs for upcoming ticks
  // ─────────────────────────────────────────────────────────────────────────

  /// Schedules the current held inputs across upcoming ticks.
  ///
  /// This method should be called once per frame, before `controller.advanceFrame(dt)`,
  /// to ensure that continuous inputs (movement, aim) are scheduled far enough
  /// ahead that the simulation always has input data available.
  ///
  /// The scheduling window extends `inputLead + maxTicksPerFrame` ticks into the
  /// future to handle variable frame rates without input starvation.
  void pumpHeldInputs() {
    // 1. Movement: enqueue MoveAxisCommand for upcoming ticks (or overwrite if axis changed).
    _scheduleHeldMoveAxis();

    // 2. Projectile aim: enqueue aim direction or clear commands for upcoming ticks.
    _projectileAim.schedule(
      controller,
      _inputBufferSeconds,
      (t, x, y) => ProjectileAimDirCommand(tick: t, x: x, y: y),
      (t) => ClearProjectileAimDirCommand(tick: t),
    );

    // 3. Melee aim: same pattern as projectile, but for melee attack direction.
    _meleeAim.schedule(
      controller,
      _inputBufferSeconds,
      (t, x, y) => MeleeAimDirCommand(tick: t, x: x, y: y),
      (t) => ClearMeleeAimDirCommand(tick: t),
    );
  }

  /// Schedules [MoveAxisCommand]s for upcoming ticks based on the current axis value.
  ///
  /// Detects axis changes and re-schedules to overwrite any already-buffered ticks.
  void _scheduleHeldMoveAxis() {
    final axis = _moveAxis;

    if (axis == 0 && _lastScheduledAxis == 0) {
      // No held axis and nothing to override.
      _axisScheduledThroughTick = controller.tick;
      return;
    }

    if (axis != _lastScheduledAxis) {
      // Axis changed (including to 0); reschedule to overwrite any already
      // buffered ticks.
      _axisScheduledThroughTick = controller.tick;
      _lastScheduledAxis = axis;
    }

    final maxTicksPerFrame = (controller.tickHz * _inputBufferSeconds).ceil();
    final targetMaxTick =
        controller.tick + controller.inputLead + maxTicksPerFrame;

    final startTick = max(controller.tick + 1, _axisScheduledThroughTick + 1);
    for (var t = startTick; t <= targetMaxTick; t += 1) {
      controller.enqueue(MoveAxisCommand(tick: t, axis: axis));
    }
    _axisScheduledThroughTick = targetMaxTick;
  }
}

/// Helper class to encapsulate the state and scheduling logic for a single aim input (e.g., Projectile or Melee).
class _AimInputChannel {
  /// Whether an aim direction is currently set.
  bool isSet = false;

  /// The X component of the current aim direction (quantized).
  double x = 0;

  /// The Y component of the current aim direction (quantized).
  double y = 0;

  // -- Scheduling State --

  /// Whether the aim was set during the last schedule pass.
  bool _lastScheduledSet = false;

  /// The X component scheduled during the last pass.
  double _lastScheduledX = 0;

  /// The Y component scheduled during the last pass.
  double _lastScheduledY = 0;

  /// The highest tick for which we have already scheduled aim commands.
  int _scheduledThroughTick = 0;

  /// Tick through which clear commands are blocked.
  ///
  /// This is used when a "commit" action (like casting) uses the aim, and we want
  /// to ensure the subsequent clear command doesn't overwrite it in the same tick.
  int _clearBlockedThroughTick = 0;

  /// Updates the aim direction.
  void set(double rawX, double rawY) {
    final qx = AimQuantizer.quantize(rawX);
    final qy = AimQuantizer.quantize(rawY);

    if (isSet && qx == x && qy == y) {
      return;
    }

    isSet = true;
    x = qx;
    y = qy;
  }

  /// Clears the aim direction.
  void clear() {
    isSet = false;
    x = 0;
    y = 0;
  }

  /// Prevents `Clear...Command` from being scheduled up to and including [tick].
  void blockClearThrough(int tick) {
    _clearBlockedThroughTick = max(_clearBlockedThroughTick, tick);
  }

  /// Schedules aim or clear commands for upcoming ticks.
  ///
  /// [bufferSeconds] determines how far ahead to schedule.
  /// [createAimCmd] factory for the specific aim command (Projectile vs Melee).
  /// [createClearCmd] factory for the specific clear command.
  void schedule(
    GameController controller,
    double bufferSeconds,
    Command Function(int tick, double x, double y) createAimCmd,
    Command Function(int tick) createClearCmd,
  ) {
    if (!isSet && !_lastScheduledSet) {
      // No held aim and nothing to override.
      _scheduledThroughTick = controller.tick;
      return;
    }

    if (isSet != _lastScheduledSet) {
      // Aim active state changed; force reschedule from current tick to overwrite buffers.
      _scheduledThroughTick = controller.tick;
      _lastScheduledSet = isSet;
      _lastScheduledX = x;
      _lastScheduledY = y;
    }

    if (isSet && (x != _lastScheduledX || y != _lastScheduledY)) {
      // Vector changed; force reschedule from current tick.
      _scheduledThroughTick = controller.tick;
      _lastScheduledX = x;
      _lastScheduledY = y;
    }

    final maxTicksPerFrame = (controller.tickHz * bufferSeconds).ceil();
    final targetMaxTick =
        controller.tick + controller.inputLead + maxTicksPerFrame;

    var startTick = max(controller.tick + 1, _scheduledThroughTick + 1);

    // If we are clearing aim, ensure we don't overwrite a committed action tick.
    if (!isSet) {
      startTick = max(startTick, _clearBlockedThroughTick + 1);
    }

    for (var t = startTick; t <= targetMaxTick; t += 1) {
      if (isSet) {
        controller.enqueue(createAimCmd(t, x, y));
      } else {
        controller.enqueue(createClearCmd(t));
      }
    }
    _scheduledThroughTick = targetMaxTick;
  }
}