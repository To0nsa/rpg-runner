import 'package:flutter/material.dart';

import '../../../game/game_controller.dart';
import 'survival_timer_overlay.dart';
import '../../runner_game_ui_state.dart';
import 'start_pause_button_overlay.dart';

class TopCenterHudOverlay extends StatelessWidget {
  const TopCenterHudOverlay({
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
            StartPauseButtonOverlay(
              uiState: uiState,
              onStart: onStart,
              onTogglePause: onTogglePause,
            ),
          ],
        ),
      ),
    );
  }
}
