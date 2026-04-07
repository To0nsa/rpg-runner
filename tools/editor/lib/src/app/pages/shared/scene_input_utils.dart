import 'package:flutter/gestures.dart'
    show PointerScrollEvent, PointerSignalEvent, kPrimaryButton;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Shared pointer/keyboard input semantics for editor scene surfaces.
///
/// Keeping these mappings centralized prevents control drift between routes.
final class SceneInputUtils {
  SceneInputUtils._();

  static bool isCtrlPressed() => HardwareKeyboard.instance.isControlPressed;

  static bool isPrimaryButtonPressed(int buttons) {
    return (buttons & kPrimaryButton) != 0;
  }

  static bool shouldPanWithPrimaryDrag(int buttons) {
    return isCtrlPressed() && isPrimaryButtonPressed(buttons);
  }

  static int zoomStepsFromScrollDeltaY(double deltaY) {
    // 120px wheel delta is treated as one logical zoom step, matching common
    // desktop wheel increments while still handling high-resolution devices.
    if (deltaY.abs() <= 0) {
      return 0;
    }
    final rawSteps = (deltaY.abs() / 120.0).round();
    return rawSteps < 1 ? 1 : rawSteps;
  }

  static int signedZoomStepsFromCtrlScroll(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) {
      return 0;
    }
    if (!isCtrlPressed()) {
      return 0;
    }
    final steps = zoomStepsFromScrollDeltaY(event.scrollDelta.dy);
    if (steps < 1) {
      return 0;
    }
    return event.scrollDelta.dy < 0 ? steps : -steps;
  }

  static void panScrollControllers({
    required ScrollController horizontal,
    required ScrollController vertical,
    required Offset pointerDelta,
  }) {
    if (!horizontal.hasClients || !vertical.hasClients) {
      return;
    }
    final horizontalPosition = horizontal.position;
    final verticalPosition = vertical.position;
    final nextX = (horizontal.offset - pointerDelta.dx).clamp(
      0.0,
      horizontalPosition.maxScrollExtent,
    );
    final nextY = (vertical.offset - pointerDelta.dy).clamp(
      0.0,
      verticalPosition.maxScrollExtent,
    );
    horizontal.jumpTo(nextX);
    vertical.jumpTo(nextY);
  }
}
