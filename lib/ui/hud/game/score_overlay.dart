import 'package:flutter/widgets.dart';

import '../../../game/game_controller.dart';
import '../../theme/ui_tokens.dart';

class ScoreOverlay extends StatelessWidget {
  const ScoreOverlay({super.key, required this.controller, this.padding});

  final GameController controller;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final resolvedPadding =
        padding ??
        EdgeInsets.symmetric(
          horizontal: ui.space.xs + ui.space.xxs / 2,
          vertical: ui.space.xs - ui.space.xxs / 2,
        );
    final labelStyle = ui.text.body.copyWith(
      color: ui.colors.textPrimary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final distanceMeters = (controller.snapshot.distance / 100.0).floor();
        final collectibles = controller.snapshot.hud.collectibles;
        return IgnorePointer(
          child: RepaintBoundary(
            child: Container(
              padding: resolvedPadding,
              decoration: BoxDecoration(
                color: ui.colors.shadow.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(ui.radii.sm),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Distance ${distanceMeters}m',
                    textAlign: TextAlign.center,
                    style: labelStyle,
                  ),
                  SizedBox(height: ui.space.xxs / 2),
                  Text(
                    'Collectibles $collectibles',
                    textAlign: TextAlign.center,
                    style: labelStyle,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
