import 'dart:math' as math;

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
    required this.onRangedAimDir,
    required this.onRangedAimClear,
    required this.onRangedCommitted,
    required this.rangedAimPreview,
    required this.rangedAffordable,
    required this.rangedCooldownTicksLeft,
    required this.rangedCooldownTicksTotal,
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
  final void Function(double x, double y) onRangedAimDir;
  final VoidCallback onRangedAimClear;
  final VoidCallback onRangedCommitted;
  final AimPreviewModel rangedAimPreview;
  final bool rangedAffordable;
  final int rangedCooldownTicksLeft;
  final int rangedCooldownTicksTotal;
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
    final jumpSize = action.size * 1.50;
    final smallActionSize = action.size * 0.85;
    final smallDirectionalSize = directional.size * 0.85;
    final smallDeadzoneRadius = directional.deadzoneRadius * 0.85;

    Offset polar(double radius, double degrees) {
      final radians = degrees * math.pi / 180.0;
      return Offset(math.cos(radians) * radius, math.sin(radians) * radius);
    }

    double rightFor(Offset centerOffset, double targetSize) {
      return t.edgePadding + jumpSize * 0.5 - centerOffset.dx - targetSize * 0.5;
    }

    double bottomFor(Offset centerOffset, double targetSize) {
      return t.edgePadding + jumpSize * 0.5 - centerOffset.dy - targetSize * 0.5;
    }

    final jumpRadius = jumpSize * 0.5;
    final arcGap = t.buttonGap * 0.8;
    final arcRadius = jumpRadius + smallDirectionalSize * 0.5 + arcGap;
    final dashRadius = jumpRadius + smallActionSize * 0.5 + arcGap;

    final dashOffset = polar(dashRadius, 160);
    final meleeOffset = polar(arcRadius, 200);
    final spellOffset = polar(arcRadius, 240);
    final throwOffset = polar(arcRadius, 280);

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
          right: rightFor(throwOffset, smallDirectionalSize),
          bottom: bottomFor(throwOffset, smallDirectionalSize),
          child: DirectionalActionButton(
            label: 'Throw',
            icon: Icons.near_me,
            onAimDir: onRangedAimDir,
            onAimClear: onRangedAimClear,
            onCommit: onRangedCommitted,
            projectileAimPreview: rangedAimPreview,
            affordable: rangedAffordable,
            cooldownTicksLeft: rangedCooldownTicksLeft,
            cooldownTicksTotal: rangedCooldownTicksTotal,
            size: smallDirectionalSize,
            deadzoneRadius: smallDeadzoneRadius,
            backgroundColor: directional.backgroundColor,
            foregroundColor: directional.foregroundColor,
            labelFontSize: directional.labelFontSize,
            labelGap: directional.labelGap,
          ),
        ),
        Positioned(
          right: rightFor(spellOffset, smallDirectionalSize),
          bottom: bottomFor(spellOffset, smallDirectionalSize),
          child: DirectionalActionButton(
            label: 'Spell',
            icon: Icons.auto_awesome,
            onAimDir: onProjectileAimDir,
            onAimClear: onProjectileAimClear,
            onCommit: onCastCommitted,
            projectileAimPreview: projectileAimPreview,
            affordable: projectileAffordable,
            cooldownTicksLeft: projectileCooldownTicksLeft,
            cooldownTicksTotal: projectileCooldownTicksTotal,
            size: smallDirectionalSize,
            deadzoneRadius: smallDeadzoneRadius,
            backgroundColor: directional.backgroundColor,
            foregroundColor: directional.foregroundColor,
            labelFontSize: directional.labelFontSize,
            labelGap: directional.labelGap,
          ),
        ),
        Positioned(
          right: rightFor(meleeOffset, smallDirectionalSize),
          bottom: bottomFor(meleeOffset, smallDirectionalSize),
          child: DirectionalActionButton(
            label: 'Atk',
            icon: Icons.close,
            onAimDir: onMeleeAimDir,
            onAimClear: onMeleeAimClear,
            onCommit: onMeleeCommitted,
            projectileAimPreview: meleeAimPreview,
            affordable: meleeAffordable,
            cooldownTicksLeft: meleeCooldownTicksLeft,
            cooldownTicksTotal: meleeCooldownTicksTotal,
            size: smallDirectionalSize,
            deadzoneRadius: smallDeadzoneRadius,
            backgroundColor: directional.backgroundColor,
            foregroundColor: directional.foregroundColor,
            labelFontSize: directional.labelFontSize,
            labelGap: directional.labelGap,
          ),
        ),
        Positioned(
          right: rightFor(dashOffset, smallActionSize),
          bottom: bottomFor(dashOffset, smallActionSize),
          child: ActionButton(
            label: 'Dash',
            icon: Icons.flash_on,
            onPressed: onDashPressed,
            affordable: dashAffordable,
            cooldownTicksLeft: dashCooldownTicksLeft,
            cooldownTicksTotal: dashCooldownTicksTotal,
            size: smallActionSize,
            backgroundColor: action.backgroundColor,
            foregroundColor: action.foregroundColor,
            labelFontSize: action.labelFontSize,
            labelGap: action.labelGap,
          ),
        ),
        Positioned(
          right: t.edgePadding,
          bottom: t.edgePadding,
          child: ActionButton(
            label: 'Jump',
            icon: Icons.arrow_upward,
            onPressed: onJumpPressed,
            affordable: jumpAffordable,
            size: jumpSize,
            backgroundColor: action.backgroundColor,
            foregroundColor: action.foregroundColor,
            labelFontSize: action.labelFontSize,
            labelGap: action.labelGap,
          ),
        ),
      ],
    );
  }
}
