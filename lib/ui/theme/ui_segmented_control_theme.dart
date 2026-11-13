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
    required this.selectedBorder,
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
  final Color selectedBorder;

  final UiSegmentedControlSizes sizes;
  final UiSegmentedControlTextStyles text;

  final double disabledAlpha;
  final double pressedOverlayAlpha;
  final double hoverOverlayAlpha;
  final bool showSelectedIcon;

  static const UiSegmentedControlTheme standard = UiSegmentedControlTheme(
    background: UiBrandPalette.steelBlueInsetBottom,
    selectedBackground: UiBrandPalette.steelBlueInsetTop,
    foreground: UiBrandPalette.steelBlueMutedText,
    selectedForeground: UiBrandPalette.steelBlueForeground,
    border: UiBrandPalette.steelBlueSurfaceTop,
    selectedBorder: UiBrandPalette.wornGoldOutline,
    sizes: UiSegmentedControlSizes(
      sm: UiSegmentedControlSizeMetrics(height: 44, paddingHorizontal: 12),
      md: UiSegmentedControlSizeMetrics(height: 48, paddingHorizontal: 16),
    ),
    text: UiSegmentedControlTextStyles(
      sm: TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      md: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    ),
  );

  UiSegmentedControlSpec resolveSpec({
    required UiTokens ui,
    required AppSegmentedControlSize size,
  }) {
    final metrics = sizes.metrics(size);

    return UiSegmentedControlSpec(
      height: metrics.height,
      padding: EdgeInsets.symmetric(
        horizontal: metrics.paddingHorizontal,
        vertical: ui.space.xs,
      ),
      radius: ui.radii.md,
      segmentRadius: ui.radii.sm,
      inset: ui.space.xxs,
      spacing: ui.space.xxs,
      borderWidth: 1,
      textStyle: text.style(size).copyWith(letterSpacing: 0.2),
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
    Color? selectedBorder,
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
      selectedBorder: selectedBorder ?? this.selectedBorder,
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
    required this.segmentRadius,
    required this.inset,
    required this.spacing,
    required this.borderWidth,
    required this.textStyle,
    required this.showSelectedIcon,
  });

  final double height;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double segmentRadius;
  final double inset;
  final double spacing;
  final double borderWidth;
  final TextStyle textStyle;
  final bool showSelectedIcon;
}

extension UiSegmentedControlThemeContext on BuildContext {
  UiSegmentedControlTheme get segmentedControls =>
      Theme.of(this).extension<UiSegmentedControlTheme>() ??
      UiSegmentedControlTheme.standard;
}
