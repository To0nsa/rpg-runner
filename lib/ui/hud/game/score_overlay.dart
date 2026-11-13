import 'package:rpg_runner/ui/l10n/app_localization.dart';
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
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => RunStatsPanel(
        distanceMeters: distanceUnitsToMeters(controller.snapshot.distance),
        collectibles: controller.snapshot.hud.collectibles,
        padding: padding,
      ),
    );
  }
}

/// Shared counter presentation; the authoring canvas supplies example values.
class RunStatsPanel extends StatelessWidget {
  const RunStatsPanel({
    super.key,
    required this.distanceMeters,
    required this.collectibles,
    this.padding,
  });
  final int distanceMeters, collectibles;
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
    return IgnorePointer(
      child: RepaintBoundary(
        child: HudPanel(
          padding: resolvedPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                context.l10n.scoreDistance(meters: distanceMeters),
                textAlign: TextAlign.center,
                style: labelStyle,
              ),
              SizedBox(height: ui.space.xxs / 2),
              Text(
                context.l10n.scoreCollectibles(count: collectibles),
                textAlign: TextAlign.center,
                style: labelStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
