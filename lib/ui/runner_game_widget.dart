import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../core/contracts/v0_render_contract.dart';
import '../core/game_core.dart';
import '../game/game_controller.dart';
import '../game/input/aim_preview.dart';
import '../game/input/runner_input_router.dart';
import '../game/runner_flame_game.dart';
import 'controls/runner_controls_overlay.dart';
import 'hud/game_over_overlay.dart';
import 'hud/player_hud_overlay.dart';
import 'hud/pause_overlay.dart';
import 'hud/ready_overlay.dart';
import 'hud/top_right_hud_overlay.dart';
import 'hud/timer_row_overlay.dart';
import 'runner_game_ui_state.dart';
import 'viewport/game_viewport.dart';
import 'viewport/viewport_metrics.dart';

/// Embed-friendly widget that hosts the mini-game.
///
/// Intended to be mounted by a host app. It owns its [GameController] and
/// cleans it up on dispose.
///
/// Viewport scaling is applied by [GameViewport] to keep the fixed virtual
/// resolution fitted to the available screen.
class RunnerGameWidget extends StatefulWidget {
  const RunnerGameWidget({
    super.key,
    this.seed = 1,
    this.onExit,
    this.showExitButton = true,
    this.viewportMode = ViewportScaleMode.pixelPerfectContain,
    this.viewportAlignment = Alignment.center,
  });

  final int seed;

  final VoidCallback? onExit;
  final bool showExitButton;

  /// How the game view is scaled to the available screen.
  final ViewportScaleMode viewportMode;

  /// Where the scaled view is placed within the available screen.
  final Alignment viewportAlignment;

  @override
  State<RunnerGameWidget> createState() => _RunnerGameWidgetState();
}

class _RunnerGameWidgetState extends State<RunnerGameWidget>
    with WidgetsBindingObserver {
  bool _pausedByLifecycle = false;
  bool _started = false;

  late GameController _controller;
  late RunnerInputRouter _input;
  late AimPreviewModel _projectileAimPreview;
  late AimPreviewModel _meleeAimPreview;
  late RunnerFlameGame _game;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _initGame();

    // Start in "ready" (paused) until the user taps to begin.
    _controller.setPaused(true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _onLifecycle(state);

  void _onLifecycle(AppLifecycleState state) {
    final uiState = _buildUiState();
    if (state == AppLifecycleState.resumed) {
      if (_pausedByLifecycle && uiState.started && !uiState.gameOver) {
        _pausedByLifecycle = false;
        _controller.setPaused(false);
      }
      return;
    }

    // Only mark lifecycle-paused if we were actually running.
    _pausedByLifecycle = uiState.isRunning;
    _controller.setPaused(true);
    _clearInputs();
  }

  void _clearInputs() {
    _input.setMoveAxis(0);
    _input.clearProjectileAimDir();
    _input.clearMeleeAimDir();
    _projectileAimPreview.end();
    _meleeAimPreview.end();
    _input.pumpHeldInputs();
  }

  RunnerGameUiState _buildUiState() {
    final snapshot = _controller.snapshot;
    return RunnerGameUiState(
      started: _started,
      paused: snapshot.paused,
      gameOver: snapshot.gameOver,
    );
  }

  void _startGame() {
    setState(() => _started = true);
    _clearInputs();
    _controller.setPaused(false);
  }

  void _restartGame() {
    final oldController = _controller;
    final oldProjectilePreview = _projectileAimPreview;
    final oldMeleePreview = _meleeAimPreview;

    setState(() {
      _pausedByLifecycle = false;
      _started = false;
      _initGame();
    });
    _controller.setPaused(true);
    _clearInputs();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      oldController.shutdown();
      oldController.dispose();
      oldProjectilePreview.dispose();
      oldMeleePreview.dispose();
    });
  }

  void _togglePause() {
    final paused = _controller.snapshot.paused;
    if (!paused) _clearInputs();
    _controller.setPaused(!paused);
  }

  void _initGame() {
    _controller = GameController(core: GameCore(seed: widget.seed));
    _input = RunnerInputRouter(controller: _controller);
    _projectileAimPreview = AimPreviewModel();
    _meleeAimPreview = AimPreviewModel();
    _game = RunnerFlameGame(
      controller: _controller,
      input: _input,
      projectileAimPreview: _projectileAimPreview,
      meleeAimPreview: _meleeAimPreview,
    );
  }

  void _disposeGame() {
    _controller.shutdown();
    _controller.dispose();
    _projectileAimPreview.dispose();
    _meleeAimPreview.dispose();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeGame();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
            final metrics = computeViewportMetrics(
              constraints,
              devicePixelRatio,
              v0VirtualWidth,
              v0VirtualHeight,
              widget.viewportMode,
              alignment: widget.viewportAlignment,
            );
            Widget gameView = GameViewport(
              metrics: metrics,
              child: GameWidget(
                key: ValueKey(_game),
                game: _game,
                autofocus: false,
              ),
            );

            return gameView;
          },
        ),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final uiState = _buildUiState();
            final hud = _controller.snapshot.hud;
            if (uiState.gameOver) {
              final runEndedEvent = _controller.lastRunEndedEvent;
              final runEndKey = runEndedEvent?.tick ?? _controller.snapshot.tick;
              return GameOverOverlay(
                key: ValueKey('gameOver-$runEndKey-${runEndedEvent?.reason}'),
                visible: true,
                onRestart: _restartGame,
                onExit: widget.onExit,
                showExitButton: widget.showExitButton,
                runEndedEvent: runEndedEvent,
                scoreTuning: _controller.scoreTuning,
                tickHz: _controller.tickHz,
              );
            }
            return Stack(
              fit: StackFit.expand,
              children: [
                IgnorePointer(
                  ignoring: !uiState.isRunning,
                  child: RunnerControlsOverlay(
                    onMoveAxis: _input.setMoveAxis,
                    onJumpPressed: _input.pressJump,
                    onDashPressed: _input.pressDash,
                    onCastCommitted: () =>
                        _input.commitCastWithAim(clearAim: true),
                    onProjectileAimDir: _input.setProjectileAimDir,
                    onProjectileAimClear: _input.clearProjectileAimDir,
                    projectileAimPreview: _projectileAimPreview,
                    projectileAffordable: hud.canAffordProjectile,
                    projectileCooldownTicksLeft:
                        hud.projectileCooldownTicksLeft,
                    projectileCooldownTicksTotal:
                        hud.projectileCooldownTicksTotal,
                    onMeleeAimDir: _input.setMeleeAimDir,
                    onMeleeAimClear: _input.clearMeleeAimDir,
                    onMeleeCommitted: _input.commitMeleeAttack,
                    meleeAimPreview: _meleeAimPreview,
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
                ReadyOverlay(
                  visible: uiState.showReadyOverlay,
                  onTap: _startGame,
                ),
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: PlayerHudOverlay(controller: _controller),
                  ),
                ),
                TimerRowOverlay(
                  controller: _controller,
                  uiState: uiState,
                  onStart: _startGame,
                  onTogglePause: _togglePause,
                ),
                TopRightHudOverlay(
                  controller: _controller,
                  showExitButton: widget.showExitButton,
                  onExit: uiState.started && !uiState.gameOver
                      ? _controller.giveUp
                      : widget.onExit,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
