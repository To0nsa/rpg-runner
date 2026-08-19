import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/snapshots/enums.dart';

import 'runner_gameplay_action.dart';
import 'runner_input_router.dart';

/// Resolves the authoritative interaction mode for a gameplay action.
///
/// The dispatcher calls this once when an action lifecycle begins and retains
/// the result until release or cancellation, so a mid-hold snapshot update
/// cannot change the meaning of the matching end edge.
typedef RunnerActionInputModeResolver =
    AbilityInputMode Function(RunnerGameplayAction action);

/// Converts device-neutral gameplay actions into router operations.
///
/// This layer owns ability-mode lifecycles and idempotent cancellation. It does
/// not import device APIs or enqueue Core commands; [RunnerInputRouter] remains
/// the only tick-scheduling boundary.
final class RunnerSemanticActionDispatcher {
  RunnerSemanticActionDispatcher({
    required RunnerInputRouter input,
    required RunnerActionInputModeResolver resolveInputMode,
  }) : _input = input,
       _resolveInputMode = resolveInputMode;

  final RunnerInputRouter _input;
  final RunnerActionInputModeResolver _resolveInputMode;
  final Map<RunnerGameplayAction, AbilityInputMode> _activeAbilityModes =
      <RunnerGameplayAction, AbilityInputMode>{};
  final Map<RunnerGameplayAction, AbilityInputMode> _endedBeforeCommitModes =
      <RunnerGameplayAction, AbilityInputMode>{};
  final Set<RunnerGameplayAction> _committedActions = <RunnerGameplayAction>{};

  double _axis = 0;
  bool _moveLeftHeld = false;
  bool _moveRightHeld = false;

  /// Sets the source-provided horizontal axis, clamped by the router.
  ///
  /// Digital left/right state takes precedence while either direction is held.
  void setMoveAxis(double axis) {
    _axis = axis;
    _syncMoveAxis();
  }

  /// Updates the quantized global aim direction used by aimed commits.
  void setAimDir(double x, double y) => _input.setAimDir(x, y);

  /// Clears the global aim direction.
  void clearAimDir() => _input.clearAimDir();

  /// Fires a touch-style one-shot action without creating pressed state.
  ///
  /// The current authoritative mode must be [AbilityInputMode.tap]. Held modes
  /// must use [beginAction] and an end, release, or cancel operation.
  void triggerAction(RunnerGameplayAction action) {
    _requireAbilityAction(action);
    final mode = _validatedMode(action);
    if (mode != AbilityInputMode.tap) {
      throw StateError(
        'runner_input_expected_tap: action=${action.name} mode=${mode.name}',
      );
    }
    _pressTap(action);
  }

  /// Begins a physical press or held touch action exactly once.
  ///
  /// Digital movement is recomputed from left/right state. Ability actions
  /// snapshot their current mode; OS repeat or duplicate pointer-down events
  /// are ignored until the lifecycle ends.
  void beginAction(RunnerGameplayAction action) {
    if (_beginMovement(action)) return;
    if (_activeAbilityModes.containsKey(action)) return;

    _endedBeforeCommitModes.remove(action);
    _committedActions.remove(action);
    final mode = _validatedMode(action);
    _activeAbilityModes[action] = mode;

    switch (mode) {
      case AbilityInputMode.tap:
        _pressTap(action);
      case AbilityInputMode.holdAimRelease:
      case AbilityInputMode.holdRelease:
        _input.startAbilitySlotHold(_slotFor(action));
      case AbilityInputMode.holdMaintain:
        _beginMaintainedAction(action);
    }
  }

  /// Commits an active release-mode action without ending its hold.
  ///
  /// Directional touch controls call this before [endAction]. Existing
  /// non-directional hold controls invoke it just after [endAction]; the
  /// dispatcher retains that single pending commit so both established touch
  /// callback orders produce the same action lifecycle.
  void commitAction(RunnerGameplayAction action) {
    final activeMode = _activeAbilityModes[action];
    final endedMode = activeMode == null
        ? _endedBeforeCommitModes.remove(action)
        : null;
    final mode = activeMode ?? endedMode;
    if (mode == null) return;
    if (!_isReleaseMode(mode)) {
      throw StateError(
        'runner_input_not_release_mode: action=${action.name} '
        'mode=${mode.name}',
      );
    }
    if (activeMode != null && !_committedActions.add(action)) return;
    _commitReleasedAction(action);
  }

  /// Ends an action without committing it.
  ///
  /// This is the cancel path for directional controls. For the existing
  /// non-directional hold-release callback order, an uncommitted release mode
  /// remains eligible for the immediately following [commitAction]. A new
  /// begin, explicit cancel, or [cancelAll] discards that eligibility.
  void endAction(RunnerGameplayAction action) {
    if (_endMovement(action)) return;

    final mode = _activeAbilityModes.remove(action);
    if (mode == null) return;
    if (mode != AbilityInputMode.tap) {
      _input.endAbilitySlotHold(_slotFor(action));
    }
    final committed = _committedActions.remove(action);
    if (_isReleaseMode(mode) && !committed) {
      _endedBeforeCommitModes[action] = mode;
    }
  }

  /// Commits, then ends, one physical action lifecycle.
  ///
  /// Desktop key/button release uses this method. Tap and hold-maintain modes
  /// only end; release modes preserve the router's same-tick aimed commit.
  void releaseAction(RunnerGameplayAction action) {
    if (_endMovement(action)) return;

    final mode = _activeAbilityModes[action];
    if (mode == null) return;
    if (_isReleaseMode(mode)) {
      commitAction(action);
    }
    endAction(action);
  }

  /// Ends one active action without a release commit.
  void cancelAction(RunnerGameplayAction action) {
    _endedBeforeCommitModes.remove(action);
    if (_endMovement(action)) return;

    final mode = _activeAbilityModes.remove(action);
    _committedActions.remove(action);
    if (mode != null && mode != AbilityInputMode.tap) {
      _input.endAbilitySlotHold(_slotFor(action));
    }
  }

  /// Neutralizes every gameplay input and pumps the neutral continuous state.
  ///
  /// The operation is idempotent and releases all supported ability slots even
  /// if adapter-local bookkeeping missed an earlier transition.
  void cancelAll() {
    _axis = 0;
    _moveLeftHeld = false;
    _moveRightHeld = false;
    _activeAbilityModes.clear();
    _endedBeforeCommitModes.clear();
    _committedActions.clear();

    _input.setMoveAxis(0);
    _input.clearAimDir();
    for (final slot in const <AbilitySlot>[
      AbilitySlot.primary,
      AbilitySlot.secondary,
      AbilitySlot.projectile,
      AbilitySlot.mobility,
    ]) {
      _input.endAbilitySlotHold(slot);
    }
    _input.pumpHeldInputs();
  }

  /// Pumps continuous movement and aim through the low-level router.
  void pumpHeldInputs() => _input.pumpHeldInputs();

  bool _beginMovement(RunnerGameplayAction action) {
    switch (action) {
      case RunnerGameplayAction.moveLeft:
        if (_moveLeftHeld) return true;
        _moveLeftHeld = true;
        _syncMoveAxis();
        return true;
      case RunnerGameplayAction.moveRight:
        if (_moveRightHeld) return true;
        _moveRightHeld = true;
        _syncMoveAxis();
        return true;
      case RunnerGameplayAction.jump:
      case RunnerGameplayAction.primary:
      case RunnerGameplayAction.secondary:
      case RunnerGameplayAction.projectile:
      case RunnerGameplayAction.spell:
      case RunnerGameplayAction.mobility:
        return false;
    }
  }

  bool _endMovement(RunnerGameplayAction action) {
    switch (action) {
      case RunnerGameplayAction.moveLeft:
        if (!_moveLeftHeld) return true;
        _moveLeftHeld = false;
        _syncMoveAxis();
        return true;
      case RunnerGameplayAction.moveRight:
        if (!_moveRightHeld) return true;
        _moveRightHeld = false;
        _syncMoveAxis();
        return true;
      case RunnerGameplayAction.jump:
      case RunnerGameplayAction.primary:
      case RunnerGameplayAction.secondary:
      case RunnerGameplayAction.projectile:
      case RunnerGameplayAction.spell:
      case RunnerGameplayAction.mobility:
        return false;
    }
  }

  void _syncMoveAxis() {
    final digitalAxis = switch ((_moveLeftHeld, _moveRightHeld)) {
      (true, false) => -1.0,
      (false, true) => 1.0,
      (true, true) => 0.0,
      (false, false) => _axis,
    };
    _input.setMoveAxis(digitalAxis);
  }

  AbilityInputMode _validatedMode(RunnerGameplayAction action) {
    final mode = _resolveInputMode(action);
    final supported = switch (action) {
      RunnerGameplayAction.moveLeft || RunnerGameplayAction.moveRight => false,
      RunnerGameplayAction.jump ||
      RunnerGameplayAction.spell => mode == AbilityInputMode.tap,
      RunnerGameplayAction.projectile => mode != AbilityInputMode.holdMaintain,
      RunnerGameplayAction.primary ||
      RunnerGameplayAction.secondary ||
      RunnerGameplayAction.mobility => true,
    };
    if (!supported) {
      throw UnsupportedError(
        'runner_input_unsupported_mode: action=${action.name} '
        'mode=${mode.name}',
      );
    }
    return mode;
  }

  void _requireAbilityAction(RunnerGameplayAction action) {
    if (action == RunnerGameplayAction.moveLeft ||
        action == RunnerGameplayAction.moveRight) {
      throw ArgumentError.value(
        action,
        'action',
        'movement actions require begin/end or an axis',
      );
    }
  }

  void _pressTap(RunnerGameplayAction action) {
    switch (action) {
      case RunnerGameplayAction.jump:
        _input.pressJump();
      case RunnerGameplayAction.primary:
        _input.pressStrike();
      case RunnerGameplayAction.secondary:
        _input.pressSecondary();
      case RunnerGameplayAction.projectile:
        _input.pressProjectile();
      case RunnerGameplayAction.spell:
        _input.pressSpell();
      case RunnerGameplayAction.mobility:
        _input.pressDash();
      case RunnerGameplayAction.moveLeft:
      case RunnerGameplayAction.moveRight:
        throw StateError('movement cannot be committed as a tap action');
    }
  }

  void _beginMaintainedAction(RunnerGameplayAction action) {
    switch (action) {
      case RunnerGameplayAction.primary:
        _input.startPrimaryHold();
      case RunnerGameplayAction.secondary:
        _input.startSecondaryHold();
      case RunnerGameplayAction.mobility:
        _input.startMobilityHold();
      case RunnerGameplayAction.projectile:
        throw UnsupportedError(
          'runner_input_unsupported_mode: action=${action.name} '
          'mode=${AbilityInputMode.holdMaintain.name}',
        );
      case RunnerGameplayAction.jump:
      case RunnerGameplayAction.spell:
      case RunnerGameplayAction.moveLeft:
      case RunnerGameplayAction.moveRight:
        throw StateError('${action.name} cannot be maintained');
    }
  }

  void _commitReleasedAction(RunnerGameplayAction action) {
    switch (action) {
      case RunnerGameplayAction.primary:
        _input.commitMeleeStrike();
      case RunnerGameplayAction.secondary:
        _input.commitSecondaryStrike();
      case RunnerGameplayAction.projectile:
        _input.commitProjectileWithAim(clearAim: true);
      case RunnerGameplayAction.mobility:
        _input.commitMobilityWithAim(clearAim: true);
      case RunnerGameplayAction.jump:
      case RunnerGameplayAction.spell:
      case RunnerGameplayAction.moveLeft:
      case RunnerGameplayAction.moveRight:
        throw StateError('${action.name} has no release commit');
    }
  }

  AbilitySlot _slotFor(RunnerGameplayAction action) {
    return switch (action) {
      RunnerGameplayAction.primary => AbilitySlot.primary,
      RunnerGameplayAction.secondary => AbilitySlot.secondary,
      RunnerGameplayAction.projectile => AbilitySlot.projectile,
      RunnerGameplayAction.mobility => AbilitySlot.mobility,
      RunnerGameplayAction.jump ||
      RunnerGameplayAction.spell ||
      RunnerGameplayAction.moveLeft ||
      RunnerGameplayAction.moveRight => throw StateError(
        '${action.name} has no held ability slot',
      ),
    };
  }

  bool _isReleaseMode(AbilityInputMode mode) =>
      mode == AbilityInputMode.holdAimRelease ||
      mode == AbilityInputMode.holdRelease;
}
