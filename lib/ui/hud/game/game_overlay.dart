import 'package:flutter/widgets.dart';

import '../../../game/game_controller.dart';
import '../../../game/input/aim_preview.dart';
import '../../../game/input/runner_input_router.dart';
import '../../controls/runner_controls_overlay.dart';
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
            onCastCommitted: () => input.commitCastWithAim(clearAim: true),
            onProjectileAimDir: input.setProjectileAimDir,
            onProjectileAimClear: input.clearProjectileAimDir,
            projectileAimPreview: projectileAimPreview,
            projectileAffordable: hud.canAffordProjectile,
            projectileCooldownTicksLeft: hud.projectileCooldownTicksLeft,
            projectileCooldownTicksTotal: hud.projectileCooldownTicksTotal,
            onMeleeAimDir: input.setMeleeAimDir,
            onMeleeAimClear: input.clearMeleeAimDir,
            onMeleeCommitted: input.commitMeleeAttack,
            meleeAimPreview: meleeAimPreview,
            meleeAffordable: hud.canAffordMelee,
            meleeCooldownTicksLeft: hud.meleeCooldownTicksLeft,
            meleeCooldownTicksTotal: hud.meleeCooldownTicksTotal,
            jumpAffordable: hud.canAffordJump,
            dashAffordable: hud.canAffordDash,
            dashCooldownTicksLeft: hud.dashCooldownTicksLeft,
            dashCooldownTicksTotal: hud.dashCooldownTicksTotal,
          ),
        ),
        PauseOverlay(visible: uiState.showPauseOverlay),
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
