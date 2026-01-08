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
    required this.onCastCommitted,
    required this.onProjectileAimDir,
    required this.onProjectileAimClear,
    required this.projectileAimPreview,
    required this.projectileAffordable,
    required this.projectileCooldownTicksLeft,
    required this.projectileCooldownTicksTotal,
    required this.onMeleeAimDir,
    required this.onMeleeAimClear,
    required this.onMeleeCommitted,
    required this.meleeAimPreview,
    required this.meleeAffordable,
    required this.meleeCooldownTicksLeft,
    required this.meleeCooldownTicksTotal,
    required this.jumpAffordable,
    required this.dashAffordable,
    required this.dashCooldownTicksLeft,
    required this.dashCooldownTicksTotal,
    this.tuning = ControlsTuning.fixed,
  });

  final ValueChanged<double> onMoveAxis;
  final VoidCallback onJumpPressed;
  final VoidCallback onDashPressed;
  final VoidCallback onCastCommitted;
  final void Function(double x, double y) onProjectileAimDir;
  final VoidCallback onProjectileAimClear;
  final AimPreviewModel projectileAimPreview;
  final bool projectileAffordable;
  final int projectileCooldownTicksLeft;
  final int projectileCooldownTicksTotal;
  final void Function(double x, double y) onMeleeAimDir;
  final VoidCallback onMeleeAimClear;
  final VoidCallback onMeleeCommitted;
  final AimPreviewModel meleeAimPreview;
  final bool meleeAffordable;
  final int meleeCooldownTicksLeft;
  final int meleeCooldownTicksTotal;
  final bool jumpAffordable;
  final bool dashAffordable;
  final int dashCooldownTicksLeft;
  final int dashCooldownTicksTotal;
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
          bottom: t.bottomEdgePadding,
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
                    onAimDir: onProjectileAimDir,
                    onAimClear: onProjectileAimClear,
                    onCommit: onCastCommitted,
                    projectileAimPreview: projectileAimPreview,
                    affordable: projectileAffordable,
                    cooldownTicksLeft: projectileCooldownTicksLeft,
                    cooldownTicksTotal: projectileCooldownTicksTotal,
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
                    affordable: jumpAffordable,
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
                  DirectionalActionButton(
                    label: 'Atk',
                    icon: Icons.close,
                    onAimDir: onMeleeAimDir,
                    onAimClear: onMeleeAimClear,
                    onCommit: onMeleeCommitted,
                    projectileAimPreview: meleeAimPreview,
                    affordable: meleeAffordable,
                    cooldownTicksLeft: meleeCooldownTicksLeft,
                    cooldownTicksTotal: meleeCooldownTicksTotal,
                    size: directional.size,
                    deadzoneRadius: directional.deadzoneRadius,
                    backgroundColor: directional.backgroundColor,
                    foregroundColor: directional.foregroundColor,
                    labelFontSize: directional.labelFontSize,
                    labelGap: directional.labelGap,
                  ),
                  SizedBox(width: t.buttonGap),
                  ActionButton(
                    label: 'Dash',
                    icon: Icons.flash_on,
                    onPressed: onDashPressed,
                    affordable: dashAffordable,
                    cooldownTicksLeft: dashCooldownTicksLeft,
                    cooldownTicksTotal: dashCooldownTicksTotal,
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
