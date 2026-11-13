import '../ui/tutorial/campaign_tutorial_practice_hint.dart';
import '../ui/tutorial/campaign_tutorial_geometry.dart';
import '../game/input/runner_gameplay_action.dart';

import 'package:flame/cache.dart';
import 'package:flutter/material.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/playtest/chunk_playtest_scenario.dart';
import 'package:runner_core/playtest/level_playtest_scenario.dart';
import 'package:runner_core/playtest/playtest_scenario.dart';
import 'package:runner_core/playtest/campaign_playtest_scenario.dart';

import 'runner_playtest_appearance.dart';

import 'package:runner_core/snapshots/game_state_snapshot.dart';

import '../game/game_controller.dart';
import '../game/input/aim_preview.dart';
import '../game/runner_flame_game.dart';
import '../game/runner_gameplay_runtime.dart';
import '../ui/input/desktop/runner_desktop_aim_geometry.dart';
import '../ui/input/desktop/runner_desktop_input_adapter.dart';
import '../ui/input/runner_gameplay_bindings.dart';
import '../ui/tutorial/campaign_tutorial_overlay.dart';

import 'package:runner_content_pipeline/campaign_tutorial.dart';

import '../ui/runner_gameplay_surface.dart';
import '../ui/viewport/viewport_metrics.dart';
import '../ui/hud/game/game_overlay.dart';
import '../ui/runner_game_ui_state.dart';
import '../ui/theme/ui_theme.dart';
import 'runner_playtest_presentation.dart';
import 'runner_playtest_display_frame.dart';
import 'runner_workspace_asset_bundle.dart';

part 'runner_playtest_session.dart';

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
  bool _presentationBlocked = false;

  /// Tooling can suspend a live attempt while its display calibration resolves.
  /// Clearing the block permits an explicit Start/Resume; it never resumes.
  void setPresentationBlocked(bool blocked) {
    if (_presentationBlocked == blocked) return;
    _presentationBlocked = blocked;
    _delegate?.setPresentationBlocked(blocked);
  }

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
    delegate.setPresentationBlocked(_presentationBlocked);
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

/// Runs one validated authored scenario without app or backend state.
///
/// Every restart rebuilds the complete Core/controller/Flame/input graph from
/// [scenario]. [assetBundle] defaults to the normal Flutter bundle; the editor
/// should supply [RunnerCapturedAssetBundle]. [onStop] fires once after the
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
    this.presentation = const RunnerPlaytestPresentation(),
    this.showIdentityBanner = true,
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

  /// Pre-launch presentation choices; the runtime exposes no settings controls.
  /// Restart retains them and keyboard input remains available with either HUD.
  final RunnerPlaytestPresentation presentation;
  final bool showIdentityBanner;

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
  void setPresentationBlocked(bool blocked);
}

class _RunnerPlaytestHostState extends State<RunnerPlaytestHost>
    implements _RunnerPlaytestDelegate {
  final _surfaceKey = GlobalKey<RunnerGameplaySurfaceState>();
  final _absentMovementTarget = GlobalKey();
  late final _RunnerPlaytestSession _session;
  _RunnerPlaytestRuntime? get _runtime => _session._runtime;
  RunnerPlaytestPhase get _phase => _session._phase;
  String? get _failureCode => _session._failureCode;
  String? get _failureMessage => _session._failureMessage;
  RunnerPlaytestStatus get _status => _session._status;

  final ThemeData _hudTheme = createUiTheme();

  bool get _hudVisible => widget.presentation.showMobileHud;
  bool get _isCampaign => widget.scenario is CampaignPlaytestScenario;

  @override
  void initState() {
    super.initState();
    _session = _RunnerPlaytestSession(
      scenario: widget.scenario,
      appearance: widget.appearance,
      assetBundle: widget.assetBundle,
      imagesFactory: widget.imagesFactory,
      resolveAimGeometry: _aimGeometryFor,
      onStop: widget.onStop,
    )..addListener(_onSessionChanged);
    widget.controller._attach(this, _status);
  }

  @override
  void didUpdateWidget(covariant RunnerPlaytestHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _session.onStop = widget.onStop;
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller._detach(this);
      widget.controller._attach(this, _status);
    }
    if (!identical(oldWidget.scenario, widget.scenario) ||
        !identical(oldWidget.assetBundle, widget.assetBundle) ||
        !identical(oldWidget.imagesFactory, widget.imagesFactory) ||
        !identical(oldWidget.appearance, widget.appearance)) {
      _session
        ..scenario = widget.scenario
        ..appearance = widget.appearance
        ..assetBundle = widget.assetBundle
        ..imagesFactory = widget.imagesFactory
        .._installFreshRuntime();
    } else if (oldWidget.presentation != widget.presentation) {
      _runtime?.desktopInput.cancelAll();
    }
  }

  RunnerDesktopAimGeometry? _aimGeometryFor(int generation) {
    if (_runtime?.generation != generation) return null;
    return _surfaceKey.currentState?.aimGeometry;
  }

  @override
  Widget build(BuildContext context) {
    final runtime = _runtime;
    final preview = RunnerPlaytestDisplayFrame(
      display: widget.presentation.display,
      child: ColoredBox(
        color: const Color(0xFF05070A),
        child: runtime == null
            ? _buildLifecycleOverlay()
            : RunnerGameplaySurface(
                key: _surfaceKey,
                runtime: runtime.graph,
                bindings: runtime.bindings,
                viewportMode: widget.presentation.viewportMode,
                onLoadError: (error) =>
                    _session._handleLoadFailure(runtime.generation, error),
                overlayBuilder: (context, metrics) => Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_hudVisible &&
                        (_phase == RunnerPlaytestPhase.ready ||
                            _phase == RunnerPlaytestPhase.running ||
                            _phase == RunnerPlaytestPhase.paused))
                      _buildMobileHud(runtime, metrics),
                    if (!_hudVisible &&
                        (_phase == RunnerPlaytestPhase.ready ||
                            _phase == RunnerPlaytestPhase.running))
                      AnimatedBuilder(
                        animation: runtime.bindings,
                        builder: (context, _) {
                          final tutorial = runtime.bindings.tutorial;
                          if (!tutorial.showing) {
                            return CampaignTutorialPracticeHint(
                              text: tutorial.combatPracticeHint,
                            );
                          }
                          return CampaignTutorialOverlay(
                            tutorial: tutorial.active!,
                            step: tutorial.step,
                            onNext: tutorial.hasNextStep
                                ? tutorial.nextStep
                                : null,
                            control: TutorialMovementControl.keyboard,
                            targetKey: _absentMovementTarget,
                            surfaceKey: _surfaceKey,
                            worldTarget: tutorial.worldTargetBounds != null
                                ? () {
                                    final bounds = tutorial.worldTargetBounds;
                                    return bounds == null
                                        ? null
                                        : campaignTutorialWorldTarget(
                                            bounds,
                                            runtime.controller.snapshot.camera,
                                            metrics,
                                          );
                                  }
                                : null,
                          );
                        },
                      ),
                    _buildLifecycleOverlay(),
                  ],
                ),
              ),
      ),
    );
    if (_isCampaign || !widget.showIdentityBanner) return preview;
    return Column(
      children: [
        const Text('PLAYTEST - NO REWARDS/REPLAY'),
        Expanded(child: preview),
      ],
    );
  }

  Widget _buildMobileHud(
    _RunnerPlaytestRuntime runtime,
    ViewportMetrics metrics,
  ) => Theme(
    data: _hudTheme,
    child: DefaultTextStyle(
      style: _hudTheme.textTheme.bodyMedium!,
      child: ExcludeFocus(
        child: AnimatedBuilder(
          animation: Listenable.merge([runtime.controller, runtime.bindings]),
          builder: (context, _) => GameOverlay(
            key: ValueKey(runtime.generation),
            tutorial: runtime.bindings.tutorial,
            onTutorialAction: (action) =>
                _session.start(tutorialAction: action),
            controller: runtime.controller,
            input: runtime.bindings.actions,
            projectileAimPreview: runtime.projectilePreview,
            meleeAimPreview: runtime.meleePreview,
            aimCancelHitboxRect: runtime.bindings.aimCancelHitboxRect,
            forceAimCancelSignal: runtime.bindings.forceAimCancelSignal,
            playerImpactFeedbackSignal: runtime.bindings.impactSignal,
            movementInputEpoch: runtime.bindings.movementEpoch,
            movementControlMode: widget.presentation.movementControlMode,
            indicatorFrames: runtime.game.offscreenIndicators,
            viewportMetrics: metrics,
            uiState: RunnerGameUiState(
              started: _phase != RunnerPlaytestPhase.ready,
              paused: runtime.controller.snapshot.paused,
              gameOver: false,
              runLoaded: true,
            ),
            showLifecycleOverlays: false,
            onStart: start,
            onTogglePause: togglePause,
            showExitButton: true,
            onExit: stop,
            exitConfirmOpen: false,
            onExitConfirmResume: resume,
            onExitConfirmExit: stop,
          ),
        ),
      ),
    ),
  );

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
        if (_session._showingTutorial) {
          return _hudVisible
              ? const SizedBox.shrink()
              : Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: TextButton(
                      onPressed: stop,
                      child: const Text('Stop'),
                    ),
                  ),
                );
        }
        return _RunnerPlaytestPanel(
          title: 'Ready',
          detail: _isCampaign
              ? 'Local playtest — no rewards or replay. Click Start or press Enter.'
              : 'Click Start or press Enter.',
          actions: <Widget>[
            FilledButton(onPressed: start, child: const Text('Start')),
            OutlinedButton(onPressed: stop, child: const Text('Stop')),
          ],
        );
      case RunnerPlaytestPhase.running:
        if (_hudVisible) return const SizedBox.shrink();
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

  void _onSessionChanged() {
    if (!mounted) return;
    setState(() {});
    widget.controller._publish(_status);
  }

  @override
  GameStateSnapshot? get snapshot => _session.snapshot;
  @override
  bool start() => _session.start();
  @override
  bool pause() => _session.pause();
  @override
  bool resume() => _session.resume();
  @override
  bool togglePause() => _session.togglePause();
  @override
  bool restart() => _session.restart();
  @override
  bool requestFocus() => _session.requestFocus();
  @override
  bool releaseFocus() => _session.releaseFocus();
  @override
  bool stop() => _session.stop();
  @override
  void setPresentationBlocked(bool blocked) =>
      _session.setPresentationBlocked(blocked);

  @override
  void dispose() {
    widget.controller._detach(this);
    _session.removeListener(_onSessionChanged);
    _session.dispose();
    super.dispose();
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
