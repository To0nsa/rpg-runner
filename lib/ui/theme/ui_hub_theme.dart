import 'package:flutter/material.dart';

import 'ui_world_palette.dart';
import 'ui_tokens.dart';

/// Restrained surfaces and reading hierarchy owned by the play hub.
@immutable
class UiHubTheme extends ThemeExtension<UiHubTheme> {
  const UiHubTheme({
    required this.selectCardWidth,
    required this.selectCardHeight,
    required this.characterPreviewSize,
    required this.surface,
    required this.outline,
    required this.foreground,
    required this.muted,
    required this.label,
    required this.title,
    required this.detail,
  });

  final double selectCardWidth, selectCardHeight, characterPreviewSize;
  final Color surface, outline, foreground, muted;
  final TextStyle label, title, detail;

  static const standard = UiHubTheme(
    selectCardWidth: 280,
    selectCardHeight: 216,
    characterPreviewSize: 132,
    surface: UiBrandPalette.cardBackground,
    outline: UiBrandPalette.wornGoldOutline,
    foreground: UiWorldPalette.mist200,
    muted: UiWorldPalette.fog300,
    label: TextStyle(
      fontFamily: 'CrimsonText',
      fontSize: 12,
      height: 1.3,
      fontWeight: FontWeight.w500,
      color: UiWorldPalette.mist200,
    ),
    title: TextStyle(
      fontFamily: 'CrimsonText',
      fontSize: 22,
      height: 1.1,
      fontWeight: FontWeight.w600,
      color: UiWorldPalette.mist200,
    ),
    detail: TextStyle(
      fontFamily: 'CrimsonText',
      fontSize: 12,
      height: 1.35,
      color: UiWorldPalette.fog300,
    ),
  );

  @override
  UiHubTheme copyWith({
    double? selectCardWidth,
    double? selectCardHeight,
    double? characterPreviewSize,
    Color? surface,
    Color? outline,
    Color? foreground,
    Color? muted,
    TextStyle? label,
    TextStyle? title,
    TextStyle? detail,
  }) => UiHubTheme(
    selectCardWidth: selectCardWidth ?? this.selectCardWidth,
    selectCardHeight: selectCardHeight ?? this.selectCardHeight,
    characterPreviewSize: characterPreviewSize ?? this.characterPreviewSize,
    surface: surface ?? this.surface,
    outline: outline ?? this.outline,
    foreground: foreground ?? this.foreground,
    muted: muted ?? this.muted,
    label: label ?? this.label,
    title: title ?? this.title,
    detail: detail ?? this.detail,
  );

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
