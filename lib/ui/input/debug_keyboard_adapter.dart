import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../game/input/runner_input_router.dart';

/// Debug-only keyboard adapter (not part of V0 mobile input).
///
/// Uses physical keys so WASD and arrow positions behave consistently across
/// layouts.
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
  final FocusNode _focusNode = FocusNode();
  final Set<PhysicalKeyboardKey> _keysPressed = <PhysicalKeyboardKey>{};

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (!widget.enabled) return KeyEventResult.ignored;

    if (event is KeyDownEvent) {
      final isNewPress = _keysPressed.add(event.physicalKey);
      if (isNewPress &&
          (event.physicalKey == PhysicalKeyboardKey.space ||
              event.physicalKey == PhysicalKeyboardKey.arrowUp ||
              event.physicalKey == PhysicalKeyboardKey.keyW)) {
        widget.input.pressJump();
      }
    } else if (event is KeyUpEvent) {
      _keysPressed.remove(event.physicalKey);
    }

    final heldLeft = _keysPressed.contains(PhysicalKeyboardKey.arrowLeft) ||
        _keysPressed.contains(PhysicalKeyboardKey.keyA);
    final heldRight = _keysPressed.contains(PhysicalKeyboardKey.arrowRight) ||
        _keysPressed.contains(PhysicalKeyboardKey.keyD);

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
    return Focus(
      autofocus: true,
      focusNode: _focusNode,
      onKeyEvent: _onKeyEvent,
      child: widget.child,
    );
  }
}

