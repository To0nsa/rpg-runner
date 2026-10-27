import 'package:flutter/material.dart';

import 'ui_world_palette.dart';

/// Matte iron, stained gold and cold lettering shared by in-run framing.
@immutable
class UiHudTheme extends ThemeExtension<UiHudTheme> {
  const UiHudTheme({
    this.background = const Color(0xD9151A1F),
    this.border = UiWorldPalette.gold500,
    this.track = UiWorldPalette.ink900,
    this.highlight = UiWorldPalette.gold400,
    this.foreground = UiWorldPalette.mist200,
    this.wear = UiWorldPalette.ash500,
    this.enemyIndicator = UiWorldPalette.rust500,
  });

  static const standard = UiHudTheme();
  final Color background;
  final Color border;
  final Color track;
  final Color highlight;
  final Color foreground;
  final Color wear;
  final Color enemyIndicator;

  @override
  UiHudTheme copyWith({
    Color? background,
    Color? border,
    Color? track,
    Color? highlight,
    Color? foreground,
    Color? wear,
    Color? enemyIndicator,
  }) => UiHudTheme(
    background: background ?? this.background,
    border: border ?? this.border,
    track: track ?? this.track,
    highlight: highlight ?? this.highlight,
    foreground: foreground ?? this.foreground,
    wear: wear ?? this.wear,
    enemyIndicator: enemyIndicator ?? this.enemyIndicator,
  );

  @override
  UiHudTheme lerp(covariant UiHudTheme? other, double t) => other == null
      ? this
      : UiHudTheme(
          background: Color.lerp(background, other.background, t)!,
          border: Color.lerp(border, other.border, t)!,
          track: Color.lerp(track, other.track, t)!,
          highlight: Color.lerp(highlight, other.highlight, t)!,
          foreground: Color.lerp(foreground, other.foreground, t)!,
          wear: Color.lerp(wear, other.wear, t)!,
          enemyIndicator: Color.lerp(enemyIndicator, other.enemyIndicator, t)!,
        );
}

extension UiHudThemeContext on BuildContext {
  UiHudTheme get hudTheme =>
      Theme.of(this).extension<UiHudTheme>() ?? UiHudTheme.standard;
}
