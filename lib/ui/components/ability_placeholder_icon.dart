import 'package:flutter/material.dart';

import '../theme/ui_tokens.dart';

/// Neutral placeholder icon for abilities while dedicated art is not available.
///
/// The icon intentionally stays minimal: transparent fill, thin border, and
/// a short text label (typically 1-3 characters).
class AbilityPlaceholderIcon extends StatelessWidget {
  const AbilityPlaceholderIcon({
    super.key,
    required this.label,
    this.size = 22,
    this.emphasis = false,
    this.enabled = true,
  });

  final String label;
  final double size;
  final bool emphasis;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final borderColor = emphasis
        ? ui.colors.accentStrong
        : ui.colors.outline.withValues(alpha: enabled ? 0.65 : 0.35);
    final textColor = enabled
        ? ui.colors.textPrimary
        : ui.colors.textMuted.withValues(alpha: 0.75);
    final radius = (size * 0.28).clamp(4.0, 8.0);

    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Center(
          child: Text(
            label,
            style: ui.text.body.copyWith(
              color: textColor,
              fontSize: (size * 0.34).clamp(8.0, 11.0),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              height: 1.0,
            ),
            maxLines: 1,
            overflow: TextOverflow.clip,
          ),
        ),
      ),
    );
  }
}
