import 'package:flutter/material.dart';

@immutable
class UiSkillIconTheme extends ThemeExtension<UiSkillIconTheme> {
  const UiSkillIconTheme({required this.listIconSize});

  final double listIconSize;

  static const UiSkillIconTheme standard = UiSkillIconTheme(listIconSize: 32);

  @override
  UiSkillIconTheme copyWith({double? listIconSize}) {
    return UiSkillIconTheme(listIconSize: listIconSize ?? this.listIconSize);
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
