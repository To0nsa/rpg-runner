import 'package:flutter/widgets.dart';

import '../controls_tuning.dart';
import '../movement_control_mode.dart';

/// Canonical movement anchor, shared by the real HUD and spotlight authoring.
/// Floating input owns the lower-left activation area; fixed controls own only
/// their visible bounds plus the standard screen-edge insets.
class MovementControlPlacement extends StatelessWidget {
  const MovementControlPlacement({
    super.key,
    required this.mode,
    required this.child,
    this.layout = const ControlsLayoutTuning(),
  });
  final MovementControlMode mode;
  final ControlsLayoutTuning layout;
  final Widget child;

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: Align(
      alignment: Alignment.bottomLeft,
      child: FractionallySizedBox(
        widthFactor: mode == MovementControlMode.joystick ? 0.33 : null,
        heightFactor: mode == MovementControlMode.joystick ? 0.5 : null,
        child: Padding(
          padding: mode == MovementControlMode.joystick
              ? EdgeInsets.zero
              : EdgeInsets.only(
                  left: layout.edgePadding,
                  bottom: layout.bottomEdgePadding,
                ),
          child: child,
        ),
      ),
    ),
  );
}
