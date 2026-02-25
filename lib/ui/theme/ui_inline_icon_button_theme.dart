import 'package:flutter/material.dart';

import 'ui_tokens.dart';

enum AppInlineIconButtonVariant { discrete, success, danger }

enum AppInlineIconButtonSize { xs, sm }

@immutable
class UiInlineIconButtonTheme extends ThemeExtension<UiInlineIconButtonTheme> {
  const UiInlineIconButtonTheme({
    required this.discrete,
    required this.success,
    required this.danger,
    required this.sizes,
    this.disabledAlpha = 0.4,
  });

  final UiInlineIconButtonVariantTheme discrete;
  final UiInlineIconButtonVariantTheme success;
  final UiInlineIconButtonVariantTheme danger;

  final UiInlineIconButtonSizes sizes;

  final double disabledAlpha;

  static const UiInlineIconButtonTheme standard = UiInlineIconButtonTheme(
    discrete: UiInlineIconButtonVariantTheme(
      iconColor: UiBrandPalette.steelBlueMutedText,
    ),
    success: UiInlineIconButtonVariantTheme(
      iconColor: UiBrandPalette.mutedMossSuccess,
    ),
    danger: UiInlineIconButtonVariantTheme(
      iconColor: UiBrandPalette.crimsonDanger,
    ),
    sizes: UiInlineIconButtonSizes(
      xs: UiInlineIconButtonSizeMetrics(
        iconSize: 16,
        padding: EdgeInsets.zero,
        spinnerSize: 16,
        spinnerStrokeWidth: 2,
      ),
      sm: UiInlineIconButtonSizeMetrics(
        iconSize: 20,
        padding: EdgeInsets.all(4),
        spinnerSize: 16,
        spinnerStrokeWidth: 2,
      ),
    ),
  );

  UiInlineIconButtonVariantTheme variant(AppInlineIconButtonVariant variant) =>
      switch (variant) {
        AppInlineIconButtonVariant.discrete => discrete,
        AppInlineIconButtonVariant.success => success,
        AppInlineIconButtonVariant.danger => danger,
      };

  UiInlineIconButtonSpec resolveSpec({
    required UiTokens ui,
    required AppInlineIconButtonVariant variant,
    required AppInlineIconButtonSize size,
  }) {
    final v = this.variant(variant);
    final s = sizes.metrics(size);

    final iconColor = v.iconColor;
    final disabledColor = iconColor.withValues(alpha: disabledAlpha);

    return UiInlineIconButtonSpec(
      iconSize: s.iconSize,
      padding: s.padding,
      constraints: const BoxConstraints(),
      iconColor: iconColor,
      disabledColor: disabledColor,
      spinnerSize: s.spinnerSize,
      spinnerStrokeWidth: s.spinnerStrokeWidth,
      spinnerColor: iconColor,
      tapTarget: ui.sizes.tapTarget,
    );
  }

  @override
  UiInlineIconButtonTheme copyWith({
    UiInlineIconButtonVariantTheme? discrete,
    UiInlineIconButtonVariantTheme? success,
    UiInlineIconButtonVariantTheme? danger,
    UiInlineIconButtonSizes? sizes,
    double? disabledAlpha,
  }) {
    return UiInlineIconButtonTheme(
      discrete: discrete ?? this.discrete,
      success: success ?? this.success,
      danger: danger ?? this.danger,
      sizes: sizes ?? this.sizes,
      disabledAlpha: disabledAlpha ?? this.disabledAlpha,
    );
  }

  @override
  UiInlineIconButtonTheme lerp(
    ThemeExtension<UiInlineIconButtonTheme>? other,
    double t,
  ) {
    if (other is! UiInlineIconButtonTheme) return this;
    return t < 0.5 ? this : other;
  }
}

@immutable
class UiInlineIconButtonVariantTheme {
  const UiInlineIconButtonVariantTheme({required this.iconColor});

  final Color iconColor;
}

@immutable
class UiInlineIconButtonSizes {
  const UiInlineIconButtonSizes({required this.xs, required this.sm});

  final UiInlineIconButtonSizeMetrics xs;
  final UiInlineIconButtonSizeMetrics sm;

  UiInlineIconButtonSizeMetrics metrics(AppInlineIconButtonSize size) =>
      switch (size) {
        AppInlineIconButtonSize.xs => xs,
        AppInlineIconButtonSize.sm => sm,
      };
}

@immutable
class UiInlineIconButtonSizeMetrics {
  const UiInlineIconButtonSizeMetrics({
    required this.iconSize,
    required this.padding,
    required this.spinnerSize,
    required this.spinnerStrokeWidth,
  });

  final double iconSize;
  final EdgeInsets padding;
  final double spinnerSize;
  final double spinnerStrokeWidth;
}

@immutable
class UiInlineIconButtonSpec {
  const UiInlineIconButtonSpec({
    required this.iconSize,
    required this.padding,
    required this.constraints,
    required this.iconColor,
    required this.disabledColor,
    required this.spinnerSize,
    required this.spinnerStrokeWidth,
    required this.spinnerColor,
    required this.tapTarget,
  });

  final double iconSize;
  final EdgeInsets padding;
  final BoxConstraints constraints;
  final Color iconColor;
  final Color disabledColor;
  final double spinnerSize;
  final double spinnerStrokeWidth;
  final Color spinnerColor;

  /// For opt-in semantics sizing (e.g. using `Semantics` or tooltip). This does
  /// not constrain layout for dense inline buttons.
  final double tapTarget;
}

extension UiInlineIconButtonThemeContext on BuildContext {
  UiInlineIconButtonTheme get inlineIconButtons =>
      Theme.of(this).extension<UiInlineIconButtonTheme>() ??
      UiInlineIconButtonTheme.standard;
}
