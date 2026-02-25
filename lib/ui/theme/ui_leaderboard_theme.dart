import 'package:flutter/material.dart';

import 'ui_tokens.dart';

@immutable
class UiLeaderboardTheme extends ThemeExtension<UiLeaderboardTheme> {
  const UiLeaderboardTheme({
    required this.columns,
    required this.rowHeight,
    required this.headerHeight,
    this.rowGap = 2,
    this.headerGap = 2,
    this.rowPadding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    this.tablePadding = const EdgeInsets.symmetric(horizontal: 12),
    this.rowRadius = 8,
    this.rowBorderWidth = 1,
    required this.rowBackground,
    required this.rowBorderColor,
    required this.highlightBackground,
    required this.highlightBorderColor,
    required this.rowTextStyle,
    required this.headerTextStyle,
    required this.highlightTextColor,
  });

  final UiLeaderboardColumns columns;
  final double rowHeight;
  final double headerHeight;
  final double rowGap;
  final double headerGap;
  final EdgeInsets rowPadding;
  final EdgeInsets tablePadding;
  final double rowRadius;
  final double rowBorderWidth;

  final Color rowBackground;
  final Color rowBorderColor;
  final Color highlightBackground;
  final Color highlightBorderColor;
  final Color highlightTextColor;

  final TextStyle rowTextStyle;
  final TextStyle headerTextStyle;

  static const UiLeaderboardTheme standard = UiLeaderboardTheme(
    columns: UiLeaderboardColumns(
      rank: UiLeaderboardColumn(width: 40),
      score: UiLeaderboardColumn(flex: 1),
      distance: UiLeaderboardColumn(flex: 1),
      time: UiLeaderboardColumn(flex: 1),
    ),
    rowHeight: 32,
    headerHeight: 20,
    rowBackground: UiBrandPalette.shadow,
    rowBorderColor: UiBrandPalette.steelBlueMutedText,
    highlightBackground: UiBrandPalette.wornGoldGlow,
    highlightBorderColor: UiBrandPalette.wornGoldInsetBorder,
    highlightTextColor: UiBrandPalette.wornGoldInsetBorder,
    rowTextStyle: TextStyle(
      color: UiBrandPalette.steelBlueForeground,
      fontSize: 12,
      fontWeight: FontWeight.w400,
    ),
    headerTextStyle: TextStyle(
      color: UiBrandPalette.steelBlueMutedText,
      fontSize: 12,
      fontWeight: FontWeight.w500,
    ),
  );

  UiLeaderboardSpec resolveSpec({required UiTokens ui}) {
    final resolvedRowTextStyle = rowTextStyle.copyWith(
      color: rowTextStyle.color ?? ui.colors.textPrimary,
    );
    final resolvedHeaderTextStyle = headerTextStyle.copyWith(
      color: headerTextStyle.color ?? ui.colors.textMuted,
    );

    return UiLeaderboardSpec(
      columns: columns,
      rowHeight: rowHeight,
      headerHeight: headerHeight,
      rowGap: rowGap,
      headerGap: headerGap,
      rowPadding: rowPadding,
      tablePadding: tablePadding,
      rowRadius: rowRadius,
      rowBorderWidth: rowBorderWidth,
      rowBackground: rowBackground,
      rowBorderColor: rowBorderColor,
      highlightBackground: highlightBackground,
      highlightBorderColor: highlightBorderColor,
      rowTextStyle: resolvedRowTextStyle,
      headerTextStyle: resolvedHeaderTextStyle,
      highlightTextColor: highlightTextColor,
    );
  }

  @override
  UiLeaderboardTheme copyWith({
    UiLeaderboardColumns? columns,
    double? rowHeight,
    double? headerHeight,
    double? rowGap,
    double? headerGap,
    EdgeInsets? rowPadding,
    EdgeInsets? tablePadding,
    double? rowRadius,
    double? rowBorderWidth,
    Color? rowBackground,
    Color? rowBorderColor,
    Color? highlightBackground,
    Color? highlightBorderColor,
    Color? highlightTextColor,
    TextStyle? rowTextStyle,
    TextStyle? headerTextStyle,
  }) {
    return UiLeaderboardTheme(
      columns: columns ?? this.columns,
      rowHeight: rowHeight ?? this.rowHeight,
      headerHeight: headerHeight ?? this.headerHeight,
      rowGap: rowGap ?? this.rowGap,
      headerGap: headerGap ?? this.headerGap,
      rowPadding: rowPadding ?? this.rowPadding,
      tablePadding: tablePadding ?? this.tablePadding,
      rowRadius: rowRadius ?? this.rowRadius,
      rowBorderWidth: rowBorderWidth ?? this.rowBorderWidth,
      rowBackground: rowBackground ?? this.rowBackground,
      rowBorderColor: rowBorderColor ?? this.rowBorderColor,
      highlightBackground: highlightBackground ?? this.highlightBackground,
      highlightBorderColor: highlightBorderColor ?? this.highlightBorderColor,
      highlightTextColor: highlightTextColor ?? this.highlightTextColor,
      rowTextStyle: rowTextStyle ?? this.rowTextStyle,
      headerTextStyle: headerTextStyle ?? this.headerTextStyle,
    );
  }

  @override
  UiLeaderboardTheme lerp(ThemeExtension<UiLeaderboardTheme>? other, double t) {
    if (other is! UiLeaderboardTheme) return this;
    return t < 0.5 ? this : other;
  }
}

@immutable
class UiLeaderboardSpec {
  const UiLeaderboardSpec({
    required this.columns,
    required this.rowHeight,
    required this.headerHeight,
    required this.rowGap,
    required this.headerGap,
    required this.rowPadding,
    required this.tablePadding,
    required this.rowRadius,
    required this.rowBorderWidth,
    required this.rowBackground,
    required this.rowBorderColor,
    required this.highlightBackground,
    required this.highlightBorderColor,
    required this.rowTextStyle,
    required this.headerTextStyle,
    required this.highlightTextColor,
  });

  final UiLeaderboardColumns columns;
  final double rowHeight;
  final double headerHeight;
  final double rowGap;
  final double headerGap;
  final EdgeInsets rowPadding;
  final EdgeInsets tablePadding;
  final double rowRadius;
  final double rowBorderWidth;
  final Color rowBackground;
  final Color rowBorderColor;
  final Color highlightBackground;
  final Color highlightBorderColor;
  final Color highlightTextColor;
  final TextStyle rowTextStyle;
  final TextStyle headerTextStyle;
}

@immutable
class UiLeaderboardColumns {
  const UiLeaderboardColumns({
    required this.rank,
    required this.score,
    required this.distance,
    required this.time,
  });

  final UiLeaderboardColumn rank;
  final UiLeaderboardColumn score;
  final UiLeaderboardColumn distance;
  final UiLeaderboardColumn time;
}

@immutable
class UiLeaderboardColumn {
  const UiLeaderboardColumn({this.width, this.flex = 1});

  final double? width;
  final int flex;
}

extension UiLeaderboardThemeContext on BuildContext {
  UiLeaderboardTheme get leaderboards =>
      Theme.of(this).extension<UiLeaderboardTheme>() ??
      UiLeaderboardTheme.standard;
}
