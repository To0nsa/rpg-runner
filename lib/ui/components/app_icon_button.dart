import 'package:flutter/material.dart';

export '../theme/ui_icon_button_theme.dart'
    show AppIconButtonSize, AppIconButtonVariant;

import '../theme/ui_icon_button_theme.dart';
import '../theme/ui_tokens.dart';

class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.label,
    this.tooltip,
    this.variant = AppIconButtonVariant.primary,
    this.size = AppIconButtonSize.md,
  }) : assert(
         label != null || tooltip != null,
         'Provide a label or tooltip for accessibility.',
       );

  final IconData icon;
  final VoidCallback? onPressed;
  final String? label;
  final String? tooltip;
  final AppIconButtonVariant variant;
  final AppIconButtonSize size;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final theme = context.iconButtons;
    final spec = theme.resolveSpec(ui: ui, variant: variant, size: size);
    final enabled = onPressed != null;

    final iconButton = IconButton(
      onPressed: onPressed,
      icon: Icon(icon),
      iconSize: spec.iconSize,
      color: spec.iconColor,
      disabledColor: spec.disabledIconColor,
      tooltip: tooltip ?? label,
      padding: EdgeInsets.zero,
      constraints: spec.constraints,
    );

    if (label == null) return iconButton;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        iconButton,
        SizedBox(height: spec.labelSpacing),
        Text(
          label!,
          style: enabled ? spec.labelStyle : spec.disabledLabelStyle,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
