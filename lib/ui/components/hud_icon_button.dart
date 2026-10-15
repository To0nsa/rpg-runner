import 'package:flutter/material.dart';

import '../theme/ui_hud_theme.dart';
import '../theme/ui_tokens.dart';
import 'hud_frame.dart';

/// A compact HUD control that stretches with its adjacent information panel.
class HudIconButton extends StatelessWidget {
  const HudIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      minWidth: context.ui.sizes.tapTarget,
      maxWidth: context.ui.sizes.tapTarget,
      minHeight: context.ui.sizes.tapTarget,
    ),
    child: HudPanel(
      child: IconButton(
        style: IconButton.styleFrom(
          minimumSize: Size.zero,
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: Colors.transparent,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(3)),
          ),
        ),
        icon: Icon(icon),
        tooltip: tooltip,
        onPressed: onPressed,
        color: context.hudTheme.foreground,
        disabledColor: context.ui.colors.textMuted,
      ),
    ),
  );
}
