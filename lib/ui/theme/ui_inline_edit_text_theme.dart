import 'package:flutter/material.dart';

import 'ui_inline_icon_button_theme.dart';
import 'ui_tokens.dart';

@immutable
class UiInlineEditTextTheme extends ThemeExtension<UiInlineEditTextTheme> {
  const UiInlineEditTextTheme({
    required this.valueStyle,
    required this.hintStyle,
    required this.borderColor,
    required this.enabledBorderColor,
    required this.focusedBorderColor,
    required this.editButtonVariant,
    required this.saveButtonVariant,
    required this.cancelButtonVariant,
    required this.editButtonSize,
    required this.actionButtonSize,
    this.fieldPadding = const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
  });

  final TextStyle valueStyle;
  final TextStyle hintStyle;

  final Color borderColor;
  final Color enabledBorderColor;
  final Color focusedBorderColor;

  final AppInlineIconButtonVariant editButtonVariant;
  final AppInlineIconButtonVariant saveButtonVariant;
  final AppInlineIconButtonVariant cancelButtonVariant;

  final AppInlineIconButtonSize editButtonSize;
  final AppInlineIconButtonSize actionButtonSize;

  final EdgeInsets fieldPadding;

  static const UiInlineEditTextTheme standard = UiInlineEditTextTheme(
    valueStyle: TextStyle(color: UiBrandPalette.steelBlueForeground),
    hintStyle: TextStyle(color: UiBrandPalette.steelBlueMutedText),
    borderColor: UiBrandPalette.wornGoldInsetBorder,
    enabledBorderColor: UiBrandPalette.wornGoldOutline,
    focusedBorderColor: UiBrandPalette.wornGoldInsetBorder,
    editButtonVariant: AppInlineIconButtonVariant.discrete,
    saveButtonVariant: AppInlineIconButtonVariant.success,
    cancelButtonVariant: AppInlineIconButtonVariant.discrete,
    editButtonSize: AppInlineIconButtonSize.xs,
    actionButtonSize: AppInlineIconButtonSize.sm,
  );

  UiInlineEditTextSpec resolveSpec({required UiTokens ui}) {
    return UiInlineEditTextSpec(
      valueStyle: valueStyle,
      fieldDecoration: InputDecoration(
        isDense: true,
        contentPadding: fieldPadding,
        border: UnderlineInputBorder(
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: enabledBorderColor),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: focusedBorderColor),
        ),
        hintStyle: hintStyle,
      ),
      editButtonVariant: editButtonVariant,
      saveButtonVariant: saveButtonVariant,
      cancelButtonVariant: cancelButtonVariant,
      editButtonSize: editButtonSize,
      actionButtonSize: actionButtonSize,
    );
  }

  @override
  UiInlineEditTextTheme copyWith({
    TextStyle? valueStyle,
    TextStyle? hintStyle,
    Color? borderColor,
    Color? enabledBorderColor,
    Color? focusedBorderColor,
    AppInlineIconButtonVariant? editButtonVariant,
    AppInlineIconButtonVariant? saveButtonVariant,
    AppInlineIconButtonVariant? cancelButtonVariant,
    AppInlineIconButtonSize? editButtonSize,
    AppInlineIconButtonSize? actionButtonSize,
    EdgeInsets? fieldPadding,
  }) {
    return UiInlineEditTextTheme(
      valueStyle: valueStyle ?? this.valueStyle,
      hintStyle: hintStyle ?? this.hintStyle,
      borderColor: borderColor ?? this.borderColor,
      enabledBorderColor: enabledBorderColor ?? this.enabledBorderColor,
      focusedBorderColor: focusedBorderColor ?? this.focusedBorderColor,
      editButtonVariant: editButtonVariant ?? this.editButtonVariant,
      saveButtonVariant: saveButtonVariant ?? this.saveButtonVariant,
      cancelButtonVariant: cancelButtonVariant ?? this.cancelButtonVariant,
      editButtonSize: editButtonSize ?? this.editButtonSize,
      actionButtonSize: actionButtonSize ?? this.actionButtonSize,
      fieldPadding: fieldPadding ?? this.fieldPadding,
    );
  }

  @override
  UiInlineEditTextTheme lerp(
    ThemeExtension<UiInlineEditTextTheme>? other,
    double t,
  ) {
    if (other is! UiInlineEditTextTheme) return this;
    return t < 0.5 ? this : other;
  }
}

@immutable
class UiInlineEditTextSpec {
  const UiInlineEditTextSpec({
    required this.valueStyle,
    required this.fieldDecoration,
    required this.editButtonVariant,
    required this.saveButtonVariant,
    required this.cancelButtonVariant,
    required this.editButtonSize,
    required this.actionButtonSize,
  });

  final TextStyle valueStyle;
  final InputDecoration fieldDecoration;
  final AppInlineIconButtonVariant editButtonVariant;
  final AppInlineIconButtonVariant saveButtonVariant;
  final AppInlineIconButtonVariant cancelButtonVariant;
  final AppInlineIconButtonSize editButtonSize;
  final AppInlineIconButtonSize actionButtonSize;
}

extension UiInlineEditTextThemeContext on BuildContext {
  UiInlineEditTextTheme get inlineEditText =>
      Theme.of(this).extension<UiInlineEditTextTheme>() ??
      UiInlineEditTextTheme.standard;
}
