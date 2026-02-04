import 'package:flutter/material.dart';

import 'ui_tokens.dart';

enum AppIconButtonVariant { primary, secondary, danger }

enum AppIconButtonSize { sm, md, lg }

@immutable
class UiIconButtonTheme extends ThemeExtension<UiIconButtonTheme> {
  const UiIconButtonTheme({
    required this.primary,
    required this.secondary,
    required this.danger,
    required this.sizes,
    required this.text,
    this.disabledAlpha = 0.4,
  });

  final UiIconButtonVariantTheme primary;
  final UiIconButtonVariantTheme secondary;
  final UiIconButtonVariantTheme danger;

  final UiIconButtonSizes sizes;
  final UiIconButtonTextStyles text;

  final double disabledAlpha;

  static const UiIconButtonTheme standard = UiIconButtonTheme(
    primary: UiIconButtonVariantTheme(
      iconColor: Colors.white,
      labelColor: Colors.white70,
    ),
    secondary: UiIconButtonVariantTheme(
      iconColor: Colors.black,
      labelColor: Colors.black54,
    ),
    danger: UiIconButtonVariantTheme(
      iconColor: Colors.redAccent,
      labelColor: Colors.redAccent,
    ),
    sizes: UiIconButtonSizes(
      sm: UiIconButtonSizeMetrics(iconSize: 24),
      md: UiIconButtonSizeMetrics(iconSize: 32),
      lg: UiIconButtonSizeMetrics(iconSize: 40),
    ),
    text: UiIconButtonTextStyles(
      sm: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      md: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      lg: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
    ),
  );

  UiIconButtonVariantTheme variant(AppIconButtonVariant variant) =>
      switch (variant) {
        AppIconButtonVariant.primary => primary,
        AppIconButtonVariant.secondary => secondary,
        AppIconButtonVariant.danger => danger,
      };

  UiIconButtonSpec resolveSpec({
    required UiTokens ui,
    required AppIconButtonVariant variant,
    required AppIconButtonSize size,
  }) {
    final variantTheme = this.variant(variant);
    final sizeMetrics = sizes.metrics(size);
    final labelStyleBase = text.style(size);
    final disabledIconColor = variantTheme.iconColor.withValues(
      alpha: disabledAlpha,
    );
    final disabledLabelColor = variantTheme.labelColor.withValues(
      alpha: disabledAlpha,
    );

    return UiIconButtonSpec(
      iconSize: sizeMetrics.iconSize,
      constraints: BoxConstraints(
        minWidth: ui.sizes.tapTarget,
        minHeight: ui.sizes.tapTarget,
      ),
      labelSpacing: ui.space.xxs,
      iconColor: variantTheme.iconColor,
      disabledIconColor: disabledIconColor,
      labelStyle: labelStyleBase.copyWith(color: variantTheme.labelColor),
      disabledLabelStyle: labelStyleBase.copyWith(color: disabledLabelColor),
    );
  }

  @override
  UiIconButtonTheme copyWith({
    UiIconButtonVariantTheme? primary,
    UiIconButtonVariantTheme? secondary,
    UiIconButtonVariantTheme? danger,
    UiIconButtonSizes? sizes,
    UiIconButtonTextStyles? text,
    double? disabledAlpha,
  }) {
    return UiIconButtonTheme(
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      danger: danger ?? this.danger,
      sizes: sizes ?? this.sizes,
      text: text ?? this.text,
      disabledAlpha: disabledAlpha ?? this.disabledAlpha,
    );
  }

  @override
  UiIconButtonTheme lerp(ThemeExtension<UiIconButtonTheme>? other, double t) {
    if (other is! UiIconButtonTheme) return this;
    return t < 0.5 ? this : other;
  }
}

@immutable
class UiIconButtonVariantTheme {
  const UiIconButtonVariantTheme({
    required this.iconColor,
    required this.labelColor,
  });

  final Color iconColor;
  final Color labelColor;
}

@immutable
class UiIconButtonSizes {
  const UiIconButtonSizes({
    required this.sm,
    required this.md,
    required this.lg,
  });

  final UiIconButtonSizeMetrics sm;
  final UiIconButtonSizeMetrics md;
  final UiIconButtonSizeMetrics lg;

  UiIconButtonSizeMetrics metrics(AppIconButtonSize size) => switch (size) {
    AppIconButtonSize.sm => sm,
    AppIconButtonSize.md => md,
    AppIconButtonSize.lg => lg,
  };
}

@immutable
class UiIconButtonSizeMetrics {
  const UiIconButtonSizeMetrics({required this.iconSize});

  final double iconSize;
}

@immutable
class UiIconButtonTextStyles {
  const UiIconButtonTextStyles({
    required this.sm,
    required this.md,
    required this.lg,
  });

  final TextStyle sm;
  final TextStyle md;
  final TextStyle lg;

  TextStyle style(AppIconButtonSize size) => switch (size) {
    AppIconButtonSize.sm => sm,
    AppIconButtonSize.md => md,
    AppIconButtonSize.lg => lg,
  };
}

@immutable
class UiIconButtonSpec {
  const UiIconButtonSpec({
    required this.iconSize,
    required this.constraints,
    required this.labelSpacing,
    required this.iconColor,
    required this.disabledIconColor,
    required this.labelStyle,
    required this.disabledLabelStyle,
  });

  final double iconSize;
  final BoxConstraints constraints;
  final double labelSpacing;
  final Color iconColor;
  final Color disabledIconColor;
  final TextStyle labelStyle;
  final TextStyle disabledLabelStyle;
}

extension UiIconButtonThemeContext on BuildContext {
  UiIconButtonTheme get iconButtons =>
      Theme.of(this).extension<UiIconButtonTheme>() ??
      UiIconButtonTheme.standard;
}
