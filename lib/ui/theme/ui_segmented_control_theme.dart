import 'package:flutter/material.dart';

import 'ui_tokens.dart';

enum AppSegmentedControlSize { sm, md }

@immutable
class UiSegmentedControlTheme extends ThemeExtension<UiSegmentedControlTheme> {
  const UiSegmentedControlTheme({
    required this.background,
    required this.selectedBackground,
    required this.foreground,
    required this.selectedForeground,
    required this.border,
    required this.sizes,
    required this.text,
    this.disabledAlpha = 0.45,
    this.pressedOverlayAlpha = 0.12,
    this.hoverOverlayAlpha = 0.08,
    this.showSelectedIcon = false,
  });

  final Color background;
  final Color selectedBackground;
  final Color foreground;
  final Color selectedForeground;
  final Color border;

  final UiSegmentedControlSizes sizes;
  final UiSegmentedControlTextStyles text;

  final double disabledAlpha;
  final double pressedOverlayAlpha;
  final double hoverOverlayAlpha;
  final bool showSelectedIcon;

  static const UiSegmentedControlTheme standard = UiSegmentedControlTheme(
    background: Colors.transparent,
    selectedBackground: Colors.white,
    foreground: Colors.white,
    selectedForeground: Colors.black,
    border: Colors.white,
    sizes: UiSegmentedControlSizes(
      sm: UiSegmentedControlSizeMetrics(height: 32, paddingHorizontal: 8),
      md: UiSegmentedControlSizeMetrics(height: 48, paddingHorizontal: 16),
    ),
    text: UiSegmentedControlTextStyles(
      sm: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      md: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    ),
  );

  UiSegmentedControlSpec resolveSpec({
    required UiTokens ui,
    required AppSegmentedControlSize size,
  }) {
    final metrics = sizes.metrics(size);

    return UiSegmentedControlSpec(
      height: metrics.height,
      padding: EdgeInsets.symmetric(horizontal: metrics.paddingHorizontal),
      radius: ui.radii.xl,
      textStyle: text.style(size).copyWith(letterSpacing: 1.2),
      showSelectedIcon: showSelectedIcon,
    );
  }

  @override
  UiSegmentedControlTheme copyWith({
    Color? background,
    Color? selectedBackground,
    Color? foreground,
    Color? selectedForeground,
    Color? border,
    UiSegmentedControlSizes? sizes,
    UiSegmentedControlTextStyles? text,
    double? disabledAlpha,
    double? pressedOverlayAlpha,
    double? hoverOverlayAlpha,
    bool? showSelectedIcon,
  }) {
    return UiSegmentedControlTheme(
      background: background ?? this.background,
      selectedBackground: selectedBackground ?? this.selectedBackground,
      foreground: foreground ?? this.foreground,
      selectedForeground: selectedForeground ?? this.selectedForeground,
      border: border ?? this.border,
      sizes: sizes ?? this.sizes,
      text: text ?? this.text,
      disabledAlpha: disabledAlpha ?? this.disabledAlpha,
      pressedOverlayAlpha: pressedOverlayAlpha ?? this.pressedOverlayAlpha,
      hoverOverlayAlpha: hoverOverlayAlpha ?? this.hoverOverlayAlpha,
      showSelectedIcon: showSelectedIcon ?? this.showSelectedIcon,
    );
  }

  @override
  UiSegmentedControlTheme lerp(
    ThemeExtension<UiSegmentedControlTheme>? other,
    double t,
  ) {
    if (other is! UiSegmentedControlTheme) return this;
    return t < 0.5 ? this : other;
  }
}

@immutable
class UiSegmentedControlSizes {
  const UiSegmentedControlSizes({required this.sm, required this.md});

  final UiSegmentedControlSizeMetrics sm;
  final UiSegmentedControlSizeMetrics md;

  UiSegmentedControlSizeMetrics metrics(AppSegmentedControlSize size) =>
      switch (size) {
        AppSegmentedControlSize.sm => sm,
        AppSegmentedControlSize.md => md,
      };
}

@immutable
class UiSegmentedControlSizeMetrics {
  const UiSegmentedControlSizeMetrics({
    required this.height,
    required this.paddingHorizontal,
  });

  final double height;
  final double paddingHorizontal;
}

@immutable
class UiSegmentedControlTextStyles {
  const UiSegmentedControlTextStyles({required this.sm, required this.md});

  final TextStyle sm;
  final TextStyle md;

  TextStyle style(AppSegmentedControlSize size) => switch (size) {
    AppSegmentedControlSize.sm => sm,
    AppSegmentedControlSize.md => md,
  };
}

@immutable
class UiSegmentedControlSpec {
  const UiSegmentedControlSpec({
    required this.height,
    required this.padding,
    required this.radius,
    required this.textStyle,
    required this.showSelectedIcon,
  });

  final double height;
  final EdgeInsetsGeometry padding;
  final double radius;
  final TextStyle textStyle;
  final bool showSelectedIcon;
}

extension UiSegmentedControlThemeContext on BuildContext {
  UiSegmentedControlTheme get segmentedControls =>
      Theme.of(this).extension<UiSegmentedControlTheme>() ??
      UiSegmentedControlTheme.standard;
}
