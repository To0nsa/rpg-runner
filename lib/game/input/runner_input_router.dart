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
  // Projectile aim state
  // ─────────────────────────────────────────────────────────────────────────

  /// Whether a projectile aim direction is currently set.
  bool _projectileAimSet = false;

  /// Whether the last scheduled state had aim set (for change detection).
  bool _projectileLastScheduledAimSet = false;

  /// Current projectile aim X component (quantized).
  double _projectileAimX = 0;

  /// Current projectile aim Y component (quantized).
  double _projectileAimY = 0;

  /// Last scheduled aim X (for change detection).
  double _projectileLastScheduledAimX = 0;

  /// Last scheduled aim Y (for change detection).
  double _projectileLastScheduledAimY = 0;

  /// Highest tick for which projectile aim commands have been enqueued.
  int _projectileAimScheduledThroughTick = 0;

  /// Tick through which clear commands are blocked (to avoid overwriting aimed cast).
  int _projectileAimClearBlockedThroughTick = 0;

  // ─────────────────────────────────────────────────────────────────────────
  // Melee aim state
  // ─────────────────────────────────────────────────────────────────────────

  /// Whether a melee aim direction is currently set.
  bool _meleeAimSet = false;

  /// Whether the last scheduled state had melee aim set.
  bool _lastScheduledMeleeAimSet = false;

  /// Current melee aim X component (quantized).
  double _meleeAimX = 0;

  /// Current melee aim Y component (quantized).
  double _meleeAimY = 0;

  /// Last scheduled melee aim X.
  double _lastScheduledMeleeAimX = 0;

  /// Last scheduled melee aim Y.
  double _lastScheduledMeleeAimY = 0;

  /// Highest tick for which melee aim commands have been enqueued.
  int _meleeAimScheduledThroughTick = 0;

  /// Tick through which melee clear commands are blocked.
  int _meleeAimClearBlockedThroughTick = 0;

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
  void setProjectileAimDir(double x, double y) {
    final qx = AimQuantizer.quantize(x);
    final qy = AimQuantizer.quantize(y);

    // Skip if aim hasn't meaningfully changed.
    if (_projectileAimSet && qx == _projectileAimX && qy == _projectileAimY) {
      return;
    }

    _projectileAimSet = true;
    _projectileAimX = qx;
    _projectileAimY = qy;
  }

  /// Clears the projectile aim direction.
  ///
  /// Called when the player releases the aim input. Subsequent [pumpHeldInputs]
  /// calls will schedule [ClearProjectileAimDirCommand] for upcoming ticks.
  void clearProjectileAimDir() {
    _projectileAimSet = false;
    _projectileAimX = 0;
    _projectileAimY = 0;
  }

  /// Sets the melee aim direction (should be normalized or near-normalized).
  ///
  /// Quantized similarly to [setProjectileAimDir] to reduce jitter.
  void setMeleeAimDir(double x, double y) {
    final qx = AimQuantizer.quantize(x);
    final qy = AimQuantizer.quantize(y);

    // Skip if aim hasn't meaningfully changed.
    if (_meleeAimSet && qx == _meleeAimX && qy == _meleeAimY) {
      return;
    }

    _meleeAimSet = true;
    _meleeAimX = qx;
    _meleeAimY = qy;
  }

  /// Clears the melee aim direction.
  ///
  /// Called when the player releases the melee aim input.
  void clearMeleeAimDir() {
    _meleeAimSet = false;
    _meleeAimX = 0;
    _meleeAimY = 0;
  }

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
    final hadAim = _projectileAimSet;
    if (hadAim) {
      controller.enqueue(
        ProjectileAimDirCommand(
          tick: tick,
          x: _projectileAimX,
          y: _projectileAimY,
        ),
      );
    }
    controller.enqueue(CastPressedCommand(tick: tick));
    if (clearAim) {
      _projectileAimSet = false;
      _projectileAimX = 0;
      _projectileAimY = 0;
      if (hadAim) {
        _projectileAimClearBlockedThroughTick = max(
          _projectileAimClearBlockedThroughTick,
          tick,
        );
      }
    }
  }

  /// Commits a melee attack on the next tick using the current melee aim dir.
  void commitMeleeAttack() {
    final tick = controller.tick + controller.inputLead;
    final hadAim = _meleeAimSet;
    if (hadAim) {
      controller.enqueue(
        MeleeAimDirCommand(tick: tick, x: _meleeAimX, y: _meleeAimY),
      );
    } else {
      controller.enqueue(ClearMeleeAimDirCommand(tick: tick));
    }
    controller.enqueue(AttackPressedCommand(tick: tick));

    // Clear aim after commit (release behavior).
    _meleeAimSet = false;
    _meleeAimX = 0;
    _meleeAimY = 0;
    if (hadAim) {
      _meleeAimClearBlockedThroughTick = max(
        _meleeAimClearBlockedThroughTick,
        tick,
      );
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
    _scheduleHeldProjectileAimDir();

    // 3. Melee aim: same pattern as projectile, but for melee attack direction.
    _scheduleHeldMeleeAimDir();
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

    final maxTicksPerFrame = (controller.tickHz * 0.1).ceil();
    final targetMaxTick =
        controller.tick + controller.inputLead + maxTicksPerFrame;

    final startTick = max(controller.tick + 1, _axisScheduledThroughTick + 1);
    for (var t = startTick; t <= targetMaxTick; t += 1) {
      controller.enqueue(MoveAxisCommand(tick: t, axis: axis));
    }
    _axisScheduledThroughTick = targetMaxTick;
  }

  /// Schedules projectile aim commands for upcoming ticks.
  ///
  /// - If aim is set, enqueues [ProjectileAimDirCommand] for each tick.
  /// - If aim was cleared, enqueues [ClearProjectileAimDirCommand] to overwrite
  ///   any previously-scheduled aim commands.
  /// - Respects [_projectileAimClearBlockedThroughTick] to avoid clearing aim
  ///   during a tick where an aimed cast is being committed.
  void _scheduleHeldProjectileAimDir() {
    if (!_projectileAimSet && !_projectileLastScheduledAimSet) {
      // No held aim and nothing to override.
      _projectileAimScheduledThroughTick = controller.tick;
      return;
    }

    if (_projectileAimSet != _projectileLastScheduledAimSet) {
      _projectileAimScheduledThroughTick = controller.tick;
      _projectileLastScheduledAimSet = _projectileAimSet;
      _projectileLastScheduledAimX = _projectileAimX;
      _projectileLastScheduledAimY = _projectileAimY;
    }

    if (_projectileAimSet &&
        (_projectileAimX != _projectileLastScheduledAimX ||
            _projectileAimY != _projectileLastScheduledAimY)) {
      // Reschedule ahead when the projectile aim vector changes.
      _projectileAimScheduledThroughTick = controller.tick;
      _projectileLastScheduledAimX = _projectileAimX;
      _projectileLastScheduledAimY = _projectileAimY;
    }

    final maxTicksPerFrame = (controller.tickHz * 0.1).ceil();
    final targetMaxTick =
        controller.tick + controller.inputLead + maxTicksPerFrame;

    var startTick = max(
      controller.tick + 1,
      _projectileAimScheduledThroughTick + 1,
    );
    if (!_projectileAimSet) {
      startTick = max(startTick, _projectileAimClearBlockedThroughTick + 1);
    }
    for (var t = startTick; t <= targetMaxTick; t += 1) {
      if (_projectileAimSet) {
        controller.enqueue(
          ProjectileAimDirCommand(
            tick: t,
            x: _projectileAimX,
            y: _projectileAimY,
          ),
        );
      } else {
        controller.enqueue(ClearProjectileAimDirCommand(tick: t));
      }
    }
    _projectileAimScheduledThroughTick = targetMaxTick;
  }

  /// Schedules melee aim commands for upcoming ticks.
  ///
  /// Works analogously to [_scheduleHeldProjectileAimDir], but for melee attacks.
  /// Respects [_meleeAimClearBlockedThroughTick] to avoid clearing aim during
  /// a tick where an aimed melee attack is being committed.
  void _scheduleHeldMeleeAimDir() {
    if (!_meleeAimSet && !_lastScheduledMeleeAimSet) {
      // No held aim and nothing to override.
      _meleeAimScheduledThroughTick = controller.tick;
      return;
    }

    if (_meleeAimSet != _lastScheduledMeleeAimSet) {
      _meleeAimScheduledThroughTick = controller.tick;
      _lastScheduledMeleeAimSet = _meleeAimSet;
      _lastScheduledMeleeAimX = _meleeAimX;
      _lastScheduledMeleeAimY = _meleeAimY;
    }

    if (_meleeAimSet &&
        (_meleeAimX != _lastScheduledMeleeAimX ||
            _meleeAimY != _lastScheduledMeleeAimY)) {
      // Reschedule ahead when the aim vector changes.
      _meleeAimScheduledThroughTick = controller.tick;
      _lastScheduledMeleeAimX = _meleeAimX;
      _lastScheduledMeleeAimY = _meleeAimY;
    }

    final maxTicksPerFrame = (controller.tickHz * 0.1).ceil();
    final targetMaxTick =
        controller.tick + controller.inputLead + maxTicksPerFrame;

    var startTick = max(controller.tick + 1, _meleeAimScheduledThroughTick + 1);
    if (!_meleeAimSet) {
      startTick = max(startTick, _meleeAimClearBlockedThroughTick + 1);
    }
    for (var t = startTick; t <= targetMaxTick; t += 1) {
      if (_meleeAimSet) {
        controller.enqueue(
          MeleeAimDirCommand(tick: t, x: _meleeAimX, y: _meleeAimY),
        );
      } else {
        controller.enqueue(ClearMeleeAimDirCommand(tick: t));
      }
    }
    _meleeAimScheduledThroughTick = targetMaxTick;
  }
}
