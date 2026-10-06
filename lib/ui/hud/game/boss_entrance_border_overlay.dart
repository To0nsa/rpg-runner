import 'package:flutter/widgets.dart';

import '../../../game/feedback/boss_entrance_feedback.dart';
import '../../../game/game_controller.dart';
import 'screen_border_vignette.dart';

/// Entrance vignette follows the shared Core-tick presentation envelope.
class BossEntranceBorderOverlay extends StatelessWidget {
  const BossEntranceBorderOverlay({super.key, required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final snapshot = controller.snapshot;
      final feedback = BossEntranceFeedbackFrame.sample(
        arena: snapshot.bossArena,
        tick: snapshot.tick,
        tickHz: controller.tickHz,
      );
      return ScreenBorderVignette(
        style: ScreenBorderVignetteStyle.bossEntrance,
        intensity: feedback.vignetteIntensity,
      );
    },
  );
}
