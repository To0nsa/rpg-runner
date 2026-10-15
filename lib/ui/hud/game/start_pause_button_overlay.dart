import 'package:flutter/material.dart';

import '../../runner_game_ui_state.dart';
import '../../components/hud_frame.dart';
import '../../theme/ui_hud_theme.dart';

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
    return HudPanel(
      child: IconButton(
        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(3)),
          ),
        ),
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
        color: context.hudTheme.foreground,
        tooltip: uiState.paused ? 'Play' : 'Pause',
      ),
    );
  }
}
