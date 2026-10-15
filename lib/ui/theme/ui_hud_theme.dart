import 'package:flutter/material.dart';

/// Shared quiet framing for in-run information and session controls.
@immutable
class UiHudTheme extends ThemeExtension<UiHudTheme> {
  const UiHudTheme({
    this.background = const Color(0xBF20242B),
    this.border = const Color(0x2EE5E8EB),
    this.track = const Color(0x990F141A),
    this.radius = 8,
  });

  static const standard = UiHudTheme();
  final Color background;
  final Color border;
  final Color track;
  final double radius;

  BoxDecoration get panelDecoration => BoxDecoration(
    color: background,
    border: Border.all(color: border),
    borderRadius: BorderRadius.circular(radius),
  );

  @override
  UiHudTheme copyWith({
    Color? background,
    Color? border,
    Color? track,
    double? radius,
  }) => UiHudTheme(
    background: background ?? this.background,
    border: border ?? this.border,
    track: track ?? this.track,
    radius: radius ?? this.radius,
  );

  @override
  UiHudTheme lerp(covariant UiHudTheme? other, double t) => other == null
      ? this
      : UiHudTheme(
          background: Color.lerp(background, other.background, t)!,
          border: Color.lerp(border, other.border, t)!,
          track: Color.lerp(track, other.track, t)!,
          radius: radius + (other.radius - radius) * t,
        );
}

extension UiHudThemeContext on BuildContext {
  UiHudTheme get hudTheme =>
      Theme.of(this).extension<UiHudTheme>() ?? UiHudTheme.standard;
}
