import 'package:flutter/material.dart';

import '../../game/input/aim_preview.dart';
import 'action_button.dart';
import 'controls_tuning.dart';
import 'directional_action_button.dart';
import 'fixed_joystick.dart';
import 'floating_joystick.dart';

class RunnerControlsOverlay extends StatelessWidget {
  const RunnerControlsOverlay({
    super.key,
    required this.onMoveAxis,
    required this.onJumpPressed,
    required this.onDashPressed,
    required this.onAttackPressed,
    required this.onCastCommitted,
    required this.onAimDir,
    required this.onAimClear,
    required this.aimPreview,
    this.tuning = ControlsTuning.v0Fixed,
  });

  final ValueChanged<double> onMoveAxis;
  final VoidCallback onJumpPressed;
  final VoidCallback onDashPressed;
  final VoidCallback onAttackPressed;
  final VoidCallback onCastCommitted;
  final void Function(double x, double y) onAimDir;
  final VoidCallback onAimClear;
  final AimPreviewModel aimPreview;
  final ControlsTuning tuning;

  @override
  Widget build(BuildContext context) {
    final t = tuning;
    final action = t.actionButton;
    final directional = t.directionalActionButton;

    return Stack(
      children: [
        Positioned(
          left: t.edgePadding,
          bottom: t.edgePadding,
          child: t.joystickKind == ControlsJoystickKind.floating
              ? FloatingJoystick(
                  onAxisChanged: onMoveAxis,
                  areaSize: t.floatingJoystick.areaSize,
                  baseSize: t.floatingJoystick.baseSize,
                  knobSize: t.floatingJoystick.knobSize,
                  followSmoothing: t.floatingJoystick.followSmoothing,
                  baseColor: t.floatingJoystick.baseColor,
                  baseBorderColor: t.floatingJoystick.baseBorderColor,
                  baseBorderWidth: t.floatingJoystick.baseBorderWidth,
                  knobColor: t.floatingJoystick.knobColor,
                  knobBorderColor: t.floatingJoystick.knobBorderColor,
                  knobBorderWidth: t.floatingJoystick.knobBorderWidth,
                )
              : FixedJoystick(
                  onAxisChanged: onMoveAxis,
                  size: t.fixedJoystick.size,
                  knobSize: t.fixedJoystick.knobSize,
                  baseColor: t.fixedJoystick.baseColor,
                  baseBorderColor: t.fixedJoystick.baseBorderColor,
                  baseBorderWidth: t.fixedJoystick.baseBorderWidth,
                  knobColor: t.fixedJoystick.knobColor,
                  knobBorderColor: t.fixedJoystick.knobBorderColor,
                  knobBorderWidth: t.fixedJoystick.knobBorderWidth,
                ),
        ),
        Positioned(
          right: t.edgePadding,
          bottom: t.edgePadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DirectionalActionButton(
                    label: 'Spell',
                    icon: Icons.auto_awesome,
                    onAimDir: onAimDir,
                    onAimClear: onAimClear,
                    onCommit: onCastCommitted,
                    aimPreview: aimPreview,
                    size: directional.size,
                    deadzoneRadius: directional.deadzoneRadius,
                    backgroundColor: directional.backgroundColor,
                    foregroundColor: directional.foregroundColor,
                    labelFontSize: directional.labelFontSize,
                    labelGap: directional.labelGap,
                  ),
                  SizedBox(width: t.buttonGap),
                  ActionButton(
                    label: 'Jump',
                    icon: Icons.arrow_upward,
                    onPressed: onJumpPressed,
                    size: action.size,
                    backgroundColor: action.backgroundColor,
                    foregroundColor: action.foregroundColor,
                    labelFontSize: action.labelFontSize,
                    labelGap: action.labelGap,
                  ),
                ],
              ),
              SizedBox(height: t.rowGap),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ActionButton(
                    label: 'Atk',
                    icon: Icons.close,
                    onPressed: onAttackPressed,
                    size: action.size,
                    backgroundColor: action.backgroundColor,
                    foregroundColor: action.foregroundColor,
                    labelFontSize: action.labelFontSize,
                    labelGap: action.labelGap,
                  ),
                  SizedBox(width: t.buttonGap),
                  ActionButton(
                    label: 'Dash',
                    icon: Icons.flash_on,
                    onPressed: onDashPressed,
                    size: action.size,
                    backgroundColor: action.backgroundColor,
                    foregroundColor: action.foregroundColor,
                    labelFontSize: action.labelFontSize,
                    labelGap: action.labelGap,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
