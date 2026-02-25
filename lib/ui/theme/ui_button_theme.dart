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
      background: Color(0xFF2A2018),
      foreground: Color(0xFFFFE8BD),
      border: Color(0xFFC8A66B),
      surfaceTop: Color(0xFF5A4327),
      surfaceBottom: Color(0xFF1E150F),
      insetTop: Color(0xFF3A2B1B),
      insetBottom: Color(0xFF140E0A),
      insetBorder: Color(0xFFE3C688),
      shadow: Color(0xCC000000),
      glow: Color(0x66C8A66B),
    ),
    secondary: UiButtonVariantTheme(
      background: Color(0xFF2D2F36),
      foreground: Color(0xFFE8E9EB),
      border: Color(0xFF8C909A),
      surfaceTop: Color(0xFF4E515D),
      surfaceBottom: Color(0xFF1C1E24),
      insetTop: Color(0xFF343742),
      insetBottom: Color(0xFF17191E),
      insetBorder: Color(0xFFBEC5D0),
      shadow: Color(0xB3000000),
      glow: Color(0x3D8C909A),
    ),
    danger: UiButtonVariantTheme(
      background: Color(0xFF3A1212),
      foreground: Color(0xFFFFE7E1),
      border: Color(0xFFD06D5D),
      surfaceTop: Color(0xFF7A2921),
      surfaceBottom: Color(0xFF270B0B),
      insetTop: Color(0xFF551A17),
      insetBottom: Color(0xFF1A0707),
      insetBorder: Color(0xFFF29B84),
      shadow: Color(0xCC000000),
      glow: Color(0x52D06D5D),
    ),
    sizes: UiButtonSizes(
      xxs: UiButtonSizeMetrics(width: 96, height: 48),
      xs: UiButtonSizeMetrics(width: 120, height: 48),
      sm: UiButtonSizeMetrics(width: 144, height: 48),
      md: UiButtonSizeMetrics(width: 160, height: 48),
      lg: UiButtonSizeMetrics(width: 192, height: 48),
    ),
    text: UiButtonTextStyles(
      xxs: TextStyle(
        fontFamily: 'CrimsonText',
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
      xs: TextStyle(
        fontFamily: 'CrimsonText',
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
      sm: TextStyle(
        fontFamily: 'CrimsonText',
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
      md: TextStyle(
        fontFamily: 'CrimsonText',
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
      lg: TextStyle(
        fontFamily: 'CrimsonText',
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
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
      surfaceTop: variantTheme.surfaceTop,
      surfaceBottom: variantTheme.surfaceBottom,
      insetTop: variantTheme.insetTop,
      insetBottom: variantTheme.insetBottom,
      insetBorder: variantTheme.insetBorder,
      shadow: variantTheme.shadow,
      glow: variantTheme.glow,
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
    Color? surfaceTop,
    Color? surfaceBottom,
    Color? insetTop,
    Color? insetBottom,
    Color? insetBorder,
    Color? shadow,
    Color? glow,
  }) : surfaceTop = surfaceTop ?? background,
       surfaceBottom = surfaceBottom ?? background,
       insetTop = insetTop ?? background,
       insetBottom = insetBottom ?? background,
       insetBorder = insetBorder ?? border,
       shadow = shadow ?? const Color(0xB3000000),
       glow = glow ?? Colors.transparent;

  final Color background;
  final Color foreground;
  final Color border;
  final Color surfaceTop;
  final Color surfaceBottom;
  final Color insetTop;
  final Color insetBottom;
  final Color insetBorder;
  final Color shadow;
  final Color glow;
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
    required this.surfaceTop,
    required this.surfaceBottom,
    required this.insetTop,
    required this.insetBottom,
    required this.insetBorder,
    required this.shadow,
    required this.glow,
  });

  final double width;
  final double height;
  final EdgeInsetsGeometry padding;
  final TextStyle textStyle;
  final Color background;
  final Color foreground;
  final Color border;
  final Color surfaceTop;
  final Color surfaceBottom;
  final Color insetTop;
  final Color insetBottom;
  final Color insetBorder;
  final Color shadow;
  final Color glow;
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
