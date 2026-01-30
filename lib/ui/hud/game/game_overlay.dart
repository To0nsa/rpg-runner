import 'package:flutter/widgets.dart';

import '../../../game/game_controller.dart';
import '../../../game/input/aim_preview.dart';
import '../../../game/input/runner_input_router.dart';
import '../../controls/runner_controls_overlay.dart';
import 'package:rpg_runner/core/abilities/ability_def.dart';
import '../../runner_game_ui_state.dart';
import 'pause_overlay.dart';
import 'ready_overlay.dart';
import 'top_center_hud_overlay.dart';
import 'top_left_hud_overlay.dart';
import 'top_right_hud_overlay.dart';

class GameOverlay extends StatelessWidget {
  const GameOverlay({
    super.key,
    required this.controller,
    required this.input,
    required this.projectileAimPreview,
    required this.meleeAimPreview,
    required this.uiState,
    required this.onStart,
    required this.onTogglePause,
    required this.showExitButton,
    required this.onExit,
    required this.exitConfirmOpen,
    required this.onExitConfirmResume,
    required this.onExitConfirmExit,
  });

  final GameController controller;
  final RunnerInputRouter input;
  final AimPreviewModel projectileAimPreview;
  final AimPreviewModel meleeAimPreview;
  final RunnerGameUiState uiState;
  final VoidCallback onStart;
  final VoidCallback onTogglePause;
  final bool showExitButton;
  final VoidCallback? onExit;
  final bool exitConfirmOpen;
  final VoidCallback onExitConfirmResume;
  final VoidCallback onExitConfirmExit;

  @override
  Widget build(BuildContext context) {
    final hud = controller.snapshot.hud;

    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          ignoring: !uiState.isRunning,
          child: RunnerControlsOverlay(
            onMoveAxis: input.setMoveAxis,
            onJumpPressed: input.pressJump,
            onDashPressed: input.pressDash,
            onProjectileCommitted: () =>
                input.commitProjectileWithAim(clearAim: true),
            onProjectilePressed: input.pressProjectile,
            onProjectileAimDir: input.setProjectileAimDir,
            onProjectileAimClear: input.clearProjectileAimDir,
            projectileAimPreview: projectileAimPreview,
            projectileAffordable: hud.canAffordProjectile,
            projectileCooldownTicksLeft:
                hud.cooldownTicksLeft[CooldownGroup.projectile],
            projectileCooldownTicksTotal:
                hud.cooldownTicksTotal[CooldownGroup.projectile],
            onMeleeAimDir: input.setMeleeAimDir,
            onMeleeAimClear: input.clearMeleeAimDir,
            onMeleeCommitted: input.commitMeleeStrike,
            onMeleePressed: input.pressStrike,
            meleeAimPreview: meleeAimPreview,
            meleeAffordable: hud.canAffordMelee,
            meleeCooldownTicksLeft:
                hud.cooldownTicksLeft[CooldownGroup.primary],
            meleeCooldownTicksTotal:
                hud.cooldownTicksTotal[CooldownGroup.primary],
            meleeInputMode: hud.meleeInputMode,
            projectileInputMode: hud.projectileInputMode,
            jumpAffordable: hud.canAffordJump,
            dashAffordable: hud.canAffordDash,
            dashCooldownTicksLeft:
                hud.cooldownTicksLeft[CooldownGroup.mobility],
            dashCooldownTicksTotal:
                hud.cooldownTicksTotal[CooldownGroup.mobility],
          ),
        ),
        PauseOverlay(
          visible: uiState.showPauseOverlay,
          exitConfirmOpen: exitConfirmOpen,
          onResume: onExitConfirmResume,
          onExit: onExitConfirmExit,
        ),
        ReadyOverlay(visible: uiState.showReadyOverlay, onTap: onStart),
        Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: TopLeftHudOverlay(controller: controller),
          ),
        ),
        TopCenterHudOverlay(
          controller: controller,
          uiState: uiState,
          onStart: onStart,
          onTogglePause: onTogglePause,
        ),
        TopRightHudOverlay(
          controller: controller,
          showExitButton: showExitButton,
          onExit: onExit,
        ),
      ],
    );
  }
}
