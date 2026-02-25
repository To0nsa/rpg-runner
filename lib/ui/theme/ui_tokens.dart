import 'package:flutter/material.dart';

/// Shared brand palette constants for cross-component color reuse.
class UiBrandPalette {
  const UiBrandPalette._();

  static const baseBackground = Color(0xFF0F141A);
  static const cardBackground = Color(0xFF131A22);

  static const steelBlueBackground = Color(0xFF1D2731);
  static const steelBlueForeground = Color(0xFFD2DAE3);
  static const steelBlueMutedText = Color(0xB3D2DAE3);
  static const steelBlueSurfaceTop = Color(0xFF354656);
  static const steelBlueSurfaceBottom = Color(0xFF131C24);
  static const steelBlueInsetTop = Color(0xFF283748);
  static const steelBlueInsetBottom = Color(0xFF10161C);

  static const wornGoldBorder = Color(0xFF8E7A4F);
  static const wornGoldOutline = Color(0xB38E7A4F);
  static const wornGoldInsetBorder = Color(0xFFAE9664);
  static const wornGoldGlow = Color(0x1A8E7A4F);

  static const mutedMossValueHighlight = Color(0xFF7A8F7D);
  static const mutedMossSuccess = Color(0xFF7E957E);
  static const crimsonDanger = Color(0xFFA93D48);

  static const mutedPlumBackground = Color(0xFF282328);
  static const mutedPlumForeground = Color(0xFFD9CFD7);
  static const mutedPlumBorder = Color(0xFF7E6675);
  static const mutedPlumSurfaceTop = Color(0xFF433843);
  static const mutedPlumSurfaceBottom = Color(0xFF191519);
  static const mutedPlumInsetTop = Color(0xFF332A33);
  static const mutedPlumInsetBottom = Color(0xFF141114);
  static const mutedPlumInsetBorder = Color(0xFF957C8C);
  static const mutedPlumGlow = Color(0x1A7E6675);

  static const scrim = Color(0xAA000000);
  static const shadow = Color(0x8A000000);
  static const buttonShadow = Color(0xB3000000);
}

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
      background: UiBrandPalette.baseBackground,
      surface: UiBrandPalette.steelBlueBackground,
      cardBackground: UiBrandPalette.cardBackground,
      textPrimary: UiBrandPalette.steelBlueForeground,
      textMuted: UiBrandPalette.steelBlueMutedText,
      outline: UiBrandPalette.wornGoldOutline,
      outlineStrong: UiBrandPalette.wornGoldInsetBorder,
      accent: UiBrandPalette.wornGoldBorder,
      accentStrong: UiBrandPalette.wornGoldInsetBorder,
      valueHighlight: UiBrandPalette.mutedMossValueHighlight,
      danger: UiBrandPalette.crimsonDanger,
      success: UiBrandPalette.mutedMossSuccess,
      scrim: UiBrandPalette.scrim,
      shadow: UiBrandPalette.shadow,
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
        fontFamily: 'CrimsonText',
        color: UiBrandPalette.steelBlueForeground,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
      title: TextStyle(
        fontFamily: 'CrimsonText',
        color: UiBrandPalette.steelBlueForeground,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
      headline: TextStyle(
        fontFamily: 'CrimsonText',
        color: UiBrandPalette.steelBlueForeground,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      body: TextStyle(
        fontFamily: 'CrimsonText',
        color: UiBrandPalette.steelBlueForeground,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      label: TextStyle(
        fontFamily: 'CrimsonText',
        color: UiBrandPalette.steelBlueForeground,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
      caption: TextStyle(
        fontFamily: 'CrimsonText',
        color: UiBrandPalette.steelBlueMutedText,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      loreHeading: TextStyle(
        fontFamily: 'CrimsonText',
        color: UiBrandPalette.steelBlueForeground,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      loreBody: TextStyle(
        fontFamily: 'CrimsonText',
        color: UiBrandPalette.steelBlueMutedText,
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
      cardLabel: TextStyle(
        fontFamily: 'CrimsonText',
        color: UiBrandPalette.steelBlueForeground,
        fontSize: 14,
        letterSpacing: 1,
        fontWeight: FontWeight.w700,
        shadows: [
          Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 4)),
        ],
      ),
      cardTitle: TextStyle(
        fontFamily: 'CrimsonText',
        color: UiBrandPalette.steelBlueForeground,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
        shadows: [
          Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 4)),
        ],
      ),
      cardSubtitle: TextStyle(
        fontFamily: 'CrimsonText',
        color: UiBrandPalette.steelBlueForeground,
        fontSize: 14,
        fontWeight: FontWeight.w700,
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
    required this.loreHeading,
    required this.loreBody,
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
  final TextStyle loreHeading;
  final TextStyle loreBody;
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
