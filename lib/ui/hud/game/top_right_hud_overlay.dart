import 'package:flutter/material.dart';

import '../../../game/game_controller.dart';
import '../../theme/ui_tokens.dart';
import '../../components/hud_icon_button.dart';
import '../../runner_game_ui_state.dart';
import 'score_overlay.dart';
import 'start_pause_button_overlay.dart';

class TopRightHudOverlay extends StatelessWidget {
  const TopRightHudOverlay({
    super.key,
    required this.controller,
    required this.uiState,
    required this.onStart,
    required this.onTogglePause,
    required this.showExitButton,
    required this.onExit,
  });

  final GameController controller;
  final RunnerGameUiState uiState;
  final VoidCallback onStart;
  final VoidCallback onTogglePause;
  final bool showExitButton;
  final VoidCallback? onExit;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return IntrinsicHeight(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScoreOverlay(controller: controller),
          SizedBox(width: ui.space.xs),
          StartPauseButtonOverlay(
            uiState: uiState,
            onStart: onStart,
            onTogglePause: onTogglePause,
          ),
          if (showExitButton) ...[
            SizedBox(width: ui.space.xs),
            HudIconButton(
              onPressed: onExit,
              icon: Icons.close,
              tooltip: 'Exit game',
            ),
          ],
        ],
      ),
    );
  }
}
