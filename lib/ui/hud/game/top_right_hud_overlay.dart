import 'package:rpg_runner/ui/l10n/app_localization.dart';
import 'package:flutter/material.dart';

import '../../../game/game_controller.dart';
import 'run_hud_actions_row.dart';
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
    this.showStart = true,
    this.showStats = true,
    this.tutorialPaused = false,
    this.statsTargetKey,
  });

  final GameController controller;
  final RunnerGameUiState uiState;
  final VoidCallback onStart;
  final VoidCallback onTogglePause;
  final bool showExitButton;
  final VoidCallback? onExit;
  final bool showStart, showStats, tutorialPaused;
  final Key? statsTargetKey;

  @override
  Widget build(BuildContext context) {
    return RunHudActionsRow(
      stats: showStats
          ? ScoreOverlay(key: statsTargetKey, controller: controller)
          : null,
      pause: showStart || uiState.started
          ? StartPauseButtonOverlay(
              uiState: tutorialPaused
                  ? RunnerGameUiState(
                      started: uiState.started,
                      paused: false,
                      gameOver: uiState.gameOver,
                      runLoaded: uiState.runLoaded,
                    )
                  : uiState,
              onStart: onStart,
              onTogglePause: onTogglePause,
            )
          : null,
      exit: showExitButton
          ? HudIconButton(
              onPressed: onExit,
              icon: Icons.close,
              tooltip: context.l10n.exitGameTooltip,
            )
          : null,
    );
  }
}
