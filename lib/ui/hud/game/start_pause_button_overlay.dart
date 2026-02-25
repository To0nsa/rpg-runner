import 'package:flutter/material.dart';

import '../../runner_game_ui_state.dart';
import '../../theme/ui_tokens.dart';

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
    final ui = context.ui;
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
      color: ui.colors.textPrimary,
      tooltip: uiState.paused ? 'Play' : 'Pause',
    );
  }
}
