import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/snapshots/enums.dart';
import '../../../game/input/aim_preview.dart';
import '../../haptics/haptics_service.dart';
import '../action_button.dart';
import '../controls_tuning.dart';
import '../directional_action_button.dart';
import '../hold_action_button.dart';

/// Resolves melee input mode (tap, hold-maintain, directional aim-release).
class MeleeControl extends StatelessWidget {
  const MeleeControl({
    super.key,
    required this.tuning,
    required this.inputMode,
    required this.size,
    required this.deadzoneRadius,
    required this.onPressed,
    required this.onHoldStart,
    required this.onHoldEnd,
    required this.onAimDir,
    required this.onAimClear,
    required this.onCommitted,
    required this.aimPreview,
    required this.affordable,
    required this.cooldownTicksLeft,
    required this.cooldownTicksTotal,
    required this.cancelHitboxRect,
    required this.haptics,
    required this.forceCancelSignal,
  });

  final ControlsTuning tuning;
  final AbilityInputMode inputMode;
  final double size;
  final double deadzoneRadius;

  final VoidCallback onPressed;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;
  final void Function(double x, double y) onAimDir;
  final VoidCallback onAimClear;
  final VoidCallback onCommitted;

  final AimPreviewModel aimPreview;
  final bool affordable;
  final int cooldownTicksLeft;
  final int cooldownTicksTotal;
  final ValueListenable<Rect?> cancelHitboxRect;
  final UiHaptics haptics;
  final ValueListenable<int> forceCancelSignal;

  @override
  Widget build(BuildContext context) {
    final action = tuning.style.actionButton;
    final directional = tuning.style.directionalActionButton;
    final cooldownRing = tuning.style.cooldownRing;
    if (inputMode == AbilityInputMode.tap) {
      return ActionButton(
        label: 'Atk',
        icon: Icons.close,
        onPressed: onPressed,
        tuning: action,
        cooldownRing: cooldownRing,
        affordable: affordable,
        cooldownTicksLeft: cooldownTicksLeft,
        cooldownTicksTotal: cooldownTicksTotal,
        size: size,
      );
    }
    if (inputMode == AbilityInputMode.holdMaintain) {
      return HoldActionButton(
        label: 'Atk',
        icon: Icons.close,
        onHoldStart: onHoldStart,
        onHoldEnd: onHoldEnd,
        tuning: action,
        cooldownRing: cooldownRing,
        affordable: affordable,
        cooldownTicksLeft: cooldownTicksLeft,
        cooldownTicksTotal: cooldownTicksTotal,
        size: size,
      );
    }
    return DirectionalActionButton(
      label: 'Atk',
      icon: Icons.close,
      onAimDir: onAimDir,
      onAimClear: onAimClear,
      onCommit: onCommitted,
      projectileAimPreview: aimPreview,
      tuning: directional,
      cooldownRing: cooldownRing,
      haptics: haptics,
      cancelHitboxRect: cancelHitboxRect,
      affordable: affordable,
      cooldownTicksLeft: cooldownTicksLeft,
      cooldownTicksTotal: cooldownTicksTotal,
      size: size,
      deadzoneRadius: deadzoneRadius,
      forceCancelSignal: forceCancelSignal,
    );
  }
}
