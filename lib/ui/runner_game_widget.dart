import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/game_core.dart';
import '../core/contracts/v0_render_contract.dart';
import '../game/game_controller.dart';
import '../game/runner_flame_game.dart';
import 'pixel_perfect_viewport.dart';
import 'providers.dart';

/// Embed-friendly widget that hosts the mini-game.
///
/// Intended to be mounted by a host app. It owns the `GameController` and
/// provides it to Flutter overlays via Riverpod.
///
/// Pixel scaling is applied by [PixelPerfectViewport] to keep the fixed virtual
/// resolution letterboxed to the available screen.
class RunnerGameWidget extends StatefulWidget {
  const RunnerGameWidget({
    super.key,
    this.seed = 1,
    this.onExit,
    this.showExitButton = true,
  });

  final int seed;
  final VoidCallback? onExit;
  final bool showExitButton;

  @override
  State<RunnerGameWidget> createState() => _RunnerGameWidgetState();
}

class _RunnerGameWidgetState extends State<RunnerGameWidget>
    with WidgetsBindingObserver {
  bool _pausedByLifecycle = false;
  late final GameController _controller;
  late final RunnerFlameGame _game;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = GameController(core: GameCore(seed: widget.seed));
    _game = RunnerFlameGame(controller: _controller);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _onLifecycle(state);

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        gameControllerProvider.overrideWithValue(_controller),
      ],
      child: Stack(
        fit: StackFit.expand,
        children: [
          PixelPerfectViewport(
            virtualWidth: v0VirtualWidth,
            virtualHeight: v0VirtualHeight,
            child: GameWidget(game: _game),
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
      ),
    );
  }
}
