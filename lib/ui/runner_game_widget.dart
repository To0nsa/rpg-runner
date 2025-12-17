import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../core/contracts/v0_render_contract.dart';
import '../core/game_core.dart';
import '../game/game_controller.dart';
import '../game/runner_flame_game.dart';
import 'pixel_perfect_viewport.dart';

/// Embed-friendly widget that hosts the mini-game.
///
/// Intended to be mounted by a host app. It can either create its own
/// [GameController] (widget-owned) or accept one from the host (host-owned).
///
/// Pixel scaling is applied by [PixelPerfectViewport] to keep the fixed virtual
/// resolution letterboxed to the available screen.
class RunnerGameWidget extends StatefulWidget {
  const RunnerGameWidget({
    super.key,
    this.seed = 1,
    this.controller,
    this.onExit,
    this.showExitButton = true,
  });

  /// Only used if [controller] is null (widget-owned controller).
  final int seed;

  /// If provided, the host owns the controller lifecycle.
  final GameController? controller;

  final VoidCallback? onExit;
  final bool showExitButton;

  @override
  State<RunnerGameWidget> createState() => _RunnerGameWidgetState();
}

class _RunnerGameWidgetState extends State<RunnerGameWidget>
    with WidgetsBindingObserver {
  bool _pausedByLifecycle = false;

  late final GameController _controller =
      widget.controller ?? GameController(core: GameCore(seed: widget.seed));
  late final RunnerFlameGame _game = RunnerFlameGame(controller: _controller);

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
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
    );
  }
}
