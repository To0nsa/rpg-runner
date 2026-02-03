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
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final buttons = context.buttons;

    final spec = buttons.resolveSpec(ui: ui, variant: variant, size: size);

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(ui.radii.sm),
    );

    final style = ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return spec.background.withValues(
            alpha: buttons.disabledBackgroundAlpha,
          );
        }
        return spec.background;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return spec.foreground.withValues(
            alpha: buttons.disabledForegroundAlpha,
          );
        }
        return spec.foreground;
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return spec.foreground.withValues(alpha: buttons.pressedOverlayAlpha);
        }
        if (states.contains(WidgetState.hovered)) {
          return spec.foreground.withValues(alpha: buttons.hoverOverlayAlpha);
        }
        return null;
      }),
      side: WidgetStateProperty.resolveWith((states) {
        final w = ui.sizes.borderWidth;
        if (states.contains(WidgetState.disabled)) {
          return BorderSide(
            color: spec.border.withValues(alpha: buttons.disabledBorderAlpha),
            width: w,
          );
        }
        return BorderSide(color: spec.border, width: w);
      }),
      shape: WidgetStateProperty.all(shape),
      padding: WidgetStateProperty.all(spec.padding),
      textStyle: WidgetStateProperty.all(spec.textStyle),
      minimumSize: WidgetStateProperty.all(
        Size(ui.sizes.tapTarget, spec.height),
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

    return SizedBox(width: spec.width, height: spec.height, child: button);
  }
}
