import 'package:flutter/material.dart';

import '../../runner_game_ui_state.dart';
import '../../components/hud_icon_button.dart';

class StartPauseButtonOverlay extends StatelessWidget {
  const StartPauseButtonOverlay({
    super.key,
    required this.uiState,
    required this.onStart,
    required this.onTogglePause,
  });

  final RunnerGameUiState uiState;
  final VoidCallback onStart;
  final VoidCallback onTogglePause;

  @override
  Widget build(BuildContext context) {
    return HudIconButton(
      onPressed: uiState.gameOver
          ? null
          : () {
              if (!uiState.started) {
                onStart();
                return;
              }
              onTogglePause();
            },
      icon: uiState.paused ? Icons.play_arrow : Icons.pause,
      tooltip: uiState.paused ? 'Play' : 'Pause',
    );
  }
}
