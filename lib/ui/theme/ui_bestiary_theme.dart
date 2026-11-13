import 'package:flutter/material.dart';

import 'ui_tokens.dart';
import 'ui_world_palette.dart';

/// Field-guide colors and emphasis built on the game's shared typography.
@immutable
class UiBestiaryTheme extends ThemeExtension<UiBestiaryTheme> {
  const UiBestiaryTheme({
    required this.background,
    required this.surface,
    required this.outline,
    required this.accent,
    required this.title,
    required this.heading,
    required this.body,
    required this.detail,
    required this.lore,
  });

  final Color background, surface, outline, accent;
  final TextStyle title, heading, body, detail, lore;

  static final standard = UiBestiaryTheme(
    background: UiWorldPalette.ink900,
    surface: UiWorldPalette.ink800,
    outline: Color(0x6655616D),
    accent: UiWorldPalette.gold400,
    title: UiTokens.standard.text.title.copyWith(
      height: 1.2,
      color: UiWorldPalette.mist200,
    ),
    heading: UiTokens.standard.text.body.copyWith(
      height: 1.25,
      fontWeight: FontWeight.w700,
      color: UiWorldPalette.mist200,
    ),
    body: UiTokens.standard.text.body.copyWith(
      height: 1.3,
      color: UiWorldPalette.mist200,
    ),
    detail: UiTokens.standard.text.body.copyWith(
      fontSize: UiTokens.standard.text.label.fontSize,
      height: 1.25,
      color: UiWorldPalette.fog300,
    ),
    lore: UiTokens.standard.text.body.copyWith(
      height: 1.4,
      fontStyle: FontStyle.italic,
      color: UiWorldPalette.mist200,
    ),
  );

  @override
  UiBestiaryTheme copyWith({
    Color? background,
    Color? surface,
    Color? outline,
    Color? accent,
    TextStyle? title,
    TextStyle? heading,
    TextStyle? body,
    TextStyle? detail,
    TextStyle? lore,
  }) => UiBestiaryTheme(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    outline: outline ?? this.outline,
    accent: accent ?? this.accent,
    title: title ?? this.title,
    heading: heading ?? this.heading,
    body: body ?? this.body,
    detail: detail ?? this.detail,
    lore: lore ?? this.lore,
  );

  @override
  UiBestiaryTheme lerp(ThemeExtension<UiBestiaryTheme>? other, double t) {
    if (other is! UiBestiaryTheme) return this;
    return UiBestiaryTheme(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      title: TextStyle.lerp(title, other.title, t)!,
      heading: TextStyle.lerp(heading, other.heading, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      detail: TextStyle.lerp(detail, other.detail, t)!,
      lore: TextStyle.lerp(lore, other.lore, t)!,
    );
  }
}

extension UiBestiaryThemeContext on BuildContext {
  UiBestiaryTheme get bestiary =>
      Theme.of(this).extension<UiBestiaryTheme>() ?? UiBestiaryTheme.standard;
}
