import 'package:flutter/material.dart';

import '../../runner_game_ui_state.dart';

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
    return IconButton(
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
    );
  }
}
