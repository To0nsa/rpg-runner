import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:runner_core/contracts/render_contract.dart';

import '../game/runner_flame_game.dart';
import '../game/runner_gameplay_runtime.dart';
import 'input/desktop/runner_desktop_aim_geometry.dart';
import 'input/desktop/runner_desktop_input_adapter.dart';
import 'input/runner_gameplay_bindings.dart';
import 'tutorial/campaign_tutorial_geometry.dart';
import 'viewport/game_viewport.dart';
import 'viewport/viewport_metrics.dart';

/// One coordinate space for rendering, HUD and desktop input in every host.
/// Borrows the attempt and bindings; the mode owns lifecycle and all overlays.
class RunnerGameplaySurface extends StatefulWidget {
  const RunnerGameplaySurface({
    super.key,
    required this.runtime,
    required this.bindings,
    required this.onLoadError,
    required this.overlayBuilder,
    this.viewportMode = ViewportScaleMode.pixelPerfectContain,
    this.alignment = Alignment.center,
  });

  final RunnerGameplayRuntime runtime;
  final RunnerGameplayBindings bindings;
  final ViewportScaleMode viewportMode;
  final Alignment alignment;
  final ValueChanged<Object> onLoadError;
  final Widget Function(BuildContext context, ViewportMetrics metrics)
  overlayBuilder;

  @override
  State<RunnerGameplaySurface> createState() => RunnerGameplaySurfaceState();
}

class RunnerGameplaySurfaceState extends State<RunnerGameplaySurface> {
  // Read layout on demand at the completed tick, never mutate tutorial state
  // during build. Rebinding/detachment follows the borrowed attempt's lifetime.
  Rect? _tutorialViewport() => visibleWorldBounds;

  @override
  void initState() {
    super.initState();
    widget.bindings.tutorial.resolveVisibleWorldBounds = _tutorialViewport;
  }

  void _detachTutorialViewport(RunnerGameplayBindings bindings) {
    if (bindings.tutorial.resolveVisibleWorldBounds == _tutorialViewport) {
      bindings.tutorial.resolveVisibleWorldBounds = null;
    }
  }

  @override
  void didUpdateWidget(covariant RunnerGameplaySurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.bindings, widget.bindings)) {
      _detachTutorialViewport(oldWidget.bindings);
      widget.bindings.tutorial.resolveVisibleWorldBounds = _tutorialViewport;
    }
  }

  @override
  void dispose() {
    _detachTutorialViewport(widget.bindings);
    super.dispose();
  }

  /// Current visible world area, excluding cropped canvas outside this device.
  Rect? get visibleWorldBounds {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || box.size.isEmpty) return null;
    return campaignTutorialVisibleWorldBounds(
      widget.runtime.controller.snapshot.camera,
      _metrics(box.size),
      box.size,
    );
  }

  // Switching desktop/touch wrappers must reparent the live GameWidget instead
  // of unmounting and disposing its attempt's render resources.
  final _viewKey = GlobalKey();
  ViewportMetrics _metrics(Size size) => computeViewportMetrics(
    BoxConstraints.tight(size),
    MediaQuery.devicePixelRatioOf(context),
    virtualWidth,
    virtualHeight,
    widget.viewportMode,
    alignment: widget.alignment,
  );

  /// Adapter coordinates have already passed through the preview transform.
  RunnerDesktopAimGeometry? get aimGeometry {
    final box = context.findRenderObject();
    final snapshot = widget.runtime.controller.snapshot;
    final player = snapshot.playerEntity;
    if (box is! RenderBox ||
        !box.hasSize ||
        box.size.isEmpty ||
        player == null) {
      return null;
    }
    return RunnerDesktopAimGeometry.fromWorld(
      metrics: _metrics(box.size),
      camera: snapshot.camera,
      playerWorldPosition: Offset(player.pos.x, player.pos.y),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final metrics = _metrics(constraints.biggest);
      final game = widget.runtime.game;
      final view = GameViewport(
        key: _viewKey,
        metrics: metrics,
        child: GameWidget<RunnerFlameGame>(
          key: ObjectKey(game),
          game: game,
          autofocus: false,
          loadingBuilder: (_) => const SizedBox.expand(),
          errorBuilder: (_, error) => _LoadFailure(
            key: ObjectKey(game),
            error: error,
            onError: widget.onLoadError,
          ),
        ),
      );
      return Stack(
        fit: StackFit.expand,
        children: [
          if (widget.bindings.desktop case final desktop?)
            RunnerDesktopInputAdapter(controller: desktop, child: view)
          else
            view,
          widget.overlayBuilder(context, metrics),
        ],
      );
    },
  );
}

class _LoadFailure extends StatefulWidget {
  const _LoadFailure({super.key, required this.error, required this.onError});
  final Object error;
  final ValueChanged<Object> onError;
  @override
  State<_LoadFailure> createState() => _LoadFailureState();
}

class _LoadFailureState extends State<_LoadFailure> {
  @override
  void initState() {
    super.initState();
    _report();
  }

  @override
  void didUpdateWidget(covariant _LoadFailure oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.error, widget.error)) _report();
  }

  void _report() {
    final error = widget.error;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(widget.error, error)) widget.onError(error);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
