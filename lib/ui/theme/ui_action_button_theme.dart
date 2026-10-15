import 'package:flutter/material.dart';

import '../controls/controls_tuning.dart';
import '../controls/control_resource_usage.dart';
import 'ui_resource_colors.dart';
import 'ui_world_palette.dart';

enum UiActionButtonSurface { run, selection }

@immutable
class UiActionButtonTheme extends ThemeExtension<UiActionButtonTheme> {
  const UiActionButtonTheme({
    required this.run,
    required this.selection,
    required this.selectionRing,
    this.resourceOverlay = const Color(0xB8151A1F),
  });

  final UiActionButtonVisual run;
  final UiActionButtonVisual selection;
  final UiActionButtonSelectionRing selectionRing;

  /// Brand ink over the vitals colors keeps the action wheel subdued.
  final Color resourceOverlay;

  /// Muted resource hues; the control surface supplies their final opacity.
  List<Color> resourceBackgrounds(ControlResourceUsage resources) => [
    if (resources.health)
      Color.alphaBlend(resourceOverlay, UiResourceColors.health),
    if (resources.mana)
      Color.alphaBlend(resourceOverlay, UiResourceColors.mana),
    if (resources.stamina)
      Color.alphaBlend(resourceOverlay, UiResourceColors.stamina),
  ];

  static final UiActionButtonTheme standard = _buildStandard();

  static UiActionButtonTheme _buildStandard() {
    return UiActionButtonTheme(
      run: const UiActionButtonVisual(
        backgroundColor: Color(0x94151A1F),
        foregroundColor: UiWorldPalette.mist200,
      ),
      selection: const UiActionButtonVisual(
        backgroundColor: Color(0x94151A1F),
        foregroundColor: UiWorldPalette.mist200,
      ),
      selectionRing: const UiActionButtonSelectionRing(
        outerScale: 1.08,
        color: UiWorldPalette.gold500,
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
    );
  }

  @override
  UiActionButtonTheme copyWith({
    UiActionButtonVisual? run,
    UiActionButtonVisual? selection,
    UiActionButtonSelectionRing? selectionRing,
    Color? resourceOverlay,
  }) {
    return UiActionButtonTheme(
      run: run ?? this.run,
      selection: selection ?? this.selection,
      selectionRing: selectionRing ?? this.selectionRing,
      resourceOverlay: resourceOverlay ?? this.resourceOverlay,
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
  });

  final Color backgroundColor;
  final Color foregroundColor;
}

@immutable
class UiActionButtonSelectionRing {
  const UiActionButtonSelectionRing({
    required this.outerScale,
    required this.color,
  });

  final double outerScale;
  final Color color;
}

extension UiActionButtonThemeContext on BuildContext {
  UiActionButtonTheme get actionButtons =>
      Theme.of(this).extension<UiActionButtonTheme>() ??
      UiActionButtonTheme.standard;
}
