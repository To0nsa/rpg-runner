import 'package:flutter/material.dart';

import '../../../theme/ui_hub_theme.dart';
import '../../../theme/ui_tokens.dart';
import '../../../theme/ui_world_palette.dart';

/// One clipped frame; selecting the artwork never activates its footer action.
class HubSelectCardFrame extends StatelessWidget {
  const HubSelectCardFrame({
    super.key,
    required this.background,
    required this.child,
    required this.footer,
    required this.onTap,
  });

  final Widget background, child, footer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final hub = context.hub;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 220;
        final scaler = MediaQuery.textScalerOf(context);
        final textGrowth = (scaler.scale(14) - 14).clamp(0.0, double.infinity);
        // Enlarged names get a third line; reserve room for wrapped footers too.
        final extraTitleLine = scaler.scale(14) > 16.8
            ? scaler.scale(hub.title.fontSize!) * hub.title.height!
            : 0.0;
        return SizedBox(
          width: hub.selectCardWidth,
          height:
              (compact ? 196 : hub.selectCardHeight) +
              textGrowth * (compact ? 16 : 8) +
              extraTitleLine,
          child: Material(
            color: hub.surface,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: hub.outline),
              borderRadius: BorderRadius.circular(ui.radii.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      background,
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              UiWorldPalette.ink900.withValues(alpha: .55),
                              UiWorldPalette.ink900.withValues(alpha: .25),
                              UiWorldPalette.ink900.withValues(alpha: .92),
                            ],
                          ),
                        ),
                      ),
                      // A transparent Material keeps feedback above the artwork.
                      Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          onTap: onTap,
                          child: Padding(
                            padding: EdgeInsets.all(
                              compact ? ui.space.sm : ui.space.md,
                            ),
                            child: child,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                footer,
              ],
            ),
          ),
        );
      },
    );
  }
}
