import 'package:flame/cache.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:runner_core/contracts/render_contract.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/playtest/chunk_playtest_scenario.dart';
import 'package:runner_core/playtest/level_playtest_scenario.dart';
import 'package:runner_core/playtest/playtest_scenario.dart';

import 'runner_playtest_appearance.dart';

import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/snapshots/game_state_snapshot.dart';

import '../game/game_controller.dart';
import '../game/input/aim_preview.dart';
import '../game/input/runner_gameplay_action.dart';
import '../game/input/runner_input_router.dart';
import '../game/input/runner_semantic_action_dispatcher.dart';
import '../game/runner_flame_game.dart';
import '../ui/input/desktop/runner_desktop_aim_geometry.dart';
import '../ui/input/desktop/runner_desktop_input_adapter.dart';
import '../ui/viewport/game_viewport.dart';
import '../ui/viewport/viewport_metrics.dart';
import 'runner_workspace_asset_bundle.dart';

/// Creates a fresh isolated Flame image cache for one runtime generation.
typedef RunnerPlaytestImagesFactory = Images Function(AssetBundle? assetBundle);

/// Backend-free lifecycle states published by the authored playtest host.
enum RunnerPlaytestPhase {
  /// A fresh runtime is resolving and loading its render assets.
  loading,

  /// The runtime is loaded at tick zero and awaits explicit start.
  ready,

  /// Core simulation and gameplay input are active.
  running,

  /// Core simulation and gameplay input are both suspended.
  paused,

  /// Core reached a terminal state without product settlement side effects.
  gameOver,

  /// Runtime construction or asset loading failed and can be retried.
  failed,

  /// Runtime resources were retired after an explicit stop request.
  stopped,
}

/// Immutable host status suitable for editor presentation and shortcuts.
@immutable
final class RunnerPlaytestStatus {
  const RunnerPlaytestStatus({
    required this.phase,
    required this.runtimeGeneration,
    required this.loadProgress,
    this.failureCode,
    this.failureMessage,
  });

  /// Current lifecycle phase for the active generation.
  final RunnerPlaytestPhase phase;

  /// Monotonic host-local generation; restart always increments it.
  final int runtimeGeneration;

  /// Flame load progress in `[0, 1]` for the active runtime.
  final double loadProgress;

  /// Stable tooling-facing code when [phase] is
  /// [RunnerPlaytestPhase.failed].
  final String? failureCode;

  /// Human-readable failure detail; never use it for programmatic branching.
  final String? failureMessage;
}

/// External lifecycle handle for one mounted [RunnerPlaytestHost].
///
/// The host owns and disposes runtime resources. Callers own this controller,
/// must keep it unique to one mounted host, and dispose it after unmounting.
final class RunnerPlaytestController extends ChangeNotifier {
  RunnerPlaytestStatus _status = const RunnerPlaytestStatus(
    phase: RunnerPlaytestPhase.loading,
    runtimeGeneration: 0,
    loadProgress: 0,
  );
  _RunnerPlaytestDelegate? _delegate;
  bool _disposed = false;

  /// Latest lifecycle status published synchronously by the mounted host.
  RunnerPlaytestStatus get status => _status;

  /// Current deterministic snapshot, or `null` when no runtime is mounted.
  GameStateSnapshot? get snapshot => _delegate?.snapshot;

  /// Starts a ready generation and requests gameplay focus.
  ///
  /// Returns `false` unless the host is attached and currently ready.
  bool start() => _delegate?.start() ?? false;

  /// Pauses simulation and cancels all translated gameplay input.
  ///
  /// Returns `false` unless the active generation is running.
  bool pause() => _delegate?.pause() ?? false;

  /// Resumes a paused generation and requests gameplay focus.
  ///
  /// Returns `false` unless the active generation is paused.
  bool resume() => _delegate?.resume() ?? false;

  /// Switches only between running and paused lifecycle phases.
  bool togglePause() => _delegate?.togglePause() ?? false;

  /// Disposes the active runtime and rebuilds the scenario at exact tick zero.
  ///
  /// Returns `false` after an explicit [stop].
  bool restart() => _delegate?.restart() ?? false;

  /// Requests keyboard focus without enabling gameplay under an overlay.
  bool requestFocus() => _delegate?.requestFocus() ?? false;

  /// Releases keyboard focus; a running host transitions to paused.
  bool releaseFocus() => _delegate?.releaseFocus() ?? false;

  /// Permanently stops this mount and schedules its one-shot stop callback.
  bool stop() => _delegate?.stop() ?? false;

  void _attach(_RunnerPlaytestDelegate delegate, RunnerPlaytestStatus status) {
    if (_disposed) {
      throw StateError('Cannot attach a disposed playtest controller.');
    }
    if (_delegate != null && !identical(_delegate, delegate)) {
      throw StateError(
        'RunnerPlaytestController is already attached to another host.',
      );
    }
    _delegate = delegate;
    _status = status;
  }

  void _detach(_RunnerPlaytestDelegate delegate) {
    if (identical(_delegate, delegate)) _delegate = null;
  }

  void _publish(RunnerPlaytestStatus status) {
    if (_disposed) return;
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _delegate = null;
    super.dispose();
  }
}

/// Runs one validated authored-chunk scenario without app or backend state.
///
/// Every restart rebuilds the complete Core/controller/Flame/input graph from
/// [scenario]. [assetBundle] defaults to the normal Flutter bundle; the editor
/// should supply [RunnerWorkspaceAssetBundle]. [onStop] fires once after the
/// runtime has been removed and disposed.
class RunnerPlaytestHost extends StatefulWidget {
  const RunnerPlaytestHost({
    super.key,
    required this.scenario,
    required this.appearance,
    required this.controller,
    required this.onStop,
    this.assetBundle,
    this.imagesFactory,
  });

  /// Immutable, already-validated inputs used to construct every generation.
  final PlaytestScenario scenario;

  /// Captured render inputs; authored content never resolves generated fallbacks.
  final RunnerPlaytestAppearance appearance;

  /// Caller-owned lifecycle handle; it must not be shared by mounted hosts.
  final RunnerPlaytestController controller;

  /// Called once after an explicit stop has retired runtime resources.
  final VoidCallback onStop;

  /// Read-only image source; use [RunnerWorkspaceAssetBundle] in the editor.
  final AssetBundle? assetBundle;

  /// Optional image-cache factory for specialized tooling/tests.
  ///
  /// Production editor hosts normally supply only [assetBundle]. The factory
  /// must return a new cache for every invocation because restart transfers
  /// ownership of the previous cache to runtime disposal.
  final RunnerPlaytestImagesFactory? imagesFactory;

  @override
  State<RunnerPlaytestHost> createState() => _RunnerPlaytestHostState();
}

abstract interface class _RunnerPlaytestDelegate {
  GameStateSnapshot? get snapshot;
  bool start();
  bool pause();
  bool resume();
  bool togglePause();
  bool restart();
  bool requestFocus();
  bool releaseFocus();
  bool stop();
}

class _RunnerPlaytestHostState extends State<RunnerPlaytestHost>
    implements _RunnerPlaytestDelegate {
  final GlobalKey _surfaceKey = GlobalKey();
  final Set<_RunnerPlaytestRuntime> _retiredRuntimes =
      <_RunnerPlaytestRuntime>{};

  _RunnerPlaytestRuntime? _runtime;
  RunnerPlaytestPhase _phase = RunnerPlaytestPhase.loading;
  int _runtimeGeneration = 0;
  String? _failureCode;
  String? _failureMessage;
  bool _stopNotified = false;
  bool _stopCallbackPending = false;

  @override
  void initState() {
    super.initState();
    _installFreshRuntime(initial: true);
    widget.controller._attach(this, _status);
  }

  @override
  void didUpdateWidget(covariant RunnerPlaytestHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller._detach(this);
      widget.controller._attach(this, _status);
    }
    if (!identical(oldWidget.scenario, widget.scenario) ||
        !identical(oldWidget.assetBundle, widget.assetBundle) ||
        !identical(oldWidget.imagesFactory, widget.imagesFactory) ||
        !identical(oldWidget.appearance, widget.appearance)) {
      _installFreshRuntime();
    }
  }

  RunnerPlaytestStatus get _status {
    final progress = _runtime?.game.loadState.value.progress ?? 0.0;
    return RunnerPlaytestStatus(
      phase: _phase,
      runtimeGeneration: _runtimeGeneration,
      loadProgress: progress.clamp(0.0, 1.0),
      failureCode: _failureCode,
      failureMessage: _failureMessage,
    );
  }

  @override
  GameStateSnapshot? get snapshot => _runtime?.controller.snapshot;

  @override
  bool start() {
    final runtime = _runtime;
    if (_phase != RunnerPlaytestPhase.ready || runtime == null) {
      return false;
    }
    runtime.desktopInput.setEnabled(true);
    runtime.controller.setPaused(false);
    _setPhase(RunnerPlaytestPhase.running);
    _requestRuntimeFocus(runtime);
    return true;
  }

  @override
  bool pause() {
    final runtime = _runtime;
    if (_phase != RunnerPlaytestPhase.running || runtime == null) {
      return false;
    }
    runtime.desktopInput.setEnabled(false);
    runtime.controller.setPaused(true);
    _setPhase(RunnerPlaytestPhase.paused);
    return true;
  }

  @override
  bool resume() {
    final runtime = _runtime;
    if (_phase != RunnerPlaytestPhase.paused || runtime == null) {
      return false;
    }
    runtime.desktopInput.setEnabled(true);
    runtime.controller.setPaused(false);
    _setPhase(RunnerPlaytestPhase.running);
    _requestRuntimeFocus(runtime);
    return true;
  }

  @override
  bool togglePause() {
    return switch (_phase) {
      RunnerPlaytestPhase.running => pause(),
      RunnerPlaytestPhase.paused => resume(),
      RunnerPlaytestPhase.loading ||
      RunnerPlaytestPhase.ready ||
      RunnerPlaytestPhase.gameOver ||
      RunnerPlaytestPhase.failed ||
      RunnerPlaytestPhase.stopped => false,
    };
  }

  @override
  bool restart() {
    if (_phase == RunnerPlaytestPhase.stopped) return false;
    _installFreshRuntime();
    return true;
  }

  @override
  bool requestFocus() {
    final runtime = _runtime;
    if (runtime == null ||
        _phase == RunnerPlaytestPhase.loading ||
        _phase == RunnerPlaytestPhase.failed ||
        _phase == RunnerPlaytestPhase.stopped) {
      return false;
    }
    runtime.desktopInput.requestFocus();
    return true;
  }

  @override
  bool releaseFocus() {
    final runtime = _runtime;
    if (runtime == null) return false;
    runtime.desktopInput.releaseFocus();
    return true;
  }

  @override
  bool stop() {
    if (_phase == RunnerPlaytestPhase.stopped) return false;
    final oldRuntime = _runtime;
    oldRuntime?.prepareForRemoval();
    _runtime = null;
    _phase = RunnerPlaytestPhase.stopped;
    _failureCode = null;
    _failureMessage = null;
    _stopCallbackPending = true;
    if (mounted) setState(() {});
    widget.controller._publish(_status);

    if (oldRuntime == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _invokeStopOnce());
    } else {
      _retireRuntime(oldRuntime, afterDispose: _invokeStopOnce);
    }
    return true;
  }

  void _installFreshRuntime({bool initial = false}) {
    final oldRuntime = _runtime;
    oldRuntime?.prepareForRemoval();
    _runtimeGeneration += 1;
    _phase = RunnerPlaytestPhase.loading;
    _failureCode = null;
    _failureMessage = null;

    try {
      _runtime = _createRuntime(_runtimeGeneration);
    } on Object catch (error) {
      _runtime = null;
      _phase = RunnerPlaytestPhase.failed;
      _recordFailure(error, construction: true);
    }

    if (!initial && mounted) setState(() {});
    if (!initial) widget.controller._publish(_status);
    if (oldRuntime != null) _retireRuntime(oldRuntime);
  }

  _RunnerPlaytestRuntime _createRuntime(int generation) {
    final controller = GameController(
      core: switch (widget.scenario) {
        ChunkPlaytestScenario scenario => GameCore.chunkPlaytest(
          scenario: scenario,
        ),
        LevelPlaytestScenario scenario => GameCore.levelPlaytest(
          scenario: scenario,
        ),
        _ => throw ArgumentError('Unsupported playtest scenario type.'),
      },
      tickHz: widget.scenario.tickHz,
    )..setPaused(true);
    final input = RunnerInputRouter(controller: controller);
    final actions = RunnerSemanticActionDispatcher(
      input: input,
      resolveInputMode: (action) => _resolveInputMode(controller, action),
    );
    final projectilePreview = AimPreviewModel();
    final meleePreview = AimPreviewModel();
    final imageCache =
        widget.imagesFactory?.call(widget.assetBundle) ??
        Images(bundle: widget.assetBundle);
    final game = RunnerFlameGame(
      controller: controller,
      input: input,
      projectileAimPreview: projectilePreview,
      meleeAimPreview: meleePreview,
      playerCharacter: widget.scenario.playerCharacter,
      imageCache: imageCache,
      parallaxThemes: widget.appearance.parallaxThemes,
      terrainMaterials: widget.appearance.terrainMaterials,
    );
    final desktopInput = RunnerDesktopInputController(
      dispatcher: actions,
      resolveAimGeometry: () => _aimGeometryFor(generation),
      onFocusLost: () => _handleFocusLost(generation),
      onCancelPresentation: () {
        projectilePreview.end();
        meleePreview.end();
      },
      onAimChanged: (x, y) {
        if (_runtime?.generation == generation) {
          projectilePreview.updateAim(x, y);
        }
      },
      onAimCleared: () {
        if (_runtime?.generation == generation &&
            projectilePreview.value.active) {
          projectilePreview.clearAim();
        }
      },
    )..setEnabled(false);

    late final _RunnerPlaytestRuntime runtime;
    runtime = _RunnerPlaytestRuntime(
      generation: generation,
      controller: controller,
      game: game,
      desktopInput: desktopInput,
      projectilePreview: projectilePreview,
      meleePreview: meleePreview,
      imageCache: imageCache,
      onLoadStateChanged: () => _handleLoadState(runtime),
      onControllerChanged: () => _handleControllerState(runtime),
    );
    runtime.attachHostListeners();
    return runtime;
  }

  AbilityInputMode _resolveInputMode(
    GameController controller,
    RunnerGameplayAction action,
  ) {
    final hud = controller.snapshot.hud;
    return switch (action) {
      RunnerGameplayAction.primary => hud.meleeInputMode,
      RunnerGameplayAction.secondary => hud.secondaryInputMode,
      RunnerGameplayAction.projectile => hud.projectileInputMode,
      RunnerGameplayAction.mobility => hud.mobilityInputMode,
      RunnerGameplayAction.jump ||
      RunnerGameplayAction.spell ||
      RunnerGameplayAction.moveLeft ||
      RunnerGameplayAction.moveRight => AbilityInputMode.tap,
    };
  }

  RunnerDesktopAimGeometry? _aimGeometryFor(int generation) {
    final runtime = _runtime;
    final surfaceContext = _surfaceKey.currentContext;
    if (runtime == null ||
        runtime.generation != generation ||
        surfaceContext == null) {
      return null;
    }
    final renderBox = surfaceContext.findRenderObject();
    if (renderBox is! RenderBox ||
        !renderBox.hasSize ||
        renderBox.size.isEmpty) {
      return null;
    }
    final player = runtime.controller.snapshot.playerEntity;
    if (player == null) return null;
    final metrics = computeViewportMetrics(
      BoxConstraints.tight(renderBox.size),
      MediaQuery.devicePixelRatioOf(context),
      virtualWidth,
      virtualHeight,
      ViewportScaleMode.pixelPerfectContain,
    );
    return RunnerDesktopAimGeometry.fromWorld(
      metrics: metrics,
      camera: runtime.controller.snapshot.camera,
      playerWorldPosition: Offset(player.pos.x, player.pos.y),
    );
  }

  void _handleLoadState(_RunnerPlaytestRuntime runtime) {
    if (!identical(_runtime, runtime) ||
        _phase != RunnerPlaytestPhase.loading) {
      return;
    }
    if (runtime.game.loadState.value.phase == RunLoadPhase.worldReady) {
      _phase = RunnerPlaytestPhase.ready;
      runtime.desktopInput.setEnabled(false);
      if (mounted) setState(() {});
      widget.controller._publish(_status);
      _requestRuntimeFocus(runtime);
      return;
    }
    if (mounted) setState(() {});
    widget.controller._publish(_status);
  }

  void _handleControllerState(_RunnerPlaytestRuntime runtime) {
    if (!identical(_runtime, runtime) ||
        !runtime.controller.snapshot.gameOver ||
        _phase == RunnerPlaytestPhase.gameOver ||
        _phase == RunnerPlaytestPhase.stopped) {
      return;
    }
    runtime.desktopInput.setEnabled(false);
    _setPhase(RunnerPlaytestPhase.gameOver);
  }

  void _handleFocusLost(int generation) {
    final runtime = _runtime;
    if (runtime == null ||
        runtime.generation != generation ||
        _phase != RunnerPlaytestPhase.running) {
      return;
    }
    runtime.controller.setPaused(true);
    runtime.desktopInput.setEnabled(false);
    _setPhase(RunnerPlaytestPhase.paused);
  }

  void _handleLoadFailure(int generation, Object error) {
    final runtime = _runtime;
    if (runtime == null || runtime.generation != generation) return;
    runtime.desktopInput.setEnabled(false);
    runtime.controller.setPaused(true);
    _recordFailure(error, construction: false);
    _setPhase(RunnerPlaytestPhase.failed, preserveFailure: true);
  }

  void _recordFailure(Object error, {required bool construction}) {
    if (error case final RunnerWorkspaceAssetException workspaceError) {
      _failureCode = workspaceError.code;
      _failureMessage = workspaceError.message;
      return;
    }
    _failureCode = construction
        ? 'runner_playtest_runtime_construction_failed'
        : 'runner_playtest_asset_load_failed';
    _failureMessage = error.toString();
  }

  void _setPhase(RunnerPlaytestPhase phase, {bool preserveFailure = false}) {
    _phase = phase;
    if (!preserveFailure) {
      _failureCode = null;
      _failureMessage = null;
    }
    if (mounted) setState(() {});
    widget.controller._publish(_status);
  }

  void _requestRuntimeFocus(_RunnerPlaytestRuntime runtime) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(_runtime, runtime)) {
        runtime.desktopInput.requestFocus();
      }
    });
  }

  void _retireRuntime(
    _RunnerPlaytestRuntime runtime, {
    VoidCallback? afterDispose,
  }) {
    runtime.detachHostListeners();
    _retiredRuntimes.add(runtime);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_retiredRuntimes.remove(runtime)) return;
      runtime.dispose();
      afterDispose?.call();
    });
  }

  void _invokeStopOnce() {
    if (_stopNotified || !_stopCallbackPending) return;
    _stopCallbackPending = false;
    _stopNotified = true;
    widget.onStop();
  }

  @override
  Widget build(BuildContext context) {
    final runtime = _runtime;
    return ColoredBox(
      color: const Color(0xFF05070A),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (runtime != null)
            SizedBox.expand(
              key: _surfaceKey,
              child: RunnerDesktopInputAdapter(
                controller: runtime.desktopInput,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final metrics = computeViewportMetrics(
                      constraints,
                      MediaQuery.devicePixelRatioOf(context),
                      virtualWidth,
                      virtualHeight,
                      ViewportScaleMode.pixelPerfectContain,
                    );
                    return GameViewport(
                      metrics: metrics,
                      child: GameWidget<RunnerFlameGame>(
                        key: ValueKey<RunnerFlameGame>(runtime.game),
                        game: runtime.game,
                        autofocus: false,
                        loadingBuilder: (_) => const SizedBox.expand(),
                        errorBuilder: (_, error) =>
                            _RunnerPlaytestLoadFailureReporter(
                              generation: runtime.generation,
                              error: error,
                              onError: _handleLoadFailure,
                            ),
                      ),
                    );
                  },
                ),
              ),
            ),
          const _RunnerPlaytestIdentityBanner(),
          _buildLifecycleOverlay(),
        ],
      ),
    );
  }

  Widget _buildLifecycleOverlay() {
    switch (_phase) {
      case RunnerPlaytestPhase.loading:
        final progress = _runtime?.game.loadState.value.progress ?? 0.0;
        return _RunnerPlaytestPanel(
          title: 'Preparing playtest',
          detail: '${(progress * 100).round()}%',
          actions: <Widget>[
            OutlinedButton(onPressed: stop, child: const Text('Stop')),
          ],
        );
      case RunnerPlaytestPhase.ready:
        return _RunnerPlaytestPanel(
          title: 'Ready',
          detail: 'Click Start or press Enter from the editor host.',
          actions: <Widget>[
            FilledButton(onPressed: start, child: const Text('Start')),
            OutlinedButton(onPressed: stop, child: const Text('Stop')),
          ],
        );
      case RunnerPlaytestPhase.running:
        return _RunnerPlaytestToolbar(
          onPause: pause,
          onRestart: restart,
          onStop: stop,
        );
      case RunnerPlaytestPhase.paused:
        return _RunnerPlaytestPanel(
          title: 'Paused',
          detail: 'Input is neutral. Resume explicitly to continue.',
          actions: <Widget>[
            FilledButton(onPressed: resume, child: const Text('Resume')),
            OutlinedButton(onPressed: restart, child: const Text('Restart')),
            OutlinedButton(onPressed: stop, child: const Text('Stop')),
          ],
        );
      case RunnerPlaytestPhase.gameOver:
        return _RunnerPlaytestPanel(
          title: 'Playtest ended',
          detail: 'No rewards, replay, or score were recorded.',
          actions: <Widget>[
            FilledButton(onPressed: restart, child: const Text('Restart')),
            OutlinedButton(onPressed: stop, child: const Text('Stop')),
          ],
        );
      case RunnerPlaytestPhase.failed:
        return _RunnerPlaytestPanel(
          title: 'Playtest failed',
          detail: <String>[?_failureCode, ?_failureMessage].join('\n'),
          actions: <Widget>[
            FilledButton(onPressed: restart, child: const Text('Retry')),
            OutlinedButton(onPressed: stop, child: const Text('Stop')),
          ],
        );
      case RunnerPlaytestPhase.stopped:
        return const _RunnerPlaytestPanel(
          title: 'Stopped',
          detail: 'Returning to the editor.',
          actions: <Widget>[],
        );
    }
  }

  @override
  void dispose() {
    widget.controller._detach(this);
    final runtime = _runtime;
    _runtime = null;
    runtime?.prepareForRemoval();
    runtime?.detachHostListeners();
    runtime?.dispose();
    for (final retired in _retiredRuntimes) {
      retired.dispose();
    }
    _retiredRuntimes.clear();
    _invokeStopOnce();
    super.dispose();
  }
}

final class _RunnerPlaytestRuntime {
  _RunnerPlaytestRuntime({
    required this.generation,
    required this.controller,
    required this.game,
    required this.desktopInput,
    required this.projectilePreview,
    required this.meleePreview,
    required this.imageCache,
    required this.onLoadStateChanged,
    required this.onControllerChanged,
  });

  final int generation;
  final GameController controller;
  final RunnerFlameGame game;
  final RunnerDesktopInputController desktopInput;
  final AimPreviewModel projectilePreview;
  final AimPreviewModel meleePreview;
  final Images imageCache;
  final VoidCallback onLoadStateChanged;
  final VoidCallback onControllerChanged;
  bool _listenersAttached = false;
  bool _disposed = false;

  void attachHostListeners() {
    if (_listenersAttached) return;
    _listenersAttached = true;
    game.loadState.addListener(onLoadStateChanged);
    controller.addListener(onControllerChanged);
  }

  void detachHostListeners() {
    if (!_listenersAttached) return;
    _listenersAttached = false;
    game.loadState.removeListener(onLoadStateChanged);
    controller.removeListener(onControllerChanged);
  }

  void prepareForRemoval() {
    if (_disposed) return;
    desktopInput.setEnabled(false);
    controller.setPaused(true);
    detachHostListeners();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    detachHostListeners();
    desktopInput.dispose();
    controller.shutdown();
    controller.dispose();
    projectilePreview.dispose();
    meleePreview.dispose();
    imageCache.clearCache();
  }
}

class _RunnerPlaytestLoadFailureReporter extends StatefulWidget {
  const _RunnerPlaytestLoadFailureReporter({
    required this.generation,
    required this.error,
    required this.onError,
  });

  final int generation;
  final Object error;
  final void Function(int generation, Object error) onError;

  @override
  State<_RunnerPlaytestLoadFailureReporter> createState() =>
      _RunnerPlaytestLoadFailureReporterState();
}

class _RunnerPlaytestLoadFailureReporterState
    extends State<_RunnerPlaytestLoadFailureReporter> {
  @override
  void initState() {
    super.initState();
    _report();
  }

  @override
  void didUpdateWidget(covariant _RunnerPlaytestLoadFailureReporter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.generation != widget.generation ||
        !identical(oldWidget.error, widget.error)) {
      _report();
    }
  }

  void _report() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onError(widget.generation, widget.error);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

class _RunnerPlaytestIdentityBanner extends StatelessWidget {
  const _RunnerPlaytestIdentityBanner();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SafeArea(
        minimum: const EdgeInsets.all(12),
        child: Align(
          alignment: Alignment.topLeft,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xDD11151C),
              border: Border.all(color: const Color(0xFFDBA740)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Text(
                'PLAYTEST - NO REWARDS/REPLAY\n'
                'A/D move  Space jump  Shift mobility\n'
                'Mouse/J primary  RMB/K projectile  Q secondary  E/L spell',
                style: TextStyle(
                  color: Color(0xFFFFE4A3),
                  fontSize: 11,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RunnerPlaytestToolbar extends StatelessWidget {
  const _RunnerPlaytestToolbar({
    required this.onPause,
    required this.onRestart,
    required this.onStop,
  });

  final VoidCallback onPause;
  final VoidCallback onRestart;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.all(12),
      child: Align(
        alignment: Alignment.topRight,
        child: Material(
          color: const Color(0xDD11151C),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextButton(onPressed: onPause, child: const Text('Pause')),
                TextButton(onPressed: onRestart, child: const Text('Restart')),
                TextButton(onPressed: onStop, child: const Text('Stop')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RunnerPlaytestPanel extends StatelessWidget {
  const _RunnerPlaytestPanel({
    required this.title,
    required this.detail,
    required this.actions,
  });

  final String title;
  final String detail;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xB805070A),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xF21A202A),
              border: Border.all(color: const Color(0xFF596574)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    detail,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFCBD2DC)),
                  ),
                  if (actions.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 20),
                    Wrap(spacing: 10, runSpacing: 10, children: actions),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
