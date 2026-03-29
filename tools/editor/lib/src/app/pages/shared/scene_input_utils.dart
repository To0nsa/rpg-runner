import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

final class SceneInputUtils {
  SceneInputUtils._();

  static bool isCtrlPressed() => HardwareKeyboard.instance.isControlPressed;

  static int zoomStepsFromScrollDeltaY(double deltaY) {
    if (deltaY.abs() <= 0) {
      return 0;
    }
    final rawSteps = (deltaY.abs() / 120.0).round();
    return rawSteps < 1 ? 1 : rawSteps;
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
