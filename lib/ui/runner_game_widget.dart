import 'package:runner_core/campaign/campaign_registry.dart';

import '../game/input/runner_gameplay_action.dart';
import 'campaign/campaign_catalog.dart';

import 'package:runner_content_pipeline/campaign_tutorial.dart';
import 'package:run_protocol/campaign_binding.dart';
import 'package:rpg_runner/ui/l10n/app_localization.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:run_protocol/board_key.dart';

import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/players/player_character_definition.dart';

import '../game/game_controller.dart';
import '../game/input/aim_preview.dart';
import '../game/input/runner_semantic_action_dispatcher.dart';
import '../game/runner_flame_game.dart';
import 'app/ui_routes.dart';
import 'app/app_runtime_policy.dart';
import 'bootstrap/loader_content.dart';
import 'components/loader_shell.dart';
import 'controls/movement_control_mode.dart';
import 'input/runner_control_scheme.dart';
import 'input/runner_gameplay_bindings.dart';
import 'input/desktop/runner_desktop_input_adapter.dart';
import 'input/desktop/runner_desktop_aim_geometry.dart';
import 'scoped/scoped_game_context_menu.dart';
import 'hud/game/game_overlay.dart';
import 'hud/gameover/game_over_overlay.dart';
import 'haptics/haptics_service.dart';
import 'runner_game_ui_state.dart';
import 'run/runner_run_session.dart';
import 'run/run_start_preparation.dart';
import 'run/run_release_gate.dart';
import 'state/app/app_state.dart';
import 'state/run/run_start_remote_exception.dart';
import 'state/ownership/selection_state.dart';
import 'state/boards/ghost_replay_cache.dart';
import 'state/run/run_submission_status.dart';
import 'runner_gameplay_surface.dart';
import 'viewport/viewport_metrics.dart';

/// Embed-friendly widget that hosts the mini-game.
///
/// Intended to be mounted by a host app. It owns its [GameController] and
/// cleans it up on dispose through a run-owned session.
/// The loading presentation waits for render assets, upcoming terrain, selected
/// ghost preparation, and replay-recorder initialization. HUD, controls, and
/// Start appear only after all required preparation succeeds. Required failures
/// offer retry at tick zero with the same ticket, plus the host's exit callback.
/// The complete initial terrain window is ready before Start. Native startup
/// builds independent terrain candidates concurrently; browser work cooperates
/// with rendering. A bounded native worker computes ghost ticks ahead; only
/// presentation follows the live tick.
/// Developer Practice on web or native debug skips recording and submission,
/// preserving the normal simulation, loading, controls and score breakdown.
/// Campaign uses the ticket's mission/content binding and a finite resident world.
/// It requires RunMode.campaign, forbids boards/ghosts, and replaces survival HUD
/// with objective/exit progress. First-clear XP/unlocks require canonical settlement;
/// retry/next issue new tickets. Developer campaign attempts remain local.
/// An authored movement introduction replaces Start after readiness. Movement
/// begins play with the same held gesture; lifecycle/exit gates still apply.
/// Campaign initial HUD and lesson reveals gate actions across input devices.
/// Objectives and first-coin lessons pause after a short practice walk and pickup,
/// respectively, and resume on fresh movement;
/// a chunk-entry obstacle sequence advances two informational pages with Next,
/// then reveals resources and resumes on a fresh Jump, dispatching that real press;
/// host lifecycle/exit guards retain priority. Progress resets with the attempt.
///
/// During play, missing terrain holds the next tick asynchronously and keeps
/// controls mounted. Runtime failure offers same-run retry and exit; it never
/// restarts the ticket or recorder. Waits do not accrue catch-up time.
///
/// Leaving the resumed lifecycle pauses play and clears held inputs. Touch
/// resumes lifecycle-paused play on return; desktop requires explicit resume.
/// Automatic controls use keyboard/mouse on desktop platforms and their browsers,
/// and touch elsewhere. Desktop Enter starts/resumes; Escape/P toggles pause.
/// Desktop mouse aiming, including browsers, has no aim-ray preview; touch
/// previews remain available.
/// Host UI clicks do not fire abilities. Browser context menus are suppressed
/// while desktop controls are mounted, then restored to their prior setting.
/// Reward completion belongs to AppState and continues after this widget closes;
/// embedding hosts must forward app foreground state to AppState.
/// Run gold/XP display immediately; AppState projects journaled rewards into
/// wallet/XP presentation while keeping spending and level gifts server-owned.
/// A restart rejected for maintenance or an obsolete client shows a release
/// dialog while retaining the current session and its submission recovery.
/// Boss entrances hold controls within the active Core run; the replay clock
/// continues, and defeating the boss restores ordinary route progression.
///
/// Viewport scaling is applied by [RunnerGameplaySurface] to keep the fixed virtual
/// resolution fitted to the available screen. During play, left/top off-screen
/// actor markers use that same fitted/cropped view and ignore pointer input.
/// Localization follows the inherited locale. Hosts register
/// RunnerLocalizations.delegates/supportedLocales on their MaterialApp; absent
/// or unsupported locale configuration falls back to English. Keep this widget's
/// identity when changing locale so the current run session remains mounted.
/// Runtime, input/feedback and viewport wiring are shared with Training and Play.
/// Product policy stays in the run session. Pending replay finalization retains
/// its original attempt identity after this widget is replaced or removed.
/// Editor display calibration never changes this widget's inherited environment.
class RunnerGameWidget extends StatefulWidget {
  const RunnerGameWidget({
    super.key,
    required this.runSessionId,
    required this.runId,
    required this.seed,
    this.tickHz = 60,
    required this.levelId,
    this.playerCharacterId = PlayerCharacterId.eloise,
    this.runMode = RunMode.practice,
    this.equippedLoadout = const EquippedLoadoutDef(),
    this.campaign,
    this.boardId,
    this.boardKey,
    this.ghostReplayBootstrap,
    this.isDeveloperPractice = false,
    this.movementControlMode = MovementControlMode.arrows,
    this.controlScheme = RunnerControlScheme.automatic,
    this.onExit,
    this.showExitButton = true,
    this.viewportMode = ViewportScaleMode.pixelPerfectContain,
    this.viewportAlignment = Alignment.center,
    this.sessionFactory,
  });

  /// Master RNG seed for deterministic generation.
  final int seed;

  /// Fixed simulation tick rate from the ticket or local developer configuration.
  final int tickHz;

  /// Unique identifier for this run session (replay/ghost).
  final String runSessionId;

  /// Legacy integer run identifier consumed by current in-run systems.
  final int runId;

  /// Registered runner level or the campaign mission's regional identity.
  final LevelId levelId;

  /// Which player character to use for this run.
  final PlayerCharacterId playerCharacterId;

  /// Ticket-selected mode; campaign uses its separate mission binding.
  final RunMode runMode;

  /// Per-run loadout override (from menu / meta inventory).
  final EquippedLoadoutDef equippedLoadout;

  /// Exact server-issued mission/content binding, required only for campaign.
  final CampaignBinding? campaign;

  /// Server-issued board identity for competitive/weekly runs.
  final String? boardId;

  /// Server-issued board key for competitive/weekly runs.
  final BoardKey? boardKey;

  /// Optional verified ghost replay payload to race against.
  final GhostReplayBootstrap? ghostReplayBootstrap;

  /// Local Practice/campaign on web or native debug; no recording or account rewards.
  final bool isDeveloperPractice;

  /// Arrows, floating joystick, or fixed joystick, retained on restart. All emit
  /// only -1, 0 or 1; hosts can select without app settings services.
  final MovementControlMode movementControlMode;

  /// Automatic platform selection, or an explicit touch/keyboard-mouse surface.
  /// Desktop focus loss pauses until explicit resume. Changing schemes clears
  /// held inputs and pauses an active run. Movement preferences apply to touch.
  final RunnerControlScheme controlScheme;

  final VoidCallback? onExit;
  final bool showExitButton;

  /// How the game view is scaled to the available screen.
  final ViewportScaleMode viewportMode;

  /// Where the scaled view is placed within the available screen.
  final Alignment viewportAlignment;

  /// Overrides local dependencies in startup lifecycle tests.
  @visibleForTesting
  final RunnerRunSession Function(RunStartDescriptor)? sessionFactory;

  @override
  State<RunnerGameWidget> createState() => _RunnerGameWidgetState();
}

class _RunnerGameWidgetState extends State<RunnerGameWidget>
    with WidgetsBindingObserver {
  final UiHaptics _haptics = const UiHapticsService();
  bool _pausedByLifecycle = false;
  RunnerControlScheme _controlScheme = RunnerControlScheme.touch;
  RunnerDesktopInputController? get _desktopInput => _bindings.desktop;
  final _surfaceKey = GlobalKey<RunnerGameplaySurfaceState>();
  bool get _usesDesktop => _controlScheme == RunnerControlScheme.desktop;
  bool _started = false;
  bool _exitConfirmOpen = false;
  bool _pausedBeforeExitConfirm = false;
  bool _restartInFlight = false;
  RunStartPreparation? _restartPreparation;

  late RunStartDescriptor _descriptor;
  String get _runSessionId => _descriptor.runSessionId;
  LevelId get _levelId => _descriptor.levelId;
  RunMode get _runMode => _descriptor.runMode;
  RunSubmissionStatus? _runSubmissionStatus;
  AppState? _submissionAppState;

  late RunnerRunSession _session;
  GameController get _controller => _session.controller;
  late RunnerGameplayBindings _bindings;
  RunnerSemanticActionDispatcher get _actions => _bindings.actions;
  AimPreviewModel get _projectileAimPreview => _session.projectileAimPreview;
  AimPreviewModel get _meleeAimPreview => _session.meleeAimPreview;
  RunnerFlameGame get _game => _session.game;
  bool _loadingRetryInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _validateInitialRunInputs();
    _descriptor = RunStartDescriptor(
      runSessionId: widget.runSessionId,
      runId: widget.runId,
      seed: widget.seed,
      tickHz: widget.tickHz,
      levelId: widget.levelId,
      playerCharacterId: widget.playerCharacterId,
      runMode: widget.runMode,
      equippedLoadout: widget.equippedLoadout,
      boardId: widget.boardId,
      boardKey: widget.boardKey,
      campaign: widget.campaign,
      ghostReplayBootstrap: widget.ghostReplayBootstrap,
      isDeveloperPractice: widget.isDeveloperPractice,
    );
    _initGame();

    // Start in "ready" (paused) until the user taps to begin.
    _controller.setPaused(true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _configureControls();
    final appState = _maybeAppState();
    if (identical(appState, _submissionAppState)) return;
    _submissionAppState?.removeListener(_onSubmissionChanged);
    _submissionAppState = appState;
    appState?.addListener(_onSubmissionChanged);
    appState?.setRunSubmissionForeground(
      WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
    );
  }

  @override
  void didUpdateWidget(covariant RunnerGameWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _configureControls();
  }

  void _configureControls() {
    final scheme = widget.controlScheme.resolve(defaultTargetPlatform);
    if (_controlScheme == scheme) return;
    _clearInputs();
    _bindings.detachDesktop();
    _controlScheme = scheme;
    _pausedByLifecycle = false;
    if (_started) _controller.setPaused(true);
    if (_usesDesktop) _createDesktopInput();
  }

  CampaignMission? get _campaignMission {
    final id = _descriptor.campaign?.missionId;
    return id == null ? null : CampaignCatalog.mission(id);
  }

  bool _startFromTutorialAction(RunnerGameplayAction action) {
    if (!_bindings.tutorial.showing ||
        !_session.isReady ||
        !_isForeground ||
        _exitConfirmOpen ||
        _restartInFlight ||
        _controller.terrainReadiness != TerrainReadiness.ready) {
      return false;
    }
    if (!_bindings.tutorial.acceptAction(action)) return false;
    if (!_started) {
      _startGame(fromMovement: true);
    } else {
      _controller.setPaused(false);
      _syncDesktopInput();
      _requestDesktopFocus(preserveStartInput: true);
    }
    return _started && !_controller.snapshot.paused;
  }

  void _createDesktopInput() {
    _bindings.attachDesktop(
      resolveAimGeometry: _desktopAimGeometry,
      onFocusLost: _pauseDesktop,
      onActionStart: _startFromTutorialAction,
    );
    _requestDesktopFocus();
  }

  void _requestDesktopFocus({bool preserveStartInput = false}) {
    final input = _desktopInput;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(input, _desktopInput) && _isForeground) {
        input?.requestFocus(preserveStartInput: preserveStartInput);
      }
    });
  }

  bool get _isForeground {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  void _syncDesktopInput() {
    _desktopInput?.setEnabled(
      _session.isReady &&
          _started &&
          !_controller.snapshot.paused &&
          !_controller.snapshot.gameOver &&
          !_exitConfirmOpen &&
          !_restartInFlight &&
          _isForeground &&
          _controller.terrainReadiness != TerrainReadiness.failed,
    );
  }

  void _pauseDesktop() {
    if (!_usesDesktop) return;
    _pausedByLifecycle = false;
    if (_started) _bindings.tutorial.suspend();
    _clearInputs();
    _controller.setPaused(true);
    _syncDesktopInput();
  }

  RunnerDesktopAimGeometry? _desktopAimGeometry() {
    return _surfaceKey.currentState?.aimGeometry;
  }

  KeyEventResult _desktopShortcut(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    final enter =
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter;
    final pause =
        key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.keyP;
    if (!enter && !pause) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.handled;
    if (!_session.isReady ||
        !_isForeground ||
        _controller.snapshot.gameOver ||
        _restartInFlight) {
      return KeyEventResult.handled;
    }
    if (_exitConfirmOpen) {
      if (key == LogicalKeyboardKey.escape) _closeExitConfirm(resume: true);
    } else if (!_started) {
      if (enter) _startGame();
    } else if (pause || (enter && _controller.snapshot.paused)) {
      _togglePause();
    }
    return KeyEventResult.handled;
  }

  void _onSubmissionChanged() {
    if (!mounted) return;
    final status = _submissionAppState?.runSubmissionStatusFor(_runSessionId);
    if (status == null) return;
    setState(() => _runSubmissionStatus = status);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _onLifecycle(state);

  void _onLifecycle(AppLifecycleState state) {
    _submissionAppState?.setRunSubmissionForeground(
      state == AppLifecycleState.resumed,
    );
    if (_usesDesktop) {
      if (state != AppLifecycleState.resumed) _pauseDesktop();
      _syncDesktopInput();
      return;
    }
    final runLoaded = _session.isReady;
    final uiState = _buildUiState(runLoaded: runLoaded);
    if (state == AppLifecycleState.resumed) {
      final resumeRun = _pausedByLifecycle && uiState.canRun;
      _pausedByLifecycle = false;
      if (resumeRun) {
        _bindings.tutorial.resumeGuidance();
        _controller.setPaused(_bindings.tutorial.active != null);
      }
      return;
    }

    // Later background transitions see an already paused run; retain ownership
    // until resume instead of replacing it with that paused snapshot.
    _pausedByLifecycle =
        _pausedByLifecycle ||
        uiState.isRunning ||
        (_started && _bindings.tutorial.showing);
    if (_started) _bindings.tutorial.suspend();
    _controller.setPaused(true);
    _clearInputs();
  }

  void _clearInputs() => _bindings.cancelAll();

  AppState? _maybeAppState() {
    try {
      return Provider.of<AppState>(context, listen: false);
    } on ProviderNotFoundException {
      return null;
    }
  }

  int _displayedGoldForGameOver() {
    final appState = _maybeAppState();
    final value = appState?.displayedGold ?? 0;
    return value < 0 ? 0 : value;
  }

  void _validateInitialRunInputs() {
    if (widget.isDeveloperPractice &&
        (!developerPracticeAllowed ||
            (widget.runMode != RunMode.practice &&
                widget.runMode != RunMode.campaign) ||
            widget.boardId != null ||
            widget.boardKey != null ||
            widget.ghostReplayBootstrap != null)) {
      throw StateError(
        'Developer runs require web or native debug and unranked local play.',
      );
    }
    if (widget.runSessionId.trim().isEmpty) {
      throw StateError('RunnerGameWidget requires non-empty runSessionId.');
    }
    if (widget.tickHz <= 0) {
      throw StateError('RunnerGameWidget requires a positive tickHz.');
    }
    if (widget.runId <= 0) {
      throw StateError('RunnerGameWidget requires runId > 0.');
    }
    if (widget.seed <= 0) {
      throw StateError('RunnerGameWidget requires seed > 0.');
    }
    if (widget.runMode.requiresBoard) {
      if (widget.boardId == null || widget.boardKey == null) {
        throw StateError(
          'RunnerGameWidget requires boardId and boardKey for '
          '${widget.runMode.name} runs.',
        );
      }
    }
    if ((widget.runMode == RunMode.campaign) != (widget.campaign != null)) {
      throw StateError('Campaign mode requires an exact mission binding.');
    }
    if (!widget.runMode.requiresBoard &&
        (widget.boardId != null || widget.boardKey != null)) {
      throw StateError('Unranked runs cannot carry board bindings.');
    }
    final ghostBootstrap = widget.ghostReplayBootstrap;
    if (ghostBootstrap != null) {
      if (!widget.runMode.requiresBoard || widget.boardId == null) {
        throw StateError(
          'RunnerGameWidget ghost replay requires a board-bound run.',
        );
      }
      if (ghostBootstrap.manifest.boardId != widget.boardId) {
        throw StateError(
          'RunnerGameWidget ghost replay boardId must match run boardId.',
        );
      }
    }
  }

  void _handleGameEvent(GameEvent event) {
    if (event is! RunEndedEvent) return;
    unawaited(
      _session.finalization.complete(
        event,
        recorder: _session.recorder,
        journal: _maybeAppState()?.journalRunReplay,
      ),
    );
  }

  RunnerGameUiState _buildUiState({required bool runLoaded}) {
    final snapshot = _controller.snapshot;
    return RunnerGameUiState(
      started: _started,
      paused: snapshot.paused,
      gameOver: snapshot.gameOver,
      runLoaded: runLoaded,
    );
  }

  void _startGame({bool fromMovement = false}) {
    if (_started ||
        !_session.isReady ||
        (!fromMovement && !_bindings.tutorial.startNormally())) {
      return;
    }
    setState(() => _started = true);
    if (!fromMovement) _clearInputs();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _pausedByLifecycle =
        lifecycle != null && lifecycle != AppLifecycleState.resumed;
    _controller.setPaused(_pausedByLifecycle);
    _syncDesktopInput();
    _requestDesktopFocus(preserveStartInput: fromMovement);
  }

  void _onRestartPressed() {
    if (_restartInFlight) return;
    unawaited(_restartGame());
  }

  Future<void> _restartGame({String? campaignMissionId}) async {
    if (_restartInFlight) return;
    final appState = _maybeAppState();
    if (appState == null) {
      _showRestartFailure(
        const RunStartRemoteException(
          code: 'unimplemented',
          message: 'Run restart is unavailable in this environment.',
        ),
      );
      return;
    }
    setState(() => _restartInFlight = true);
    _controller.setPaused(true);
    _clearInputs();
    final preparation = RunStartPreparation(
      appState: appState,
      request: RunStartBootstrapArgs(
        campaignMissionId: campaignMissionId ?? _descriptor.campaign?.missionId,
        expectedMode: _runMode,
        expectedLevelId: _levelId,
      ),
    );
    _restartPreparation = preparation;
    final attempt = _session;
    try {
      final descriptor = await preparation.prepare();
      if (!mounted ||
          !identical(_session, attempt) ||
          !identical(_restartPreparation, preparation)) {
        return;
      }
      if (descriptor != null) {
        _restartWithDescriptor(descriptor);
      } else if (preparation.error case final error?) {
        _showRestartFailure(error);
      }
    } catch (error) {
      if (!mounted ||
          !identical(_session, attempt) ||
          !identical(_restartPreparation, preparation)) {
        return;
      }
      _showRestartFailure(error);
    } finally {
      if (identical(_restartPreparation, preparation)) {
        _restartPreparation = null;
        preparation.dispose();
        if (mounted) setState(() => _restartInFlight = false);
      }
    }
  }

  void _showRestartFailure(Object error) {
    if (error is RunStartRemoteException &&
        (error.isUpdateRequired || error.isReleaseMaintenance)) {
      unawaited(
        showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            content: SingleChildScrollView(
              child: RunReleaseGate(
                error: error,
                onRetry: () {
                  Navigator.of(dialogContext).pop();
                  _onRestartPressed();
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(dialogContext.l10n.uiClose),
              ),
            ],
          ),
        ),
      );
      return;
    }
    final message = RunStartPreparation.messageFor(error, context.l10n);
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  void _restartWithDescriptor(RunStartDescriptor descriptor) {
    final oldBindings = _bindings..stop();
    final oldSession = _session;
    oldSession.removeListener(_syncDesktopInput);
    oldSession.controller.removeEventListener(_handleGameEvent);
    oldSession.controller.removeListener(_syncDesktopInput);
    unawaited(
      oldSession.stop().catchError((Object error) {
        debugPrint('Run cleanup failed: $error');
      }),
    );

    setState(() {
      _pausedByLifecycle = false;
      _started = false;
      _exitConfirmOpen = false;
      _descriptor = descriptor;
      _runSubmissionStatus = null;
      _initGame();
    });
    _controller.setPaused(true);
    _clearInputs();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      oldSession.dispose();
      oldBindings.dispose();
    });
  }

  void _openExitConfirm() {
    final wasPaused = _controller.snapshot.paused;
    if (!wasPaused) _clearInputs();
    _controller.setPaused(true);

    setState(() {
      _pausedBeforeExitConfirm = wasPaused;
      _exitConfirmOpen = true;
    });
    _syncDesktopInput();
  }

  void _closeExitConfirm({required bool resume}) {
    if (!_exitConfirmOpen) {
      if (resume) _togglePause();
      return;
    }
    setState(() => _exitConfirmOpen = false);
    if (resume && _isForeground) {
      _controller.setPaused(_pausedBeforeExitConfirm);
      _requestDesktopFocus();
    }
    _syncDesktopInput();
  }

  void _confirmExitGiveUp() {
    setState(() => _exitConfirmOpen = false);
    _controller.giveUp();
  }

  void _togglePause() {
    if (!_session.isReady || !_started || !_isForeground || _exitConfirmOpen) {
      return;
    }
    if (_bindings.tutorial.active != null) {
      if (_bindings.tutorial.suspended) {
        _bindings.tutorial.resumeGuidance();
        _requestDesktopFocus();
      } else {
        _clearInputs();
        _bindings.tutorial.suspend();
      }
      _controller.setPaused(true);
      _syncDesktopInput();
      return;
    }
    final paused = _controller.snapshot.paused;
    if (!paused) _clearInputs();
    _controller.setPaused(!paused);
    _syncDesktopInput();
    if (paused) _requestDesktopFocus();
  }

  void _initGame() {
    _session =
        widget.sessionFactory?.call(_descriptor) ??
        RunnerRunSession(descriptor: _descriptor);
    _controller.addEventListener(_handleGameEvent);
    _bindings = RunnerGameplayBindings(
      controller: _controller,
      input: _session.input,
      projectilePreview: _projectileAimPreview,
      meleePreview: _meleeAimPreview,
      haptics: _haptics,
      campaignMission: campaignMissions[_descriptor.campaign?.missionId],
      tutorialSequences: _campaignMission?.tutorialSequences ?? const [],
      initialTutorialHud:
          _campaignMission?.initialTutorialHud ?? allTutorialHud,
    );
    _controller.addListener(_syncDesktopInput);
    _session.addListener(_syncDesktopInput);
    if (_usesDesktop) _createDesktopInput();
  }

  Future<void> _retryLoading() async {
    if (_started || _loadingRetryInFlight) return;
    setState(() => _loadingRetryInFlight = true);
    final attempt = _session;
    try {
      // A retry has not consumed any ticks. Reuse its ticket only after the old
      // recorder closes, so two attempts never write the same replay files.
      await attempt.stop();
      if (!mounted || !identical(attempt, _session)) return;
      _restartWithDescriptor(_descriptor);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(context.l10n.runCleanupFailed)));
      }
    } finally {
      if (mounted) setState(() => _loadingRetryInFlight = false);
    }
  }

  void _disposeGame() {
    _bindings.stop();
    _controller.removeEventListener(_handleGameEvent);
    _controller.removeListener(_syncDesktopInput);
    _session.removeListener(_syncDesktopInput);
    _session.dispose();
    _bindings.dispose();
  }

  @override
  void dispose() {
    _submissionAppState?.removeListener(_onSubmissionChanged);
    WidgetsBinding.instance.removeObserver(this);
    _restartPreparation?.dispose();
    _restartPreparation = null;
    _disposeGame();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final surface = RunnerGameplaySurface(
      key: _surfaceKey,
      runtime: session.runtime,
      bindings: _bindings,
      viewportMode: widget.viewportMode,
      alignment: widget.viewportAlignment,
      onLoadError: session.reportHostLoadFailure,
      overlayBuilder: (context, metrics) => AnimatedBuilder(
        animation: _session,
        builder: (context, _) {
          final runLoaded = _session.isReady;
          return AnimatedBuilder(
            animation: Listenable.merge([_controller, _bindings]),
            builder: (context, _) {
              final uiState = _buildUiState(runLoaded: runLoaded);
              if (uiState.showLoadingOverlay) {
                return _RunLoadingView(
                  message: _session.loadingMessage(context.l10n),
                  errorMessage: _session.errorMessage(context.l10n),
                  onRetry: _loadingRetryInFlight ? null : _retryLoading,
                  onExit: widget.showExitButton ? widget.onExit : null,
                );
              }
              if (uiState.gameOver) {
                final runEndedEvent = _controller.lastRunEndedEvent;
                final runEndKey =
                    runEndedEvent?.tick ?? _controller.snapshot.tick;
                return GameOverOverlay(
                  key: ValueKey(
                    'gameOver-$_runSessionId-$runEndKey-${runEndedEvent?.reason}',
                  ),
                  visible: true,
                  onRestart: _onRestartPressed,
                  restartInProgress: _restartInFlight,
                  onExit: widget.onExit,
                  showExitButton: widget.showExitButton,
                  levelId: _controller.snapshot.levelIdentity
                      .requireRegisteredId(),
                  runMode: _runMode,
                  campaignMissionId: _descriptor.campaign?.missionId,
                  onNextCampaignMission: _restartInFlight
                      ? null
                      : (id) => _restartGame(campaignMissionId: id),
                  isDeveloperPractice: _descriptor.isDeveloperPractice,
                  runEndedEvent: runEndedEvent,
                  scoreTuning: _controller.scoreTuning,
                  tickHz: _controller.tickHz,
                  provisionalGoldEarned: _session.finalization.goldEarned,
                  displayedGold: _displayedGoldForGameOver(),
                  rewardRevision: _maybeAppState()?.rewardDisplayRevision,
                  runSubmissionStatus:
                      _runSubmissionStatus ?? _session.finalization.status,
                  replaySubmissionJournaled: _session.finalization.journaled,
                  replaySubmissionJournalError: _session.finalization.error,
                  onRetryReplayJournal: _session.finalization.inFlight
                      ? null
                      : () => unawaited(
                          _session.finalization.retry(
                            recorder: _session.recorder,
                            journal: _maybeAppState()?.journalRunReplay,
                          ),
                        ),
                );
              }
              final overlay = GameOverlay(
                tutorial: _bindings.tutorial,
                onTutorialAction: _startFromTutorialAction,
                controlScheme: _controlScheme,
                indicatorFrames: _game.offscreenIndicators,
                viewportMetrics: metrics,
                movementInputEpoch: _bindings.movementEpoch,
                movementControlMode: widget.movementControlMode,
                controller: _controller,
                input: _actions,
                projectileAimPreview: _projectileAimPreview,
                meleeAimPreview: _meleeAimPreview,
                aimCancelHitboxRect: _bindings.aimCancelHitboxRect,
                forceAimCancelSignal: _bindings.forceAimCancelSignal,
                playerImpactFeedbackSignal: _bindings.impactSignal,
                uiState: uiState,
                onStart: _startGame,
                onTogglePause: _togglePause,
                showExitButton: widget.showExitButton,
                onExit: uiState.started && !uiState.gameOver
                    ? _openExitConfirm
                    : widget.onExit,
                exitConfirmOpen: _exitConfirmOpen,
                onExitConfirmResume: () => _closeExitConfirm(resume: true),
                onExitConfirmExit: _confirmExitGiveUp,
              );
              return ExcludeFocus(
                excluding: _usesDesktop && uiState.isRunning,
                child: overlay,
              );
            },
          );
        },
      ),
    );
    return ScopedGameContextMenu(
      enabled: _usesDesktop,
      child: Focus(
        canRequestFocus: false,
        onKeyEvent: _usesDesktop ? _desktopShortcut : null,
        child: surface,
      ),
    );
  }
}

class _RunLoadingView extends StatelessWidget {
  const _RunLoadingView({
    required this.message,
    this.errorMessage,
    this.onRetry,
    this.onExit,
  });

  final String message;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final VoidCallback? onExit;

  @override
  Widget build(BuildContext context) => LoaderShell(
    scrollable: errorMessage != null,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LoaderContent(
          loadingMessage: message,
          errorTitle: context.l10n.runStartErrorTitle,
          errorMessage: errorMessage,
          onContinue: onRetry,
        ),
        if (onExit != null)
          TextButton(onPressed: onExit, child: Text(context.l10n.uiExit)),
      ],
    ),
  );
}
