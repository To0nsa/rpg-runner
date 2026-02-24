import 'package:flutter/material.dart';

@immutable
class UiTokens extends ThemeExtension<UiTokens> {
  const UiTokens({
    required this.space,
    required this.radii,
    required this.text,
    required this.colors,
    required this.sizes,
    required this.shadows,
  });

  final UiSpace space;
  final UiRadii radii;
  final UiTextStyles text;
  final UiColors colors;
  final UiSizes sizes;
  final UiShadows shadows;

  static const UiTokens standard = UiTokens(
    space: UiSpace(xxs: 4, xs: 8, sm: 12, md: 16, lg: 24, xl: 32, xxl: 48),
    radii: UiRadii(sm: 8, md: 12, lg: 16, xl: 24),
    colors: UiColors(
      background: Colors.black,
      surface: Color.fromARGB(255, 19, 32, 59),
      cardBackground: Color(0xFF263238),
      textPrimary: Colors.white,
      textMuted: Colors.white70,
      outline: Color(0xB3FFFFFF),
      outlineStrong: Colors.white,
      accent: Color(0xFFFFF59D),
      accentStrong: Color(0xFFFFD54F),
      valueHighlight: Color(0xFF66BB6A),
      danger: Colors.redAccent,
      success: Colors.greenAccent,
      scrim: Color(0xAA000000),
      shadow: Color(0x8A000000),
    ),
    sizes: UiSizes(
      tapTarget: 48,
      iconSize: UiIconSizes(xs: 12, sm: 16, md: 24, lg: 32),
      dividerThickness: 2,
      borderWidth: 2,
    ),
    shadows: UiShadows(
      card: [
        BoxShadow(
          color: Color(0x8A000000),
          blurRadius: 8,
          offset: Offset(0, 4),
        ),
      ],
      textStrong: [
        Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 4)),
      ],
    ),
    text: UiTextStyles(
      display: TextStyle(
        color: Colors.white,
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
      title: TextStyle(
        color: Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
      headline: TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      body: TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
      label: TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
      caption: TextStyle(
        color: Color(0xB3FFFFFF),
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      cardLabel: TextStyle(
        color: Colors.white,
        fontSize: 12,
        letterSpacing: 1.5,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 4)),
        ],
      ),
      cardTitle: TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 4)),
        ],
      ),
      cardSubtitle: TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 4)),
        ],
      ),
    ),
  );

  @override
  UiTokens copyWith({
    UiSpace? space,
    UiRadii? radii,
    UiTextStyles? text,
    UiColors? colors,
    UiSizes? sizes,
    UiShadows? shadows,
  }) {
    return UiTokens(
      space: space ?? this.space,
      radii: radii ?? this.radii,
      text: text ?? this.text,
      colors: colors ?? this.colors,
      sizes: sizes ?? this.sizes,
      shadows: shadows ?? this.shadows,
    );
  }

  @override
  UiTokens lerp(ThemeExtension<UiTokens>? other, double t) {
    if (other is! UiTokens) return this;
    return t < 0.5 ? this : other;
  }
}

class UiSpace {
  const UiSpace({
    required this.xxs,
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.xxl,
  });

  final double xxs;
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double xxl;
}

class UiRadii {
  const UiRadii({
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
  });

  final double sm;
  final double md;
  final double lg;
  final double xl;
}

class UiTextStyles {
  const UiTextStyles({
    required this.display,
    required this.title,
    required this.headline,
    required this.body,
    required this.label,
    required this.caption,
    required this.cardLabel,
    required this.cardTitle,
    required this.cardSubtitle,
  });

  final TextStyle display;
  final TextStyle title;
  final TextStyle headline;
  final TextStyle body;
  final TextStyle label;
  final TextStyle caption;
  final TextStyle cardLabel;
  final TextStyle cardTitle;
  final TextStyle cardSubtitle;
}

class UiColors {
  const UiColors({
    required this.background,
    required this.surface,
    required this.cardBackground,
    required this.textPrimary,
    required this.textMuted,
    required this.outline,
    required this.outlineStrong,
    required this.accent,
    required this.accentStrong,
    required this.valueHighlight,
    required this.danger,
    required this.success,
    required this.scrim,
    required this.shadow,
  });

  final Color background;
  final Color surface;
  final Color cardBackground;
  final Color textPrimary;
  final Color textMuted;
  final Color outline;
  final Color outlineStrong;
  final Color accent;
  final Color accentStrong;
  final Color valueHighlight;
  final Color danger;
  final Color success;
  final Color scrim;
  final Color shadow;
}

class UiSizes {
  const UiSizes({
    required this.tapTarget,
    required this.iconSize,
    required this.dividerThickness,
    required this.borderWidth,
  });

  final double tapTarget;
  final UiIconSizes iconSize;
  final double dividerThickness;
  final double borderWidth;
}

class UiIconSizes {
  const UiIconSizes({
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
  });

  final double xs;
  final double sm;
  final double md;
  final double lg;
}

class UiShadows {
  const UiShadows({required this.card, required this.textStrong});

  final List<BoxShadow> card;
  final List<Shadow> textStrong;
}

extension UiTokensContext on BuildContext {
  UiTokens get ui => Theme.of(this).extension<UiTokens>() ?? UiTokens.standard;
}
