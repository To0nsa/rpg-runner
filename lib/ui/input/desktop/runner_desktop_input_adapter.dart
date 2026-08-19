import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../game/input/runner_gameplay_action.dart';
import '../../../game/input/runner_semantic_action_dispatcher.dart';
import 'runner_desktop_aim_geometry.dart';
import 'runner_desktop_bindings.dart';

/// Supplies the current fitted viewport and rendered player point for aim.
typedef RunnerDesktopAimGeometryResolver = RunnerDesktopAimGeometry? Function();

/// Owns local Windows keyboard, mouse, focus, and pressed-source state.
///
/// The controller translates only physical device transitions. Gameplay mode
/// semantics remain in [RunnerSemanticActionDispatcher], while pause/stop and
/// other host actions remain outside this adapter.
final class RunnerDesktopInputController {
  RunnerDesktopInputController({
    required RunnerSemanticActionDispatcher dispatcher,
    required RunnerDesktopAimGeometryResolver resolveAimGeometry,
    VoidCallback? onFocusLost,
    VoidCallback? onCancelPresentation,
    void Function(double x, double y)? onAimChanged,
    VoidCallback? onAimCleared,
  }) : _dispatcher = dispatcher,
       _resolveAimGeometry = resolveAimGeometry,
       _onFocusLost = onFocusLost,
       _onCancelPresentation = onCancelPresentation,
       _onAimChanged = onAimChanged,
       _onAimCleared = onAimCleared,
       focusNode = FocusNode(debugLabel: 'runner-desktop-gameplay') {
    for (final binding in RunnerDesktopBindings.keyboard) {
      _keyActions[binding.key] = binding.action;
    }
  }

  final RunnerSemanticActionDispatcher _dispatcher;
  final RunnerDesktopAimGeometryResolver _resolveAimGeometry;
  final VoidCallback? _onFocusLost;
  final VoidCallback? _onCancelPresentation;
  final void Function(double x, double y)? _onAimChanged;
  final VoidCallback? _onAimCleared;
  final Map<PhysicalKeyboardKey, RunnerGameplayAction> _keyActions =
      <PhysicalKeyboardKey, RunnerGameplayAction>{};
  final Set<PhysicalKeyboardKey> _pressedKeys = <PhysicalKeyboardKey>{};

  /// The adapter-local focus boundary; hosts must not share it with editors.
  final FocusNode focusNode;

  int _mouseButtons = 0;
  Offset? _pointerAimDirection;
  bool _hadFocus = false;
  bool _focusRequestPending = false;
  bool _enabled = true;
  bool _disposed = false;

  /// Enables or disables gameplay translation without changing focus ownership.
  ///
  /// Disabling immediately cancels every local and semantic input. This lets a
  /// host retain focus for pause/ready shortcuts without queuing gameplay under
  /// an overlay.
  void setEnabled(bool enabled) {
    if (_disposed || _enabled == enabled) return;
    _enabled = enabled;
    if (!enabled) cancelAll();
  }

  /// Requests gameplay focus after first clearing stale device state.
  void requestFocus() {
    if (_disposed || focusNode.hasFocus || _hadFocus || _focusRequestPending) {
      return;
    }
    cancelAll();
    _focusRequestPending = true;
    focusNode.requestFocus();
  }

  /// Cancels gameplay input and releases this adapter's local focus.
  void releaseFocus() {
    if (_disposed) return;
    cancelAll();
    _focusRequestPending = false;
    focusNode.unfocus();
  }

  /// Cancels gameplay input while retaining focus for host pause shortcuts.
  void cancelForPause() => cancelAll();

  /// Clears device bookkeeping and neutralizes every semantic input.
  ///
  /// This operation is safe to repeat from overlapping focus, pause, restart,
  /// stop, lifecycle, and disposal paths.
  void cancelAll() {
    if (_disposed) return;
    _pressedKeys.clear();
    _mouseButtons = 0;
    _pointerAimDirection = null;
    _dispatcher.cancelAll();
    _onCancelPresentation?.call();
  }

  /// Translates a focused physical key event into source-state transitions.
  KeyEventResult handleKeyEvent(KeyEvent event) {
    if (_disposed || !_enabled) return KeyEventResult.ignored;
    final action = _keyActions[event.physicalKey];
    if (action == null) return KeyEventResult.ignored;

    if (event is KeyRepeatEvent) {
      return KeyEventResult.handled;
    }

    final before = _activeSourceActions();
    if (event is KeyDownEvent) {
      if (!_pressedKeys.add(event.physicalKey)) {
        return KeyEventResult.handled;
      }
    } else if (event is KeyUpEvent) {
      if (!_pressedKeys.remove(event.physicalKey)) {
        return KeyEventResult.handled;
      }
    } else {
      return KeyEventResult.handled;
    }
    _applySourceTransitions(before, _activeSourceActions());
    return KeyEventResult.handled;
  }

  /// Handles focus transitions from [RunnerDesktopInputAdapter].
  void handleFocusChanged(bool hasFocus) {
    if (_disposed) return;
    if (hasFocus) {
      _focusRequestPending = false;
      _hadFocus = true;
      return;
    }
    _focusRequestPending = false;
    if (!_hadFocus) return;
    _hadFocus = false;
    cancelAll();
    _onFocusLost?.call();
  }

  /// Acquires focus and begins mouse actions only inside the fitted viewport.
  void handlePointerDown(Offset localPosition, int buttons) {
    if (_disposed) return;
    final geometry = _resolveAimGeometry();
    if (geometry == null || !geometry.contains(localPosition)) {
      _clearPointerAim();
      return;
    }
    requestFocus();
    if (!_enabled) return;
    _updateAim(localPosition, geometry: geometry);
    _updateMouseButtons(buttons, cancelReleased: false);
  }

  /// Releases mouse actions, preserving other keys/buttons for the same action.
  void handlePointerUp(Offset localPosition, int buttons) {
    if (_disposed || !_enabled) return;
    _updateAim(localPosition);
    _updateMouseButtons(buttons, cancelReleased: false);
  }

  /// Updates pointer-derived aim without changing held mouse actions.
  void handlePointerPosition(Offset localPosition) {
    if (_disposed || !_enabled) return;
    _updateAim(localPosition);
  }

  /// Cancels mouse-owned actions without producing release commits.
  void handlePointerCancel() {
    if (_disposed || !_enabled) return;
    _clearPointerAim();
    _updateMouseButtons(0, cancelReleased: true);
  }

  /// Clears pointer aim when the pointer leaves the adapter region.
  void handlePointerExit() {
    if (_disposed) return;
    _clearPointerAim();
  }

  /// Cancels input and disposes the single owned focus node.
  void dispose() {
    if (_disposed) return;
    cancelAll();
    _disposed = true;
    _hadFocus = false;
    _focusRequestPending = false;
    focusNode.dispose();
  }

  void _updateAim(Offset localPosition, {RunnerDesktopAimGeometry? geometry}) {
    final resolved = geometry ?? _resolveAimGeometry();
    final direction = resolved?.directionFor(localPosition);
    if (direction == null) {
      _clearPointerAim();
      return;
    }
    _pointerAimDirection = direction;
    _dispatcher.setAimDir(direction.dx, direction.dy);
    _onAimChanged?.call(direction.dx, direction.dy);
  }

  void _clearPointerAim() {
    _pointerAimDirection = null;
    _dispatcher.clearAimDir();
    _onAimCleared?.call();
  }

  void _applyPointerAim() {
    final direction = _pointerAimDirection;
    if (direction == null) return;
    _dispatcher.setAimDir(direction.dx, direction.dy);
  }

  void _updateMouseButtons(int buttons, {required bool cancelReleased}) {
    final nextButtons = buttons & _boundMouseButtonMask;
    if (nextButtons == _mouseButtons) return;
    final before = _activeSourceActions();
    _mouseButtons = nextButtons;
    _applySourceTransitions(
      before,
      _activeSourceActions(),
      cancelReleased: cancelReleased,
    );
  }

  Set<RunnerGameplayAction> _activeSourceActions() {
    final actions = <RunnerGameplayAction>{};
    for (final key in _pressedKeys) {
      final action = _keyActions[key];
      if (action != null) actions.add(action);
    }
    for (final binding in RunnerDesktopBindings.mouse) {
      if ((_mouseButtons & binding.buttons) != 0) {
        actions.add(binding.action);
      }
    }
    return actions;
  }

  void _applySourceTransitions(
    Set<RunnerGameplayAction> before,
    Set<RunnerGameplayAction> after, {
    bool cancelReleased = false,
  }) {
    for (final action in before.difference(after)) {
      if (cancelReleased) {
        _dispatcher.cancelAction(action);
      } else {
        _applyPointerAim();
        _dispatcher.releaseAction(action);
      }
    }
    for (final action in after.difference(before)) {
      _applyPointerAim();
      _dispatcher.beginAction(action);
    }
  }

  int get _boundMouseButtonMask {
    var mask = 0;
    for (final binding in RunnerDesktopBindings.mouse) {
      mask |= binding.buttons;
    }
    return mask;
  }
}

/// Focus-scoped widget that forwards local key and pointer events to a desktop
/// input controller.
///
/// Wrap only the intended gameplay surface. Host shortcuts should be installed
/// outside this widget so they never become semantic gameplay actions.
class RunnerDesktopInputAdapter extends StatelessWidget {
  const RunnerDesktopInputAdapter({
    super.key,
    required this.controller,
    required this.child,
  });

  final RunnerDesktopInputController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: controller.focusNode,
      onFocusChange: controller.handleFocusChanged,
      onKeyEvent: (_, event) => controller.handleKeyEvent(event),
      child: MouseRegion(
        onEnter: (event) {
          if (event.kind == PointerDeviceKind.mouse) {
            controller.handlePointerPosition(event.localPosition);
          }
        },
        onHover: (event) {
          if (event.kind == PointerDeviceKind.mouse) {
            controller.handlePointerPosition(event.localPosition);
          }
        },
        onExit: (event) {
          if (event.kind == PointerDeviceKind.mouse) {
            controller.handlePointerExit();
          }
        },
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
            if (event.kind == PointerDeviceKind.mouse) {
              controller.handlePointerDown(event.localPosition, event.buttons);
            }
          },
          onPointerMove: (event) {
            if (event.kind == PointerDeviceKind.mouse) {
              controller.handlePointerPosition(event.localPosition);
            }
          },
          onPointerUp: (event) {
            if (event.kind == PointerDeviceKind.mouse) {
              controller.handlePointerUp(event.localPosition, event.buttons);
            }
          },
          onPointerCancel: (event) {
            if (event.kind == PointerDeviceKind.mouse) {
              controller.handlePointerCancel();
            }
          },
          child: child,
        ),
      ),
    );
  }
}
