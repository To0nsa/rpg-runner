import 'package:flutter/material.dart';

import '../../../game/game_controller.dart';
import 'survival_timer_overlay.dart';
import '../../runner_game_ui_state.dart';
import '../../theme/ui_tokens.dart';
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
    final ui = context.ui;
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(top: ui.space.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SurvivalTimerOverlay(controller: controller),
            SizedBox(width: ui.space.xs),
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
