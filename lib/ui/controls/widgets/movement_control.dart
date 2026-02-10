import 'package:flutter/material.dart';

import '../controls_tuning.dart';
import '../move_buttons.dart';

class MovementControl extends StatelessWidget {
  const MovementControl({
    super.key,
    required this.tuning,
    required this.onMoveAxis,
  });

  final ControlsTuning tuning;
  final ValueChanged<double> onMoveAxis;

  @override
  Widget build(BuildContext context) {
    final layout = tuning.layout;
    final style = tuning.style;
    return MoveButtons(
      onAxisChanged: onMoveAxis,
      buttonWidth: layout.moveButtonWidth,
      buttonHeight: layout.moveButtonHeight,
      gap: layout.moveButtonGap,
      backgroundColor: style.moveButtonBackgroundColor,
      foregroundColor: style.moveButtonForegroundColor,
      borderColor: style.moveButtonBorderColor,
      borderWidth: style.moveButtonBorderWidth,
      borderRadius: style.moveButtonBorderRadius,
    );
  }
}
