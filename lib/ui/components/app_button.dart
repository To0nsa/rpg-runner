import 'package:flutter/material.dart';

export '../theme/ui_button_theme.dart' show AppButtonSize, AppButtonVariant;

import '../theme/ui_button_theme.dart';
import '../theme/ui_tokens.dart';

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.padding,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final buttons = context.buttons;

    final resolvedHeight = buttons.sizes.height(size);
    final resolvedWidth = buttons.sizes.width(size);
    final resolvedPadding =
        padding ?? EdgeInsets.symmetric(horizontal: ui.space.md, vertical: 10);

    final resolvedTextStyle = buttons.text.style(size);

    final theme = buttons.variant(variant);
    final background = theme.background;
    final foreground = theme.foreground;
    final border = theme.border;

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(ui.radii.sm),
    );

    final style = ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          if (background == Colors.transparent) return background;
          return background.withValues(alpha: buttons.disabledBackgroundAlpha);
        }
        return background;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return foreground.withValues(alpha: buttons.disabledForegroundAlpha);
        }
        return foreground;
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return foreground.withValues(alpha: buttons.pressedOverlayAlpha);
        }
        if (states.contains(WidgetState.hovered)) {
          return foreground.withValues(alpha: buttons.hoverOverlayAlpha);
        }
        return null;
      }),
      side: WidgetStateProperty.resolveWith((states) {
        final w = ui.sizes.borderWidth;
        if (states.contains(WidgetState.disabled)) {
          return BorderSide(
            color: border.withValues(alpha: buttons.disabledBorderAlpha),
            width: w,
          );
        }
        return BorderSide(color: border, width: w);
      }),
      shape: WidgetStateProperty.all(shape),
      padding: WidgetStateProperty.all(resolvedPadding),
      textStyle: WidgetStateProperty.all(resolvedTextStyle),
      minimumSize: WidgetStateProperty.all(
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

    return SizedBox(
      width: resolvedWidth,
      height: resolvedHeight,
      child: button,
    );
  }
}
