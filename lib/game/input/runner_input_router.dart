import 'dart:math';

import '../../core/commands/command.dart';
import '../game_controller.dart';

/// Shared input scheduler for multiple input sources (touch + keyboard + mouse).
///
/// - Holds the current continuous inputs (move axis, aim direction).
/// - Schedules them into the GameController for upcoming ticks so Core receives
///   tick-stamped Commands.
/// - Schedules edge-triggered presses (jump/dash/attack/cast) for the next tick.
class RunnerInputRouter {
  RunnerInputRouter({required this.controller});

  final GameController controller;

  static const double _aimQuantizeScale = 256.0;

  double _moveAxis = 0;
  double _lastScheduledAxis = 0;
  int _axisScheduledThroughTick = 0;

  bool _aimSet = false;
  bool _lastScheduledAimSet = false;
  double _aimX = 0;
  double _aimY = 0;
  double _lastScheduledAimX = 0;
  double _lastScheduledAimY = 0;
  int _aimScheduledThroughTick = 0;
  int _aimClearBlockedThroughTick = 0;

  static double _quantizeAim(double value) {
    if (value == 0) return 0;
    return (value * _aimQuantizeScale).roundToDouble() / _aimQuantizeScale;
  }

  void setMoveAxis(double axis) {
    _moveAxis = axis.clamp(-1.0, 1.0);
  }

  /// Sets the aim direction (should be normalized or near-normalized).
  void setAimDir(double x, double y) {
    final qx = _quantizeAim(x);
    final qy = _quantizeAim(y);

    if (_aimSet && qx == _aimX && qy == _aimY) {
      return;
    }

    _aimSet = true;
    _aimX = qx;
    _aimY = qy;
  }

  void clearAimDir() {
    _aimSet = false;
    _aimX = 0;
    _aimY = 0;
  }

  void pressJump() => controller.enqueueForNextTick(
        (tick) => JumpPressedCommand(tick: tick),
      );

  void pressDash() => controller.enqueueForNextTick(
        (tick) => DashPressedCommand(tick: tick),
      );

  void pressAttack() => controller.enqueueForNextTick(
        (tick) => AttackPressedCommand(tick: tick),
      );

  void pressCast() => controller.enqueueForNextTick(
        (tick) => CastPressedCommand(tick: tick),
      );

  /// Presses cast on the next tick and ensures the aim direction is set for the same tick.
  void pressCastWithAim() {
    commitCastWithAim(clearAim: false);
  }

  /// Commits cast on the next tick using the current aim dir (if set).
  ///
  /// When [clearAim] is true, clear commands are delayed until after the cast
  /// tick to avoid overwriting the aimed cast.
  void commitCastWithAim({required bool clearAim}) {
    final tick = controller.tick + controller.inputLead;
    final hadAim = _aimSet;
    if (hadAim) {
      controller.enqueue(AimDirCommand(tick: tick, x: _aimX, y: _aimY));
    }
    controller.enqueue(CastPressedCommand(tick: tick));
    if (clearAim) {
      _aimSet = false;
      _aimX = 0;
      _aimY = 0;
      if (hadAim) {
        _aimClearBlockedThroughTick =
            max(_aimClearBlockedThroughTick, tick);
      }
    }
  }

  /// Schedules the current held inputs across upcoming ticks.
  ///
  /// Call once per frame before `controller.advanceFrame(dt)`.
  void pumpHeldInputs() {
    _scheduleHeldMoveAxis();
    _scheduleHeldAimDir();
  }

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

  void _scheduleHeldAimDir() {
    if (!_aimSet && !_lastScheduledAimSet) {
      // No held aim and nothing to override.
      _aimScheduledThroughTick = controller.tick;
      return;
    }

    if (_aimSet != _lastScheduledAimSet) {
      _aimScheduledThroughTick = controller.tick;
      _lastScheduledAimSet = _aimSet;
      _lastScheduledAimX = _aimX;
      _lastScheduledAimY = _aimY;
    }

    if (_aimSet && (_aimX != _lastScheduledAimX || _aimY != _lastScheduledAimY)) {
      // Reschedule ahead when the aim vector changes.
      _aimScheduledThroughTick = controller.tick;
      _lastScheduledAimX = _aimX;
      _lastScheduledAimY = _aimY;
    }

    final maxTicksPerFrame = (controller.tickHz * 0.1).ceil();
    final targetMaxTick =
        controller.tick + controller.inputLead + maxTicksPerFrame;

    var startTick = max(controller.tick + 1, _aimScheduledThroughTick + 1);
    if (!_aimSet) {
      startTick = max(startTick, _aimClearBlockedThroughTick + 1);
    }
    for (var t = startTick; t <= targetMaxTick; t += 1) {
      if (_aimSet) {
        controller.enqueue(AimDirCommand(tick: t, x: _aimX, y: _aimY));
      } else {
        controller.enqueue(ClearAimDirCommand(tick: t));
      }
    }
    _aimScheduledThroughTick = targetMaxTick;
  }
}
