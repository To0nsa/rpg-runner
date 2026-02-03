import 'package:flutter/material.dart';

import '../theme/ui_tokens.dart';

enum AppButtonVariant { primary, secondary, danger }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.width = 160,
    this.height,
    this.padding,
    this.textStyle,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;

    final resolvedHeight = height ?? ui.sizes.buttonHeight;
    final resolvedPadding =
        padding ?? EdgeInsets.symmetric(horizontal: ui.space.md, vertical: 10);

    final baseTextStyle = textStyle ?? ui.text.label;
    final resolvedTextStyle = TextStyle(
      fontSize: baseTextStyle.fontSize,
      fontWeight: baseTextStyle.fontWeight,
      fontStyle: baseTextStyle.fontStyle,
      letterSpacing: baseTextStyle.letterSpacing,
      wordSpacing: baseTextStyle.wordSpacing,
      textBaseline: baseTextStyle.textBaseline,
      height: baseTextStyle.height,
      locale: baseTextStyle.locale,
      fontFamily: baseTextStyle.fontFamily,
      fontFamilyFallback: baseTextStyle.fontFamilyFallback,
    );

    final (background, foreground, border) = switch (variant) {
      AppButtonVariant.primary => (
        ui.colors.buttonBg,
        ui.colors.buttonFg,
        ui.colors.buttonBorder,
      ),
      AppButtonVariant.secondary => (
        Colors.transparent,
        ui.colors.textPrimary,
        ui.colors.outlineStrong,
      ),
      AppButtonVariant.danger => (
        ui.colors.danger,
        Colors.white,
        ui.colors.danger,
      ),
    };

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(ui.radii.sm),
    );

    final style = ButtonStyle(
      backgroundColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.disabled)) {
          if (background == Colors.transparent) return background;
          return background.withOpacity(0.4);
        }
        return background;
      }),
      foregroundColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.disabled)) {
          return foreground.withOpacity(0.5);
        }
        return foreground;
      }),
      overlayColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.pressed)) {
          return foreground.withOpacity(0.12);
        }
        if (states.contains(MaterialState.hovered)) {
          return foreground.withOpacity(0.08);
        }
        return null;
      }),
      side: MaterialStateProperty.resolveWith((states) {
        final w = ui.sizes.borderWidth;
        if (states.contains(MaterialState.disabled)) {
          return BorderSide(color: border.withOpacity(0.4), width: w);
        }
        return BorderSide(color: border, width: w);
      }),
      shape: MaterialStateProperty.all(shape),
      padding: MaterialStateProperty.all(resolvedPadding),
      textStyle: MaterialStateProperty.all(resolvedTextStyle),
      minimumSize: MaterialStateProperty.all(
        Size(ui.sizes.tapTarget, resolvedHeight),
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    final button = OutlinedButton(
      onPressed: onPressed,
      style: style,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );

    if (width == null) {
      return SizedBox(height: resolvedHeight, child: button);
    }
    return SizedBox(width: width, height: resolvedHeight, child: button);
  }
}
