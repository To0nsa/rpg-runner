import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../core/contracts/v0_render_contract.dart';
import '../core/game_core.dart';
import '../game/game_controller.dart';
import '../game/input/runner_input_router.dart';
import '../game/input/aim_preview.dart';
import '../game/runner_flame_game.dart';
import 'controls/runner_controls_overlay.dart';
import 'input/debug_keyboard_adapter.dart';
import 'input/debug_mouse_adapter.dart';
import 'pixel_perfect_viewport.dart';
import 'input/touch_game_view_adapter.dart';
import 'input/v0_viewport_mapper.dart';

/// Embed-friendly widget that hosts the mini-game.
///
/// Intended to be mounted by a host app. It owns its [GameController] and
/// cleans it up on dispose.
///
/// Pixel scaling is applied by [PixelPerfectViewport] to keep the fixed virtual
/// resolution letterboxed to the available screen.
class RunnerGameWidget extends StatefulWidget {
  const RunnerGameWidget({
    super.key,
    this.seed = 1,
    this.onExit,
    this.showExitButton = true,
    this.enableDebugInput = false,
  });

  final int seed;

  final VoidCallback? onExit;
  final bool showExitButton;
  final bool enableDebugInput;

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
            final mapper = V0ViewportMapper.fromConstraints(
              constraints,
              devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
            );

            Widget gameView = PixelPerfectViewport(
              virtualWidth: v0VirtualWidth,
              virtualHeight: v0VirtualHeight,
              child: GameWidget(game: _game, autofocus: false),
            );

            gameView = TouchGameViewAdapter(
              controller: _controller,
              input: _input,
              mapper: mapper,
              enableTapCast: false,
              child: gameView,
            );

            if (widget.enableDebugInput) {
              gameView = DebugMouseAdapter(
                controller: _controller,
                input: _input,
                mapper: mapper,
                child: gameView,
              );
              gameView = DebugKeyboardAdapter(input: _input, child: gameView);
            }

            return gameView;
          },
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
          Positioned(
            top: 8,
            left: 8,
            child: SafeArea(
              child: IconButton(
                onPressed: widget.onExit,
                icon: const Icon(Icons.close),
              ),
            ),
          ),
      ],
    );
  }
}
