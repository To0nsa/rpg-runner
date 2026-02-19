import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../controls_tuning.dart';

/// Solves absolute control anchor positions for the radial HUD layout.
///
/// The solver keeps layout math centralized so widgets can focus on composition.
@immutable
class ControlsRadialLayout {
  const ControlsRadialLayout({
    required this.jumpSize,
    required this.actionSize,
    required this.directionalSize,
    required this.directionalDeadzoneRadius,
    required this.jump,
    required this.dash,
    required this.melee,
    required this.secondary,
    required this.projectile,
    required this.spell,
    required this.projectileCharge,
  });

  final double jumpSize;
  final double actionSize;
  final double directionalSize;
  final double directionalDeadzoneRadius;

  final ControlsAnchor jump;
  final ControlsAnchor dash;
  final ControlsAnchor melee;
  final ControlsAnchor secondary;
  final ControlsAnchor projectile;
  final ControlsAnchor spell;
  final ControlsAnchor projectileCharge;
}

@immutable
class ControlsAnchor {
  const ControlsAnchor({required this.right, required this.bottom});

  /// Distance in logical pixels from the right edge of the overlay.
  final double right;

  /// Distance in logical pixels from the bottom edge of the overlay.
  final double bottom;
}

/// Computes radial control anchors from authored layout numbers.
class ControlsRadialLayoutSolver {
  const ControlsRadialLayoutSolver._();

  static ControlsRadialLayout solve({
    required ControlsLayoutTuning layout,
    required ActionButtonTuning action,
    required DirectionalActionButtonTuning directional,
  }) {
    final jumpSize = action.size * layout.jumpButtonScale;
    final actionSize = action.size * layout.actionButtonScale;
    final directionalSize = directional.size * layout.directionalButtonScale;
    final directionalDeadzoneRadius =
        directional.deadzoneRadius * layout.directionalDeadzoneScale;

    Offset polar(double radius, double degrees) {
      final radians = degrees * math.pi / 180.0;
      return Offset(math.cos(radians) * radius, math.sin(radians) * radius);
    }

    double rightFor(Offset centerOffset, double targetSize) {
      return layout.edgePadding +
          jumpSize * 0.5 -
          centerOffset.dx -
          targetSize * 0.5;
    }

    double bottomFor(Offset centerOffset, double targetSize) {
      return layout.edgePadding +
          jumpSize * 0.5 -
          centerOffset.dy -
          targetSize * 0.5;
    }

    final jumpRadius = jumpSize * 0.5;
    final ringGap = layout.buttonGap * layout.ringGapScale;
    final ringRadius =
        jumpRadius + math.max(directionalSize, actionSize) * 0.5 + ringGap;

    final dashOffset = polar(
      ringRadius,
      layout.radialStartDeg + layout.radialStepDeg * layout.dashStepMultiplier,
    );
    final meleeOffset = polar(
      ringRadius,
      layout.radialStartDeg + layout.radialStepDeg * layout.meleeStepMultiplier,
    );
    final secondaryOffset = polar(
      ringRadius,
      layout.radialStartDeg +
          layout.radialStepDeg * layout.secondaryStepMultiplier,
    );
    final projectileOffset = polar(
      ringRadius,
      layout.radialStartDeg +
          layout.radialStepDeg * layout.projectileStepMultiplier,
    );

    final spellSize = actionSize;
    final spellRight = rightFor(secondaryOffset, spellSize);
    final spellBottom =
        bottomFor(secondaryOffset, spellSize) + layout.spellVerticalOffset;

    return ControlsRadialLayout(
      jumpSize: jumpSize,
      actionSize: actionSize,
      directionalSize: directionalSize,
      directionalDeadzoneRadius: directionalDeadzoneRadius,
      jump: ControlsAnchor(
        right: layout.edgePadding,
        bottom: layout.edgePadding,
      ),
      dash: ControlsAnchor(
        right: rightFor(dashOffset, actionSize),
        bottom: bottomFor(dashOffset, actionSize),
      ),
      melee: ControlsAnchor(
        right: rightFor(meleeOffset, directionalSize),
        bottom: bottomFor(meleeOffset, directionalSize),
      ),
      secondary: ControlsAnchor(
        right: rightFor(secondaryOffset, actionSize),
        bottom: bottomFor(secondaryOffset, actionSize),
      ),
      projectile: ControlsAnchor(
        right: rightFor(projectileOffset, directionalSize),
        bottom: bottomFor(projectileOffset, directionalSize),
      ),
      spell: ControlsAnchor(right: spellRight, bottom: spellBottom),
      projectileCharge: ControlsAnchor(
        right: rightFor(projectileOffset, directionalSize),
        bottom:
            bottomFor(projectileOffset, directionalSize) +
            directionalSize +
            layout.chargeAnchorGap,
      ),
    );
  }
}
