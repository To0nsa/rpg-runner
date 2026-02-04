import 'package:flutter/material.dart';

export '../theme/ui_inline_icon_button_theme.dart'
    show AppInlineIconButtonSize, AppInlineIconButtonVariant;

import '../theme/ui_inline_icon_button_theme.dart';
import '../theme/ui_tokens.dart';

class AppInlineIconButton extends StatelessWidget {
  const AppInlineIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.variant = AppInlineIconButtonVariant.discrete,
    this.size = AppInlineIconButtonSize.sm,
    this.loading = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final AppInlineIconButtonVariant variant;
  final AppInlineIconButtonSize size;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final theme = context.inlineIconButtons;
    final spec = theme.resolveSpec(ui: ui, variant: variant, size: size);

    final effectiveOnPressed = loading ? null : onPressed;

    final Widget iconWidget = loading
        ? SizedBox(
            width: spec.spinnerSize,
            height: spec.spinnerSize,
            child: CircularProgressIndicator(
              strokeWidth: spec.spinnerStrokeWidth,
              color: spec.spinnerColor,
            ),
          )
        : Icon(icon);

    return IconButton(
      onPressed: effectiveOnPressed,
      icon: iconWidget,
      iconSize: spec.iconSize,
      color: spec.iconColor,
      disabledColor: spec.disabledColor,
      tooltip: tooltip,
      padding: spec.padding,
      constraints: spec.constraints,
    );
  }
}
