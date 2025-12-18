import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../game/input/runner_input_router.dart';

/// Debug-only keyboard adapter (not part of V0 mobile input).
///
/// Supports BOTH:
/// - physical positions (WASD scan codes) for layout-agnostic behavior
/// - logical letters (ZQSD / WASD) for layout-friendly behavior (esp. Web/emulator quirks)
class DebugKeyboardAdapter extends StatefulWidget {
  const DebugKeyboardAdapter({
    super.key,
    required this.input,
    required this.child,
    this.enabled = kDebugMode,
  });

  final RunnerInputRouter input;
  final Widget child;
  final bool enabled;

  @override
  State<DebugKeyboardAdapter> createState() => _DebugKeyboardAdapterState();
}

class _DebugKeyboardAdapterState extends State<DebugKeyboardAdapter> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'DebugKeyboardAdapter');

  final Set<PhysicalKeyboardKey> _physDown = <PhysicalKeyboardKey>{};
  final Set<LogicalKeyboardKey> _logDown = <LogicalKeyboardKey>{};

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  bool _isDown({
    PhysicalKeyboardKey? physical,
    LogicalKeyboardKey? logical,
    Iterable<PhysicalKeyboardKey> physicalAny = const [],
    Iterable<LogicalKeyboardKey> logicalAny = const [],
  }) {
    if (physical != null && _physDown.contains(physical)) return true;
    if (logical != null && _logDown.contains(logical)) return true;
    for (final k in physicalAny) {
      if (_physDown.contains(k)) return true;
    }
    for (final k in logicalAny) {
      if (_logDown.contains(k)) return true;
    }
    return false;
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (!widget.enabled) return KeyEventResult.ignored;

    if (event is KeyDownEvent) {
      _physDown.add(event.physicalKey);
      _logDown.add(event.logicalKey);

      final jumpPressed = _isDown(
        physicalAny: const [
          PhysicalKeyboardKey.space,
          PhysicalKeyboardKey.arrowUp,
          PhysicalKeyboardKey.keyW, // WASD physical position
        ],
        logicalAny: const [
          LogicalKeyboardKey.space,
          LogicalKeyboardKey.arrowUp,
          LogicalKeyboardKey.keyW, // QWERTY letter
          LogicalKeyboardKey.keyZ, // AZERTY letter
        ],
      );

      // Only fire jump on the actual KeyDown event (not every frame)
      // but ignore repeats by checking event.repeat if you want.
      if (jumpPressed) {
        widget.input.pressJump();
      }
    } else if (event is KeyUpEvent) {
      _physDown.remove(event.physicalKey);
      _logDown.remove(event.logicalKey);
    }

    final heldLeft = _isDown(
      physicalAny: const [PhysicalKeyboardKey.arrowLeft, PhysicalKeyboardKey.keyA],
      logicalAny: const [LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.keyA, LogicalKeyboardKey.keyQ],
    );

    final heldRight = _isDown(
      physicalAny: const [PhysicalKeyboardKey.arrowRight, PhysicalKeyboardKey.keyD],
      logicalAny: const [LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.keyD],
    );

    if (heldLeft && !heldRight) {
      widget.input.setMoveAxis(-1);
    } else if (heldRight && !heldLeft) {
      widget.input.setMoveAxis(1);
    } else {
      widget.input.setMoveAxis(0);
    }

    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    // Crucial: clicking the game view should re-grab focus, otherwise KeyUp
    // can be missed and input feels “not continuous”.
    return Focus(
      autofocus: true,
      focusNode: _focusNode,
      onKeyEvent: _onKeyEvent,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => FocusScope.of(context).requestFocus(_focusNode),
        child: widget.child,
      ),
    );
  }
}
