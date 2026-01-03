import 'dart:ui' show Color, FontFeature;

import 'package:flutter/widgets.dart';

import '../../game/game_controller.dart';

class ScoreOverlay extends StatelessWidget {
  const ScoreOverlay({
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
        final score = controller.snapshot.hud.score;
        return IgnorePointer(
          child: RepaintBoundary(
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                color: const Color(0x66000000),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Score $score',
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
