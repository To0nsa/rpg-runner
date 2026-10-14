import 'package:flutter/material.dart';

import '../controls_tuning.dart';
import '../move_buttons.dart';
import '../move_joystick.dart';
import '../movement_control_mode.dart';

/// Selects touch presentation and clears held movement when disabled or changed.
/// The run owner remains responsible for cancelling input when the run exits.
class MovementControl extends StatefulWidget {
  const MovementControl({
    super.key,
    required this.tuning,
    required this.onMoveAxis,
    this.mode = MovementControlMode.arrows,
    this.enabled = true,
    this.inputEpoch = 0,
  });

  final ControlsTuning tuning;
  final ValueChanged<double> onMoveAxis;
  final MovementControlMode mode;
  final bool enabled;

  /// A new epoch discards touches held across host input cancellation.
  final int inputEpoch;

  @override
  State<MovementControl> createState() => _MovementControlState();
}

class _MovementControlState extends State<MovementControl> {
  @override
  void didUpdateWidget(MovementControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode ||
        oldWidget.enabled != widget.enabled ||
        oldWidget.inputEpoch != widget.inputEpoch) {
      widget.onMoveAxis(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Replace pointer bookkeeping as well as neutralizing the routed axis.
    // A finger held across pause or a mode change must start a fresh gesture.
    return IgnorePointer(
      ignoring: !widget.enabled,
      child: KeyedSubtree(
        key: ValueKey((widget.mode, widget.enabled, widget.inputEpoch)),
        child: switch (widget.mode) {
          MovementControlMode.arrows => MoveButtons(
            onAxisChanged: widget.onMoveAxis,
            tuning: widget.tuning.moveButtons,
          ),
          MovementControlMode.joystick => MoveJoystick(
            onAxisChanged: widget.onMoveAxis,
            tuning: widget.tuning.moveJoystick,
            style: widget.tuning.moveButtons,
            restingPadding: EdgeInsets.only(
              left: widget.tuning.layout.edgePadding,
              bottom: widget.tuning.layout.bottomEdgePadding,
            ),
          ),
        },
      ),
    );
  }
}
