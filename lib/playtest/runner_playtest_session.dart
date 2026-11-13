part of 'runner_playtest_host.dart';

/// Backend-free attempt lifecycle. The host renders this state; retirement waits
/// for GameWidget to detach, while input and preparation stop synchronously.
final class _RunnerPlaytestSession extends ChangeNotifier {
  _RunnerPlaytestSession({
    required this.scenario,
    required this.appearance,
    required this.assetBundle,
    required this.imagesFactory,
    required this.resolveAimGeometry,
    required this.onStop,
  }) {
    _installFreshRuntime(initial: true);
  }

  PlaytestScenario scenario;
  RunnerPlaytestAppearance appearance;
  AssetBundle? assetBundle;
  RunnerPlaytestImagesFactory? imagesFactory;
  final RunnerDesktopAimGeometry? Function(int generation) resolveAimGeometry;
  VoidCallback onStop;
  final Set<_RunnerPlaytestRuntime> _retiredRuntimes = {};
  _RunnerPlaytestRuntime? _runtime;
  RunnerPlaytestPhase _phase = RunnerPlaytestPhase.loading;
  int _runtimeGeneration = 0;
  String? _failureCode;
  String? _failureMessage;
  bool _stopNotified = false;
  bool _stopCallbackPending = false;
  bool _disposed = false;
  bool _presentationBlocked = false;

  void setPresentationBlocked(bool blocked) {
    _presentationBlocked = blocked;
    if (blocked) {
      pause();
      _runtime?.bindings.cancelAll();
      _runtime?.desktopInput.setEnabled(false);
    }
  }

  void _publish() {
    if (!_disposed) notifyListeners();
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

  GameStateSnapshot? get snapshot => _runtime?.controller.snapshot;

  bool get _showingTutorial => _runtime?.bindings.tutorial.showing == true;

  bool start({RunnerGameplayAction? tutorialAction}) {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final runtime = _runtime;
    if (_presentationBlocked ||
        runtime == null ||
        (lifecycle != null && lifecycle != AppLifecycleState.resumed) ||
        runtime.controller.terrainReadiness != TerrainReadiness.ready) {
      return false;
    }
    final tutorial = runtime.bindings.tutorial;
    if (tutorialAction != null) {
      if ((_phase != RunnerPlaytestPhase.ready &&
              _phase != RunnerPlaytestPhase.running) ||
          !tutorial.acceptAction(tutorialAction)) {
        return false;
      }
    } else if (_phase != RunnerPlaytestPhase.ready ||
        !tutorial.startNormally()) {
      return false;
    }
    _phase = RunnerPlaytestPhase.running;
    runtime.desktopInput.setEnabled(true);
    runtime.controller.setPaused(false);
    _setPhase(RunnerPlaytestPhase.running);
    _requestRuntimeFocus(runtime, preserveStartInput: tutorialAction != null);
    return true;
  }

  bool pause() {
    final runtime = _runtime;
    if (_phase != RunnerPlaytestPhase.running || runtime == null) {
      return false;
    }
    runtime.bindings.tutorial.suspend();
    runtime.desktopInput.setEnabled(false);
    runtime.controller.setPaused(true);
    _setPhase(RunnerPlaytestPhase.paused);
    return true;
  }

  bool resume() {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (_presentationBlocked ||
        (lifecycle != null && lifecycle != AppLifecycleState.resumed)) {
      return false;
    }
    final runtime = _runtime;
    if (_phase != RunnerPlaytestPhase.paused || runtime == null) {
      return false;
    }
    runtime.bindings.tutorial.resumeGuidance();
    final heldForLesson = runtime.bindings.tutorial.active != null;
    _phase = RunnerPlaytestPhase.running;
    runtime.desktopInput.setEnabled(!heldForLesson);
    runtime.controller.setPaused(heldForLesson);
    _setPhase(RunnerPlaytestPhase.running);
    _requestRuntimeFocus(runtime);
    return true;
  }

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

  bool restart() {
    if (_phase == RunnerPlaytestPhase.stopped) return false;
    _installFreshRuntime();
    return true;
  }

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

  bool releaseFocus() {
    final runtime = _runtime;
    if (runtime == null) return false;
    runtime.desktopInput.releaseFocus();
    return true;
  }

  bool stop() {
    if (_phase == RunnerPlaytestPhase.stopped) return false;
    final oldRuntime = _runtime;
    oldRuntime?.prepareForRemoval();
    _runtime = null;
    _phase = RunnerPlaytestPhase.stopped;
    _failureCode = null;
    _failureMessage = null;
    _stopCallbackPending = true;

    _publish();

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

    if (!initial) _publish();
    if (oldRuntime != null) _retireRuntime(oldRuntime);
  }

  _RunnerPlaytestRuntime _createRuntime(int generation) {
    final graph = RunnerGameplayRuntime(
      core: switch (scenario) {
        CampaignPlaytestScenario scenario => GameCore.campaignPlaytest(
          mission: scenario.mission,
          playerCharacter: scenario.playerCharacter,
          equippedLoadout: scenario.equippedLoadout,
          seed: scenario.seed,
          tickHz: scenario.tickHz,
        ),
        ChunkPlaytestScenario scenario => GameCore.chunkPlaytest(
          scenario: scenario,
        ),
        LevelPlaytestScenario scenario => GameCore.levelPlaytest(
          scenario: scenario,
        ),
        _ => throw ArgumentError('Unsupported playtest scenario type.'),
      },
      createImages: () =>
          imagesFactory?.call(assetBundle) ?? Images(bundle: assetBundle),
      parallaxThemes: appearance.parallaxThemes,
      terrainMaterials: appearance.terrainMaterials,
    );
    final bindings = RunnerGameplayBindings(
      controller: graph.controller,
      input: graph.input,
      projectilePreview: graph.projectilePreview,
      meleePreview: graph.meleePreview,
      campaignMission: scenario is CampaignPlaytestScenario
          ? (scenario as CampaignPlaytestScenario).mission
          : null,
      tutorialSequences: appearance.tutorialSequences,
      initialTutorialHud: appearance.initialTutorialHud,
    );
    try {
      bindings.attachDesktop(
        resolveAimGeometry: () => resolveAimGeometry(generation),
        onFocusLost: () => _handleFocusLost(generation),
        onActionStart: (action) =>
            _runtime?.generation == generation &&
            _showingTutorial &&
            start(tutorialAction: action),
      );

      late final _RunnerPlaytestRuntime runtime;
      runtime = _RunnerPlaytestRuntime(
        generation: generation,
        graph: graph,
        bindings: bindings,
        onLoadStateChanged: () => _handleLoadState(runtime),
        onControllerChanged: () => _handleControllerState(runtime),
      );
      runtime.attachHostListeners();
      return runtime;
    } catch (_) {
      bindings.dispose();
      graph.dispose();
      rethrow;
    }
  }

  void _handleLoadState(_RunnerPlaytestRuntime runtime) {
    if (!identical(_runtime, runtime) ||
        _phase != RunnerPlaytestPhase.loading) {
      return;
    }
    if (runtime.game.loadState.value.phase == RunLoadPhase.worldReady) {
      _phase = RunnerPlaytestPhase.ready;
      runtime.desktopInput.setEnabled(false);

      _publish();
      _requestRuntimeFocus(runtime);
      return;
    }

    _publish();
  }

  void _handleControllerState(_RunnerPlaytestRuntime runtime) {
    if (!identical(_runtime, runtime)) return;
    runtime.desktopInput.setEnabled(
      !_presentationBlocked &&
          _phase == RunnerPlaytestPhase.running &&
          !runtime.controller.snapshot.paused &&
          !runtime.controller.snapshot.gameOver &&
          !runtime.bindings.tutorial.showing &&
          runtime.controller.terrainReadiness != TerrainReadiness.failed,
    );
    final showing = runtime.bindings.tutorial.showing;
    if (runtime.lastGuidanceShowing != showing) {
      runtime.lastGuidanceShowing = showing;
      _publish();
    }
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
    pause();
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

    _publish();
  }

  void _requestRuntimeFocus(
    _RunnerPlaytestRuntime runtime, {
    bool preserveStartInput = false,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed && identical(_runtime, runtime)) {
        runtime.desktopInput.requestFocus(
          preserveStartInput: preserveStartInput,
        );
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
    onStop();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final runtime = _runtime;
    _runtime = null;
    runtime?.prepareForRemoval();
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
    required this.graph,
    required this.bindings,
    required this.onLoadStateChanged,
    required this.onControllerChanged,
  });

  final int generation;
  final RunnerGameplayRuntime graph;
  GameController get controller => graph.controller;
  RunnerFlameGame get game => graph.game;
  final RunnerGameplayBindings bindings;
  RunnerDesktopInputController get desktopInput => bindings.desktop!;
  AimPreviewModel get projectilePreview => graph.projectilePreview;
  AimPreviewModel get meleePreview => graph.meleePreview;
  final VoidCallback onLoadStateChanged;
  final VoidCallback onControllerChanged;
  bool lastGuidanceShowing = false;
  bool _listenersAttached = false;
  bool _disposed = false;

  void attachHostListeners() {
    if (_listenersAttached) return;
    _listenersAttached = true;
    game.loadState.addListener(onLoadStateChanged);
    controller.addListener(onControllerChanged);
    bindings.addListener(onControllerChanged);
  }

  void detachHostListeners() {
    if (!_listenersAttached) return;
    _listenersAttached = false;
    game.loadState.removeListener(onLoadStateChanged);
    controller.removeListener(onControllerChanged);
    bindings.removeListener(onControllerChanged);
  }

  void prepareForRemoval() {
    if (_disposed) return;
    detachHostListeners();
    bindings.stop();
    graph.stop();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    detachHostListeners();
    bindings.dispose();
    graph.dispose();
  }
}
