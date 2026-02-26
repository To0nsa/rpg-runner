import 'package:flutter/material.dart';

@immutable
class UiSkillIconTheme extends ThemeExtension<UiSkillIconTheme> {
  const UiSkillIconTheme({
    required this.listIconSize,
    required this.selectionRadialIconSize,
    required this.runRadialIconSize,
  });

  final double listIconSize;
  final double selectionRadialIconSize;
  final double runRadialIconSize;

  static const UiSkillIconTheme standard = UiSkillIconTheme(
    listIconSize: 32,
    selectionRadialIconSize: 64,
    runRadialIconSize: 48,
  );

  @override
  UiSkillIconTheme copyWith({
    double? listIconSize,
    double? selectionRadialIconSize,
    double? runRadialIconSize,
  }) {
    return UiSkillIconTheme(
      listIconSize: listIconSize ?? this.listIconSize,
      selectionRadialIconSize:
          selectionRadialIconSize ?? this.selectionRadialIconSize,
      runRadialIconSize: runRadialIconSize ?? this.runRadialIconSize,
    );
  }

  @override
  UiSkillIconTheme lerp(ThemeExtension<UiSkillIconTheme>? other, double t) {
    if (other is! UiSkillIconTheme) return this;
    return t < 0.5 ? this : other;
  }
}

extension UiSkillIconThemeContext on BuildContext {
  UiSkillIconTheme get skillIcons =>
      Theme.of(this).extension<UiSkillIconTheme>() ?? UiSkillIconTheme.standard;
}
