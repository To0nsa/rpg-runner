import 'package:flutter/material.dart';

/// Town store-scoped visual values.
///
/// This keeps store-only styling out of page-local constants and avoids
/// bloating global `UiTokens` with values that only Town consumes.
@immutable
class UiTownStoreTheme extends ThemeExtension<UiTownStoreTheme> {
  const UiTownStoreTheme({
    required this.summaryPillBackgroundAlpha,
    required this.summaryPillOutlineAlpha,
    required this.bucketIdleOutlineAlpha,
  });

  final double summaryPillBackgroundAlpha;
  final double summaryPillOutlineAlpha;
  final double bucketIdleOutlineAlpha;

  static const UiTownStoreTheme standard = UiTownStoreTheme(
    summaryPillBackgroundAlpha: 0.65,
    summaryPillOutlineAlpha: 0.65,
    bucketIdleOutlineAlpha: 0.75,
  );

  @override
  UiTownStoreTheme copyWith({
    double? summaryPillBackgroundAlpha,
    double? summaryPillOutlineAlpha,
    double? bucketIdleOutlineAlpha,
  }) {
    return UiTownStoreTheme(
      summaryPillBackgroundAlpha:
          summaryPillBackgroundAlpha ?? this.summaryPillBackgroundAlpha,
      summaryPillOutlineAlpha:
          summaryPillOutlineAlpha ?? this.summaryPillOutlineAlpha,
      bucketIdleOutlineAlpha:
          bucketIdleOutlineAlpha ?? this.bucketIdleOutlineAlpha,
    );
  }

  @override
  UiTownStoreTheme lerp(ThemeExtension<UiTownStoreTheme>? other, double t) {
    if (other is! UiTownStoreTheme) {
      return this;
    }
    return t < 0.5 ? this : other;
  }
}

extension UiTownStoreThemeContext on BuildContext {
  UiTownStoreTheme get townStore =>
      Theme.of(this).extension<UiTownStoreTheme>() ?? UiTownStoreTheme.standard;
}
