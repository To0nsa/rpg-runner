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
class RunnerInputRouter {
  RunnerInputRouter({required this.controller});

  final GameController controller;

  double _moveAxis = 0;
  double _lastScheduledAxis = 0;
  int _axisScheduledThroughTick = 0;

  bool _projectileAimSet = false;
  bool _projectileLastScheduledAimSet = false;
  double _projectileAimX = 0;
  double _projectileAimY = 0;
  double _projectileLastScheduledAimX = 0;
  double _projectileLastScheduledAimY = 0;
  int _projectileAimScheduledThroughTick = 0;
  int _projectileAimClearBlockedThroughTick = 0;

  bool _meleeAimSet = false;
  bool _lastScheduledMeleeAimSet = false;
  double _meleeAimX = 0;
  double _meleeAimY = 0;
  double _lastScheduledMeleeAimX = 0;
  double _lastScheduledMeleeAimY = 0;
  int _meleeAimScheduledThroughTick = 0;
  int _meleeAimClearBlockedThroughTick = 0;

  void setMoveAxis(double axis) {
    _moveAxis = axis.clamp(-1.0, 1.0);
  }

  /// Sets the projectile aim direction (should be normalized or near-normalized).
  void setProjectileAimDir(double x, double y) {
    final qx = AimQuantizer.quantize(x);
    final qy = AimQuantizer.quantize(y);

    if (_projectileAimSet && qx == _projectileAimX && qy == _projectileAimY) {
      return;
    }

    _projectileAimSet = true;
    _projectileAimX = qx;
    _projectileAimY = qy;
  }

  void clearProjectileAimDir() {
    _projectileAimSet = false;
    _projectileAimX = 0;
    _projectileAimY = 0;
  }

  /// Sets the melee aim direction (should be normalized or near-normalized).
  void setMeleeAimDir(double x, double y) {
    final qx = AimQuantizer.quantize(x);
    final qy = AimQuantizer.quantize(y);

    if (_meleeAimSet && qx == _meleeAimX && qy == _meleeAimY) {
      return;
    }

    _meleeAimSet = true;
    _meleeAimX = qx;
    _meleeAimY = qy;
  }

  void clearMeleeAimDir() {
    _meleeAimSet = false;
    _meleeAimX = 0;
    _meleeAimY = 0;
  }

  void pressJump() =>
      controller.enqueueForNextTick((tick) => JumpPressedCommand(tick: tick));

  void pressDash() =>
      controller.enqueueForNextTick((tick) => DashPressedCommand(tick: tick));

  void pressAttack() =>
      controller.enqueueForNextTick((tick) => AttackPressedCommand(tick: tick));

  void pressCast() =>
      controller.enqueueForNextTick((tick) => CastPressedCommand(tick: tick));

  /// Presses cast on the next tick and ensures the projectile aim direction is set
  /// for the same tick.
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

  /// Schedules the current held inputs across upcoming ticks.
  ///
  /// Call once per frame before `controller.advanceFrame(dt)`.
  void pumpHeldInputs() {
    _scheduleHeldMoveAxis();
    _scheduleHeldProjectileAimDir();
    _scheduleHeldMeleeAimDir();
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
