import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../theme/ui_world_palette.dart';

/// Root controls tuning bundle for HUD layout and visuals.
///
/// This object is pure UI configuration; it does not change gameplay rules.
@immutable
class ControlsTuning {
  const ControlsTuning({
    this.layout = const ControlsLayoutTuning(),
    this.style = const ControlsStyleTuning(),
    this.moveButtons = const MoveButtonsTuning(),
    this.moveJoystick = const MoveJoystickTuning(),
  });

  /// Geometry and spacing configuration.
  final ControlsLayoutTuning layout;

  /// Colors, typography, and visual control styles.
  final ControlsStyleTuning style;

  /// Move button geometry + visual tuning.
  final MoveButtonsTuning moveButtons;
  final MoveJoystickTuning moveJoystick;

  /// Baseline preset used by the run HUD.
  static const defaults = ControlsTuning();
  static const fixed = defaults;
}

/// Spatial tuning for radial control placement and scaling.
///
/// Angle values are degrees. Scale values are multiplicative factors applied to
/// base component sizes.
@immutable
class ControlsLayoutTuning {
  const ControlsLayoutTuning({
    this.edgePadding = 32,
    this.bottomEdgePadding = 16,
    this.buttonGap = 12,
    this.rowGap = 12,
    this.jumpButtonScale = 1.6,
    this.actionButtonScale = 1.0,
    this.directionalButtonScale = 1.0,
    this.directionalDeadzoneScale = 1.0,
    this.ringGapScale = 0.9,
    this.radialStartDeg = 160.0,
    this.radialStepDeg = 35.0,
    this.dashStepMultiplier = -0.4,
    this.meleeStepMultiplier = 1.0,
    this.secondaryStepMultiplier = 3.8,
    this.projectileStepMultiplier = 2.4,
    this.spellVerticalOffset = 72.0,
    this.chargeAnchorGap = 8.0,
  });

  final double edgePadding;
  final double bottomEdgePadding;
  final double buttonGap;
  final double rowGap;

  /// Scales applied to the base action/directional button dimensions.
  final double jumpButtonScale;
  final double actionButtonScale;
  final double directionalButtonScale;
  final double directionalDeadzoneScale;
  final double ringGapScale;

  /// Polar placement parameters (degrees).
  final double radialStartDeg;
  final double radialStepDeg;
  final double dashStepMultiplier;
  final double meleeStepMultiplier;
  final double secondaryStepMultiplier;
  final double projectileStepMultiplier;

  final double spellVerticalOffset;
  final double chargeAnchorGap;
}

/// Visual tuning for reusable control widgets.
@immutable
class ControlsStyleTuning {
  const ControlsStyleTuning({
    this.actionButton = const ActionButtonTuning(),
    this.directionalActionButton = const DirectionalActionButtonTuning(),
    this.cooldownRing = const CooldownRingTuning(),
    this.chargeBar = const ChargeBarTuning(),
  });

  final ActionButtonTuning actionButton;
  final DirectionalActionButtonTuning directionalActionButton;
  final CooldownRingTuning cooldownRing;
  final ChargeBarTuning chargeBar;
}

/// Geometry and paint tuning for the left/right movement pair.
@immutable
class MoveButtonsTuning {
  const MoveButtonsTuning({
    this.buttonWidth = 64,
    this.buttonHeight = 48,
    this.gap = 8,
    this.backgroundColor = const Color(0xA6151A1F),
    this.foregroundColor = UiWorldPalette.mist200,
    this.borderColor = UiWorldPalette.gold500,
    this.borderWidth = 1,
  });

  final double buttonWidth;
  final double buttonHeight;
  final double gap;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;
  final double borderWidth;
}

/// Floating horizontal joystick geometry in logical pixels. The deadzone only
/// selects neutral versus full-strength movement; it never scales speed.
@immutable
class MoveJoystickTuning {
  const MoveJoystickTuning({
    this.size = 96,
    this.thumbSize = 40,
    this.deadzone = 8,
  }) : assert(size > thumbSize),
       assert(thumbSize > 0),
       assert(deadzone >= 0 && deadzone < (size - thumbSize) / 2);

  final double size;
  final double thumbSize;
  final double deadzone;
}

/// Paint tuning for cooldown arcs drawn around circular buttons.
@immutable
class CooldownRingTuning {
  const CooldownRingTuning({
    this.thickness = 3,
    this.trackColor = const Color(0x6655616D),
    this.progressColor = UiWorldPalette.gold400,
  });

  final double thickness;
  final Color trackColor;
  final Color progressColor;
}

/// Visual tuning for the hold/charge progress bar above controls.
@immutable
class ChargeBarTuning {
  const ChargeBarTuning({
    this.width = 84,
    this.height = 14,
    this.padding = 2,
    this.backgroundColor = const Color(0xEB151A1F),
    this.borderColor = UiWorldPalette.gold600,
    this.borderWidth = 1,
    this.outerRadius = 2,
    this.innerRadius = 1,
    this.idleColor = UiWorldPalette.ash500,
    this.halfTierColor = UiWorldPalette.gold500,
    this.fullTierColor = UiWorldPalette.fog300,
  });

  final double width;
  final double height;
  final double padding;
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final double outerRadius;
  final double innerRadius;
  final Color idleColor;
  final Color halfTierColor;
  final Color fullTierColor;
}

/// Visual tuning for circular tap/hold action buttons.
@immutable
class ActionButtonTuning {
  const ActionButtonTuning({
    this.size = 52,
    this.backgroundColor = const Color(0x33000000),
    this.foregroundColor = const Color(0xFFFFFFFF),
  });

  final double size;
  final Color backgroundColor;
  final Color foregroundColor;
}

/// Visual tuning for directional action buttons and their deadzone radius.
@immutable
class DirectionalActionButtonTuning {
  const DirectionalActionButtonTuning({
    this.size = 52,
    this.deadzoneRadius = 12,
    this.backgroundColor = const Color(0x33000000),
    this.foregroundColor = const Color(0xFFFFFFFF),
  });

  final double size;
  final double deadzoneRadius;
  final Color backgroundColor;
  final Color foregroundColor;
}
