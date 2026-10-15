import 'package:flutter/widgets.dart';
import 'package:runner_core/scoring/run_distance.dart';

import '../../../game/game_controller.dart';
import '../../theme/ui_tokens.dart';
import '../../theme/ui_hud_theme.dart';
import '../../components/hud_frame.dart';

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
      fontFamily: 'Inter',
      fontSize: 11,
      color: context.hudTheme.foreground,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final distanceMeters = distanceUnitsToMeters(
          controller.snapshot.distance,
        );
        final collectibles = controller.snapshot.hud.collectibles;
        return IgnorePointer(
          child: RepaintBoundary(
            child: HudPanel(
              padding: resolvedPadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
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
