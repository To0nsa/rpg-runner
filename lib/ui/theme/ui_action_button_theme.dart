import 'package:flutter/material.dart';

import '../controls/controls_tuning.dart';
import 'ui_tokens.dart';

enum UiActionButtonSurface { run, selection }

@immutable
class UiActionButtonTheme extends ThemeExtension<UiActionButtonTheme> {
  const UiActionButtonTheme({
    required this.run,
    required this.selection,
    required this.selectionRing,
  });

  final UiActionButtonVisual run;
  final UiActionButtonVisual selection;
  final UiActionButtonSelectionRing selectionRing;

  static final UiActionButtonTheme standard = _buildStandard(UiTokens.standard);

  static UiActionButtonTheme _buildStandard(UiTokens ui) {
    final labelFontSize = (ui.text.label.fontSize ?? 12) * (2 / 3);
    final labelGap = ui.space.xxs * 0.5;
    return UiActionButtonTheme(
      run: UiActionButtonVisual(
        backgroundColor: ui.colors.shadow.withValues(alpha: 0.2),
        foregroundColor: UiBrandPalette.steelBlueForeground,
        labelFontSize: labelFontSize,
        labelGap: labelGap,
      ),
      selection: UiActionButtonVisual(
        backgroundColor: ui.colors.textPrimary,
        foregroundColor: ui.colors.background,
        labelFontSize: labelFontSize,
        labelGap: labelGap,
      ),
      selectionRing: const UiActionButtonSelectionRing(
        selectedBorderColor: UiBrandPalette.wornGoldInsetBorder,
        borderWidthScale: 1.08,
      ),
    );
  }

  UiActionButtonVisual visual(UiActionButtonSurface surface) =>
      switch (surface) {
        UiActionButtonSurface.run => run,
        UiActionButtonSurface.selection => selection,
      };

  ActionButtonTuning resolveAction({
    required ActionButtonTuning base,
    required UiActionButtonSurface surface,
  }) {
    final visual = this.visual(surface);
    return ActionButtonTuning(
      size: base.size,
      backgroundColor: visual.backgroundColor,
      foregroundColor: visual.foregroundColor,
      labelFontSize: visual.labelFontSize,
      labelGap: visual.labelGap,
    );
  }

  DirectionalActionButtonTuning resolveDirectional({
    required DirectionalActionButtonTuning base,
    required UiActionButtonSurface surface,
  }) {
    final visual = this.visual(surface);
    return DirectionalActionButtonTuning(
      size: base.size,
      deadzoneRadius: base.deadzoneRadius,
      backgroundColor: visual.backgroundColor,
      foregroundColor: visual.foregroundColor,
      labelFontSize: visual.labelFontSize,
      labelGap: visual.labelGap,
    );
  }

  @override
  UiActionButtonTheme copyWith({
    UiActionButtonVisual? run,
    UiActionButtonVisual? selection,
    UiActionButtonSelectionRing? selectionRing,
  }) {
    return UiActionButtonTheme(
      run: run ?? this.run,
      selection: selection ?? this.selection,
      selectionRing: selectionRing ?? this.selectionRing,
    );
  }

  @override
  UiActionButtonTheme lerp(
    ThemeExtension<UiActionButtonTheme>? other,
    double t,
  ) {
    if (other is! UiActionButtonTheme) return this;
    return t < 0.5 ? this : other;
  }
}

@immutable
class UiActionButtonVisual {
  const UiActionButtonVisual({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.labelFontSize,
    required this.labelGap,
  });

  final Color backgroundColor;
  final Color foregroundColor;
  final double labelFontSize;
  final double labelGap;
}

@immutable
class UiActionButtonSelectionRing {
  const UiActionButtonSelectionRing({
    required this.selectedBorderColor,
    required this.borderWidthScale,
  });

  final Color selectedBorderColor;
  final double borderWidthScale;
}

extension UiActionButtonThemeContext on BuildContext {
  UiActionButtonTheme get actionButtons =>
      Theme.of(this).extension<UiActionButtonTheme>() ??
      UiActionButtonTheme.standard;
}
