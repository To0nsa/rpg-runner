import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'screen_border_vignette.dart';

/// Full-screen red border pulse for direct player impact feedback.
class PlayerImpactBorderOverlay extends StatelessWidget {
  const PlayerImpactBorderOverlay({super.key, required this.triggerSignal});

  final ValueListenable<int> triggerSignal;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: ValueListenableBuilder<int>(
        valueListenable: triggerSignal,
        builder: (context, trigger, _) {
          if (trigger == 0) {
            return const SizedBox.expand();
          }
          return TweenAnimationBuilder<double>(
            key: ValueKey(trigger),
            tween: Tween<double>(begin: 1.0, end: 0.0),
            duration: const Duration(milliseconds: 340),
            curve: Curves.easeOutCubic,
            builder: (context, intensity, _) {
              if (intensity <= 0.001) {
                return const SizedBox.expand();
              }
              return ScreenBorderVignette(
                style: ScreenBorderVignetteStyle.playerImpact,
                intensity: intensity,
              );
            },
          );
        },
      ),
    );
  }
}
