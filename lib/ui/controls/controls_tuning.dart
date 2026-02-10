import 'dart:ui';

import 'package:flutter/foundation.dart';

@immutable
class ControlsTuning {
  const ControlsTuning({
    this.edgePadding = 32,
    this.bottomEdgePadding = 16,
    this.buttonGap = 12,
    this.rowGap = 12,
    this.moveButtonWidth = 64,
    this.moveButtonHeight = 48,
    this.moveButtonGap = 8,
    this.moveButtonBackgroundColor = const Color(0x33000000),
    this.moveButtonForegroundColor = const Color(0xFFFFFFFF),
    this.moveButtonBorderColor = const Color(0x55FFFFFF),
    this.moveButtonBorderWidth = 1,
    this.moveButtonBorderRadius = 12,
    this.actionButton = const ActionButtonTuning(),
    this.directionalActionButton = const DirectionalActionButtonTuning(),
  });

  final double edgePadding;
  final double bottomEdgePadding;
  final double buttonGap;
  final double rowGap;

  final double moveButtonWidth;
  final double moveButtonHeight;
  final double moveButtonGap;
  final Color moveButtonBackgroundColor;
  final Color moveButtonForegroundColor;
  final Color moveButtonBorderColor;
  final double moveButtonBorderWidth;
  final double moveButtonBorderRadius;

  final ActionButtonTuning actionButton;
  final DirectionalActionButtonTuning directionalActionButton;

  static const defaults = ControlsTuning();
  static const fixed = defaults;
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
