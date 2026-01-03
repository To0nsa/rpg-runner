import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../core/contracts/v0_render_contract.dart';
import '../core/game_core.dart';
import '../game/game_controller.dart';
import '../game/input/aim_preview.dart';
import '../game/input/runner_input_router.dart';
import '../game/runner_flame_game.dart';
import 'controls/runner_controls_overlay.dart';
import 'hud/player_hud_overlay.dart';
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

  late final GameController _controller = GameController(
    core: GameCore(seed: widget.seed),
  );
  late final RunnerInputRouter _input =
      RunnerInputRouter(controller: _controller);
  late final AimPreviewModel _aimPreview = AimPreviewModel();
  late final RunnerFlameGame _game = RunnerFlameGame(
    controller: _controller,
    input: _input,
    aimPreview: _aimPreview,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _onLifecycle(state);

  void _onLifecycle(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_pausedByLifecycle) {
        _pausedByLifecycle = false;
        _controller.setPaused(false);
      }
      return;
    }
    _pausedByLifecycle = true;
    _controller.setPaused(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.shutdown();
    _controller.dispose();
    _aimPreview.dispose();
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
              child: GameWidget(game: _game, autofocus: false),
            );

            return gameView;
          },
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: PlayerHudOverlay(controller: _controller),
            ),
          ),
        ),
        RunnerControlsOverlay(
          onMoveAxis: _input.setMoveAxis,
          onJumpPressed: _input.pressJump,
          onDashPressed: _input.pressDash,
          onAttackPressed: _input.pressAttack,
          onCastCommitted: () => _input.commitCastWithAim(clearAim: true),
          onAimDir: _input.setAimDir,
          onAimClear: _input.clearAimDir,
          aimPreview: _aimPreview,
        ),
        if (widget.showExitButton)
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  onPressed: widget.onExit,
                  icon: const Icon(Icons.close),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
