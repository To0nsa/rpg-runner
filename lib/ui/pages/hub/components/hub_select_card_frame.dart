import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/ui_tokens.dart';
import '../../../theme/ui_hub_theme.dart';

/// Shared frame for hub selection cards (level/character).
///
/// Owns layout contract: size, border, shadow, padding, clipping, and overlay.
class HubSelectCardFrame extends StatelessWidget {
  const HubSelectCardFrame({
    super.key,
    required this.background,
    required this.child,
    this.onTap,
  });

  final Widget background;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final hub = context.hub;

    // Card content with border, shadow, clipping, and overlay.
    final content = Container(
      // Card size
      width: hub.selectCardWidth,
      height: hub.selectCardHeight,
      // Card border, shadow, and border radius
      decoration: BoxDecoration(
        color: ui.colors.cardBackground,
        borderRadius: BorderRadius.circular(ui.radii.md),
        border: Border.all(
          color: ui.colors.outline,
          width: ui.sizes.borderWidth,
        ),
        boxShadow: ui.shadows.card,
      ),
      // Card content
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          math.max(0.0, ui.radii.md - ui.sizes.borderWidth),
        ),
        // Stack background, overlay, and padded child
        child: Stack(
          fit: StackFit.expand,
          children: [
            background,
            Padding(
              padding: EdgeInsets.fromLTRB(
                ui.space.md,
                ui.space.xs,
                ui.space.md,
                ui.space.md,
              ),
              child: child,
            ),
          ],
        ),
      ),
    );

    if (onTap == null) return content;

    return GestureDetector(onTap: onTap, child: content);
  }
}
