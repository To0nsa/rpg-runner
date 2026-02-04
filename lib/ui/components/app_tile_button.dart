import 'package:flutter/material.dart';

export '../theme/ui_icon_button_theme.dart'
    show AppIconButtonSize, AppIconButtonVariant;

import '../theme/ui_icon_button_theme.dart';
import '../theme/ui_tokens.dart';

class AppTileButton extends StatelessWidget {
  const AppTileButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.label,
    this.tooltip,
    this.variant = AppIconButtonVariant.primary,
    this.size = AppIconButtonSize.md,
  }) : assert(
         label != null || tooltip != null,
         'Provide a label or tooltip for accessibility.',
       );

  final Widget child;
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

    final tile = ConstrainedBox(
      constraints: spec.constraints,
      child: Center(
        child: Opacity(
          opacity: enabled ? 1.0 : theme.disabledAlpha,
          child: Container(
            width: spec.iconSize,
            height: spec.iconSize,
            decoration: BoxDecoration(
              color: ui.colors.cardBackground,
              borderRadius: BorderRadius.circular(ui.radii.sm),
              border: Border.all(color: ui.colors.outline),
            ),
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );

    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(ui.radii.sm),
        child: tile,
      ),
    );

    final wrapped = Tooltip(message: tooltip ?? label, child: button);
    if (label == null) return wrapped;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        wrapped,
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
