import 'package:flutter/widgets.dart';

import '../../game/game_controller.dart';

class SurvivalTimerOverlay extends StatelessWidget {
  const SurvivalTimerOverlay({
    super.key,
    required this.controller,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  });

  final GameController controller;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
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
              padding: padding,
              decoration: BoxDecoration(
                color: const Color(0x66000000),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  color: Color(0xFFFFFFFF),
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
