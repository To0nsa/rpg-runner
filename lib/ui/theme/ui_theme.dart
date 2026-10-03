import 'package:flutter/material.dart';

import 'ui_button_theme.dart';
import 'ui_hub_theme.dart';
import 'ui_icon_button_theme.dart';
import 'ui_inline_edit_text_theme.dart';
import 'ui_inline_icon_button_theme.dart';
import 'ui_leaderboard_theme.dart';
import 'ui_action_button_theme.dart';
import 'ui_segmented_control_theme.dart';
import 'ui_skill_icon_theme.dart';
import 'ui_town_store_theme.dart';
import 'ui_tokens.dart';

/// Shared app theme, including the service-initialization error screens.
ThemeData createUiTheme() => ThemeData(
  colorScheme:
      ColorScheme.fromSeed(
        seedColor: UiBrandPalette.steelBlueBackground,
        brightness: Brightness.dark,
      ).copyWith(
        surface: UiBrandPalette.cardBackground,
        onSurface: UiBrandPalette.steelBlueForeground,
        outline: UiBrandPalette.wornGoldOutline,
      ),
  scaffoldBackgroundColor: UiBrandPalette.baseBackground,
  canvasColor: UiBrandPalette.cardBackground,
  dividerColor: UiBrandPalette.wornGoldOutline,
  appBarTheme: const AppBarTheme(
    backgroundColor: UiBrandPalette.baseBackground,
    foregroundColor: UiBrandPalette.steelBlueForeground,
    iconTheme: IconThemeData(color: UiBrandPalette.steelBlueForeground),
    titleTextStyle: TextStyle(
      fontFamily: 'CrimsonText',
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: UiBrandPalette.steelBlueForeground,
    ),
  ),
  textSelectionTheme: const TextSelectionThemeData(
    cursorColor: UiBrandPalette.wornGoldInsetBorder,
    selectionColor: UiBrandPalette.wornGoldGlow,
    selectionHandleColor: UiBrandPalette.wornGoldInsetBorder,
  ),
  fontFamily: 'CrimsonText',
  useMaterial3: true,
  extensions: [
    UiTokens.standard,
    UiHubTheme.standard,
    UiButtonTheme.standard,
    UiIconButtonTheme.standard,
    UiInlineIconButtonTheme.standard,
    UiInlineEditTextTheme.standard,
    UiSegmentedControlTheme.standard,
    UiActionButtonTheme.standard,
    UiSkillIconTheme.standard,
    UiLeaderboardTheme.standard,
    UiTownStoreTheme.standard,
  ],
);
