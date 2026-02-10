import 'dart:ui';

import 'package:flutter/foundation.dart';

@immutable
class ControlsTuning {
  const ControlsTuning({
    this.layout = const ControlsLayoutTuning(),
    this.style = const ControlsStyleTuning(),
  });

  /// Geometry and spacing configuration.
  final ControlsLayoutTuning layout;

  /// Colors, typography, and visual control styles.
  final ControlsStyleTuning style;

  static const defaults = ControlsTuning();
  static const fixed = defaults;
}

@immutable
class ControlsLayoutTuning {
  const ControlsLayoutTuning({
    this.edgePadding = 32,
    this.bottomEdgePadding = 16,
    this.buttonGap = 12,
    this.rowGap = 12,
    this.moveButtonWidth = 64,
    this.moveButtonHeight = 48,
    this.moveButtonGap = 8,
    this.jumpButtonScale = 1.6,
    this.actionButtonScale = 1.0,
    this.directionalButtonScale = 1.0,
    this.directionalDeadzoneScale = 1.0,
    this.ringGapScale = 0.9,
    this.radialStartDeg = 160.0,
    this.radialStepDeg = 35.0,
    this.dashStepMultiplier = -0.4,
    this.meleeStepMultiplier = 3.8,
    this.secondaryStepMultiplier = 1.0,
    this.projectileStepMultiplier = 2.4,
    this.bonusVerticalOffset = 72.0,
    this.chargeAnchorGap = 8.0,
  });

  final double edgePadding;
  final double bottomEdgePadding;
  final double buttonGap;
  final double rowGap;

  final double moveButtonWidth;
  final double moveButtonHeight;
  final double moveButtonGap;

  final double jumpButtonScale;
  final double actionButtonScale;
  final double directionalButtonScale;
  final double directionalDeadzoneScale;
  final double ringGapScale;

  final double radialStartDeg;
  final double radialStepDeg;
  final double dashStepMultiplier;
  final double meleeStepMultiplier;
  final double secondaryStepMultiplier;
  final double projectileStepMultiplier;

  final double bonusVerticalOffset;
  final double chargeAnchorGap;
}

@immutable
class ControlsStyleTuning {
  const ControlsStyleTuning({
    this.moveButtonBackgroundColor = const Color(0x33000000),
    this.moveButtonForegroundColor = const Color(0xFFFFFFFF),
    this.moveButtonBorderColor = const Color(0x55FFFFFF),
    this.moveButtonBorderWidth = 1,
    this.moveButtonBorderRadius = 12,
    this.actionButton = const ActionButtonTuning(),
    this.directionalActionButton = const DirectionalActionButtonTuning(),
  });

  final Color moveButtonBackgroundColor;
  final Color moveButtonForegroundColor;
  final Color moveButtonBorderColor;
  final double moveButtonBorderWidth;
  final double moveButtonBorderRadius;

  final ActionButtonTuning actionButton;
  final DirectionalActionButtonTuning directionalActionButton;
}

@immutable
class ActionButtonTuning {
  const ActionButtonTuning({
    this.size = 52,
    this.backgroundColor = const Color(0x33000000),
    this.foregroundColor = const Color(0xFFFFFFFF),
    this.labelFontSize = 8,
    this.labelGap = 2,
  });

  final double size;
  final Color backgroundColor;
  final Color foregroundColor;
  final double labelFontSize;
  final double labelGap;
}

@immutable
class DirectionalActionButtonTuning {
  const DirectionalActionButtonTuning({
    this.size = 52,
    this.deadzoneRadius = 12,
    this.backgroundColor = const Color(0x33000000),
    this.foregroundColor = const Color(0xFFFFFFFF),
    this.labelFontSize = 8,
    this.labelGap = 2,
  });

  final double size;
  final double deadzoneRadius;
  final Color backgroundColor;
  final Color foregroundColor;
  final double labelFontSize;
  final double labelGap;
}
