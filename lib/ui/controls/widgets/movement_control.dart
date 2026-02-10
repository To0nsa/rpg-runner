import 'package:flutter/material.dart';

import '../controls_tuning.dart';
import '../move_buttons.dart';

/// Adapter that binds movement callbacks to tuned `MoveButtons` visuals.
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
    return MoveButtons(onAxisChanged: onMoveAxis, tuning: tuning.moveButtons);
  }
}
