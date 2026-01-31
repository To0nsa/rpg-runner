import 'dart:ui';

import 'package:flutter/foundation.dart';

enum ControlsJoystickKind { fixed, floating }

@immutable
class ControlsTuning {
  const ControlsTuning({
    this.edgePadding = 16,
    this.bottomEdgePadding = 16,
    this.buttonGap = 12,
    this.rowGap = 12,
    this.joystickKind = ControlsJoystickKind.floating,
    this.fixedJoystick = const FixedJoystickTuning(),
    this.floatingJoystick = const FloatingJoystickTuning(),
    this.actionButton = const ActionButtonTuning(),
    this.directionalActionButton = const DirectionalActionButtonTuning(),
  });

  final double edgePadding;
  final double bottomEdgePadding;
  final double buttonGap;
  final double rowGap;

  final ControlsJoystickKind joystickKind;
  final FixedJoystickTuning fixedJoystick;
  final FloatingJoystickTuning floatingJoystick;

  final ActionButtonTuning actionButton;
  final DirectionalActionButtonTuning directionalActionButton;

  static const floating = ControlsTuning();
  static const fixed = ControlsTuning(
    joystickKind: ControlsJoystickKind.fixed,
  );
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

@immutable
class FixedJoystickTuning {
  const FixedJoystickTuning({
    this.size = 120,
    this.knobSize = 56,
    this.baseColor = const Color(0x33000000),
    this.baseBorderColor = const Color(0x55FFFFFF),
    this.baseBorderWidth = 1,
    this.knobColor = const Color(0x66FFFFFF),
    this.knobBorderColor = const Color(0x88FFFFFF),
    this.knobBorderWidth = 1,
  });

  final double size;
  final double knobSize;
  final Color baseColor;
  final Color baseBorderColor;
  final double baseBorderWidth;
  final Color knobColor;
  final Color knobBorderColor;
  final double knobBorderWidth;
}

@immutable
class FloatingJoystickTuning {
  const FloatingJoystickTuning({
    this.areaSize = 220,
    this.baseSize = 120,
    this.knobSize = 56,
    this.followSmoothing = 0.25,
    this.baseColor = const Color(0x33000000),
    this.baseBorderColor = const Color(0x55FFFFFF),
    this.baseBorderWidth = 1,
    this.knobColor = const Color(0x66FFFFFF),
    this.knobBorderColor = const Color(0x88FFFFFF),
    this.knobBorderWidth = 1,
  });

  final double areaSize;
  final double baseSize;
  final double knobSize;
  final double followSmoothing;
  final Color baseColor;
  final Color baseBorderColor;
  final double baseBorderWidth;
  final Color knobColor;
  final Color knobBorderColor;
  final double knobBorderWidth;
}
