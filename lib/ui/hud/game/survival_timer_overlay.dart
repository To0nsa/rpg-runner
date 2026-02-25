import 'package:flutter/widgets.dart';

import '../../../game/game_controller.dart';
import '../../theme/ui_tokens.dart';

class SurvivalTimerOverlay extends StatelessWidget {
  const SurvivalTimerOverlay({
    super.key,
    required this.controller,
    this.padding,
  });

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
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final ticks = controller.snapshot.tick;
        final hz = controller.tickHz;

        final totalSeconds = ticks ~/ hz;
        final minutes = totalSeconds ~/ 60;
        final seconds = totalSeconds % 60;

        final text =
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

        return IgnorePointer(
          child: RepaintBoundary(
            child: Container(
              padding: resolvedPadding,
              decoration: BoxDecoration(
                color: ui.colors.shadow.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(ui.radii.sm),
              ),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: ui.text.headline.copyWith(
                  color: ui.colors.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
