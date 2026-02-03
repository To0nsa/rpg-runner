import 'package:flutter/material.dart';

/// Hub-scoped UI defaults.
///
/// These are not global "design tokens"; they're defaults for hub components
/// (e.g. the select card frame). Keeping them separate prevents `UiTokens`
/// from accumulating one-off component sizing.
@immutable
class UiHubTheme extends ThemeExtension<UiHubTheme> {
  const UiHubTheme({
    required this.selectCardWidth,
    required this.selectCardHeight,
    required this.characterPreviewSize,
  });

  final double selectCardWidth;
  final double selectCardHeight;
  final double characterPreviewSize;

  static const UiHubTheme standard = UiHubTheme(
    selectCardWidth: 240,
    selectCardHeight: 144,
    characterPreviewSize: 96,
  );

  @override
  UiHubTheme copyWith({
    double? selectCardWidth,
    double? selectCardHeight,
    double? characterPreviewSize,
  }) {
    return UiHubTheme(
      selectCardWidth: selectCardWidth ?? this.selectCardWidth,
      selectCardHeight: selectCardHeight ?? this.selectCardHeight,
      characterPreviewSize: characterPreviewSize ?? this.characterPreviewSize,
    );
  }

  @override
  UiHubTheme lerp(ThemeExtension<UiHubTheme>? other, double t) {
    if (other is! UiHubTheme) return this;
    return t < 0.5 ? this : other;
  }
}

extension UiHubThemeContext on BuildContext {
  UiHubTheme get hub =>
      Theme.of(this).extension<UiHubTheme>() ?? UiHubTheme.standard;
}
