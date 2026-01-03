import 'package:flutter/material.dart';

import '../../game/game_controller.dart';
import 'survival_timer_overlay.dart';
import '../runner_game_ui_state.dart';

class TimerRowOverlay extends StatelessWidget {
  const TimerRowOverlay({
    super.key,
    required this.controller,
    required this.uiState,
    required this.onStart,
    required this.onTogglePause,
  });

  final GameController controller;
  final RunnerGameUiState uiState;
  final VoidCallback onStart;
  final VoidCallback onTogglePause;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SurvivalTimerOverlay(controller: controller),
            const SizedBox(width: 8),
            IconButton(
              onPressed: uiState.gameOver
                  ? null
                  : () {
                      if (!uiState.started) {
                        onStart();
                        return;
                      }
                      onTogglePause();
                    },
              icon: Icon(uiState.paused ? Icons.play_arrow : Icons.pause),
              color: Colors.white,
              tooltip: uiState.paused ? 'Play' : 'Pause',
            ),
          ],
        ),
      ),
    );
  }
}
