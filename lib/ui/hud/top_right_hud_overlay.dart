import 'package:flutter/material.dart';

import '../../game/game_controller.dart';
import 'score_overlay.dart';

class TopRightHudOverlay extends StatelessWidget {
  const TopRightHudOverlay({
    super.key,
    required this.controller,
    required this.showExitButton,
    required this.onExit,
  });

  final GameController controller;
  final bool showExitButton;
  final VoidCallback? onExit;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScoreOverlay(controller: controller),
            if (showExitButton) ...[
              const SizedBox(width: 8),
              IconButton(
                onPressed: onExit,
                icon: const Icon(Icons.close),
                color: Colors.white,
                disabledColor: Colors.white,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
