import 'package:flutter/material.dart';

import 'ui_tokens.dart';

enum AppButtonVariant { primary, secondary, danger }

enum AppButtonSize { xxs, xs, sm, md, lg }

@immutable
class UiButtonTheme extends ThemeExtension<UiButtonTheme> {
  const UiButtonTheme({
    required this.primary,
    required this.secondary,
    required this.danger,
    required this.sizes,
    required this.text,
    this.disabledBackgroundAlpha = 0.4,
    this.disabledForegroundAlpha = 0.5,
    this.disabledBorderAlpha = 0.4,
    this.pressedOverlayAlpha = 0.12,
    this.hoverOverlayAlpha = 0.08,
  });

  final UiButtonVariantTheme primary;
  final UiButtonVariantTheme secondary;
  final UiButtonVariantTheme danger;
  final UiButtonSizes sizes;
  final UiButtonTextStyles text;

  final double disabledBackgroundAlpha;
  final double disabledForegroundAlpha;
  final double disabledBorderAlpha;
  final double pressedOverlayAlpha;
  final double hoverOverlayAlpha;

  static const UiButtonTheme standard = UiButtonTheme(
    primary: UiButtonVariantTheme(
      background: Colors.black,
      foreground: Colors.white,
      border: Colors.white,
    ),
    secondary: UiButtonVariantTheme(
      background: Colors.white,
      foreground: Colors.black,
      border: Colors.black,
    ),
    danger: UiButtonVariantTheme(
      background: Colors.redAccent,
      foreground: Colors.white,
      border: Colors.redAccent,
    ),
    sizes: UiButtonSizes(
      xxs: UiButtonSizeMetrics(width: 96, height: 48),
      xs: UiButtonSizeMetrics(width: 120, height: 48),
      sm: UiButtonSizeMetrics(width: 144, height: 48),
      md: UiButtonSizeMetrics(width: 160, height: 48),
      lg: UiButtonSizeMetrics(width: 192, height: 48),
    ),
    text: UiButtonTextStyles(
      xxs: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      xs: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      sm: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      md: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      lg: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    ),
  );

  UiButtonVariantTheme variant(AppButtonVariant variant) => switch (variant) {
    AppButtonVariant.primary => primary,
    AppButtonVariant.secondary => secondary,
    AppButtonVariant.danger => danger,
  };

  UiButtonSpec resolveSpec({
    required UiTokens ui,
    required AppButtonVariant variant,
    required AppButtonSize size,
  }) {
    final variantTheme = this.variant(variant);
    return UiButtonSpec(
      width: sizes.width(size),
      height: sizes.height(size),
      padding: EdgeInsets.symmetric(horizontal: ui.space.md, vertical: 10),
      textStyle: text.style(size),
      background: variantTheme.background,
      foreground: variantTheme.foreground,
      border: variantTheme.border,
    );
  }

  @override
  UiButtonTheme copyWith({
    UiButtonVariantTheme? primary,
    UiButtonVariantTheme? secondary,
    UiButtonVariantTheme? danger,
    UiButtonSizes? sizes,
    UiButtonTextStyles? text,
    double? disabledBackgroundAlpha,
    double? disabledForegroundAlpha,
    double? disabledBorderAlpha,
    double? pressedOverlayAlpha,
    double? hoverOverlayAlpha,
  }) {
    return UiButtonTheme(
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      danger: danger ?? this.danger,
      sizes: sizes ?? this.sizes,
      text: text ?? this.text,
      disabledBackgroundAlpha:
          disabledBackgroundAlpha ?? this.disabledBackgroundAlpha,
      disabledForegroundAlpha:
          disabledForegroundAlpha ?? this.disabledForegroundAlpha,
      disabledBorderAlpha: disabledBorderAlpha ?? this.disabledBorderAlpha,
      pressedOverlayAlpha: pressedOverlayAlpha ?? this.pressedOverlayAlpha,
      hoverOverlayAlpha: hoverOverlayAlpha ?? this.hoverOverlayAlpha,
    );
  }

  @override
  UiButtonTheme lerp(ThemeExtension<UiButtonTheme>? other, double t) {
    if (other is! UiButtonTheme) return this;
    return t < 0.5 ? this : other;
  }
}

@immutable
class UiButtonVariantTheme {
  const UiButtonVariantTheme({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;
}

@immutable
class UiButtonSizes {
  const UiButtonSizes({
    required this.xxs,
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
  });

  final UiButtonSizeMetrics xxs;
  final UiButtonSizeMetrics xs;
  final UiButtonSizeMetrics sm;
  final UiButtonSizeMetrics md;
  final UiButtonSizeMetrics lg;

  double width(AppButtonSize size) => switch (size) {
    AppButtonSize.xxs => xxs.width,
    AppButtonSize.xs => xs.width,
    AppButtonSize.sm => sm.width,
    AppButtonSize.md => md.width,
    AppButtonSize.lg => lg.width,
  };

  double height(AppButtonSize size) => switch (size) {
    AppButtonSize.xxs => xxs.height,
    AppButtonSize.xs => xs.height,
    AppButtonSize.sm => sm.height,
    AppButtonSize.md => md.height,
    AppButtonSize.lg => lg.height,
  };
}

@immutable
class UiButtonSizeMetrics {
  const UiButtonSizeMetrics({required this.width, required this.height});

  final double width;
  final double height;
}

@immutable
class UiButtonSpec {
  const UiButtonSpec({
    required this.width,
    required this.height,
    required this.padding,
    required this.textStyle,
    required this.background,
    required this.foreground,
    required this.border,
  });

  final double width;
  final double height;
  final EdgeInsetsGeometry padding;
  final TextStyle textStyle;
  final Color background;
  final Color foreground;
  final Color border;
}

@immutable
class UiButtonTextStyles {
  const UiButtonTextStyles({
    required this.xxs,
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
  });

  final TextStyle xxs;
  final TextStyle xs;
  final TextStyle sm;
  final TextStyle md;
  final TextStyle lg;

  TextStyle style(AppButtonSize size) => switch (size) {
    AppButtonSize.xxs => xxs,
    AppButtonSize.xs => xs,
    AppButtonSize.sm => sm,
    AppButtonSize.md => md,
    AppButtonSize.lg => lg,
  };
}

extension UiButtonThemeContext on BuildContext {
  UiButtonTheme get buttons =>
      Theme.of(this).extension<UiButtonTheme>() ?? UiButtonTheme.standard;
}
