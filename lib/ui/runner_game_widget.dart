import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:run_protocol/board_key.dart';

import 'package:runner_core/contracts/render_contract.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/snapshots/enums.dart';

import '../game/game_controller.dart';
import '../game/input/aim_preview.dart';
import '../game/input/runner_gameplay_action.dart';
import '../game/input/runner_semantic_action_dispatcher.dart';
import '../game/replay/run_recorder.dart';
import '../game/runner_flame_game.dart';
import 'app/ui_routes.dart';
import 'bootstrap/loader_content.dart';
import 'components/loader_shell.dart';
import 'hud/game/game_overlay.dart';
import 'hud/gameover/game_over_overlay.dart';
import 'haptics/haptics_cue.dart';
import 'haptics/haptics_service.dart';
import 'runner_game_ui_state.dart';
import 'run/runner_run_session.dart';
import 'run/run_start_preparation.dart';
import 'state/app/app_state.dart';
import 'state/run/run_start_remote_exception.dart';
import 'state/ownership/selection_state.dart';
import 'state/boards/ghost_replay_cache.dart';
import 'state/run/run_submission_status.dart';
import 'viewport/game_viewport.dart';
import 'viewport/viewport_metrics.dart';

/// Embed-friendly widget that hosts the mini-game.
///
/// Intended to be mounted by a host app. It owns its [GameController] and
/// cleans it up on dispose through a run-owned session.
/// The loading presentation waits for render assets, upcoming terrain, selected
/// ghost preparation, and replay-recorder initialization. HUD, controls, and
/// Start appear only after all required preparation succeeds. Required failures
/// offer retry at tick zero with the same ticket, plus the host's exit callback.
/// Start never waits on pending ghost asset or terrain work. A bounded native
/// worker computes ghost ticks ahead; only presentation follows the live tick.
///
/// Viewport scaling is applied by [GameViewport] to keep the fixed virtual
/// resolution fitted to the available screen.
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
    this.boardId,
    this.boardKey,
    this.ghostReplayBootstrap,
    this.onExit,
    this.showExitButton = true,
    this.viewportMode = ViewportScaleMode.pixelPerfectContain,
    this.viewportAlignment = Alignment.center,
    this.sessionFactory,
  });

  /// Master RNG seed for deterministic generation.
  final int seed;

  /// Fixed simulation tick rate from the server-issued run ticket.
  final int tickHz;

  /// Unique identifier for this run session (replay/ghost).
  final String runSessionId;

  /// Legacy integer run identifier consumed by current in-run systems.
  final int runId;

  /// Which core level definition to run.
  final LevelId levelId;

  /// Which player character to use for this run.
  final PlayerCharacterId playerCharacterId;

  /// Menu-selected run mode (practice/competitive/weekly). Used by UI (e.g. leaderboard
  /// namespacing) and may later affect rules/tuning.
  final RunMode runMode;

  /// Per-run loadout override (from menu / meta inventory).
  final EquippedLoadoutDef equippedLoadout;

  /// Server-issued board identity for competitive/weekly runs.
  final String? boardId;

  /// Server-issued board key for competitive/weekly runs.
  final BoardKey? boardKey;

  /// Optional verified ghost replay payload to race against.
  final GhostReplayBootstrap? ghostReplayBootstrap;

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
  // One-second checks cover the normal immediate settlement path; after ten
  // seconds, five-second polling avoids a long-lived mobile/network hot loop.
  static const Duration _initialSubmissionPollInterval = Duration(seconds: 1);
  static const Duration _initialSubmissionPollWindow = Duration(seconds: 10);
  static const Duration _steadySubmissionPollInterval = Duration(seconds: 5);

  final UiHaptics _haptics = const UiHapticsService();
  bool _pausedByLifecycle = false;
  bool _started = false;
  bool _exitConfirmOpen = false;
  bool _pausedBeforeExitConfirm = false;
  bool _restartInFlight = false;
  RunStartPreparation? _restartPreparation;

  late RunStartDescriptor _descriptor;
  String get _runSessionId => _descriptor.runSessionId;
  LevelId get _levelId => _descriptor.levelId;
  RunMode get _runMode => _descriptor.runMode;
  int? _provisionalGoldEarned;
  RunSubmissionStatus? _runSubmissionStatus;
  Timer? _runSubmissionPollTimer;
  bool _runSubmissionPollInFlight = false;
  DateTime? _runSubmissionPollingStartedAt;
  bool _runSubmissionPollingFast = false;
  String? _runSubmissionRunSessionId;
  bool _runReplayJournaled = false;
  bool _runReplayJournalInFlight = false;
  String? _runReplayJournalError;

  late RunnerRunSession _session;
  GameController get _controller => _session.controller;
  late RunnerSemanticActionDispatcher _actions;
  AimPreviewModel get _projectileAimPreview => _session.projectileAimPreview;
  AimPreviewModel get _meleeAimPreview => _session.meleeAimPreview;
  late ValueNotifier<Rect?> _aimCancelHitboxRect;
  late ValueNotifier<int> _forceAimCancelSignal;
  late ValueNotifier<int> _playerImpactFeedbackSignal;
  int _lastPlayerDamageTick = -1;
  int _lastChargeTier = 0;
  RunnerFlameGame get _game => _session.game;
  RunRecorder? get _runRecorder => _session.recorder;
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
      ghostReplayBootstrap: widget.ghostReplayBootstrap,
    );
    _initGame();

    // Start in "ready" (paused) until the user taps to begin.
    _controller.setPaused(true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _onLifecycle(state);

  void _onLifecycle(AppLifecycleState state) {
    final runLoaded = _session.isReady;
    final uiState = _buildUiState(runLoaded: runLoaded);
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
    _actions.cancelAll();
    _projectileAimPreview.end();
    _meleeAimPreview.end();
  }

  void _cancelHeldChargedAim() {
    _actions.clearAimDir();
    _projectileAimPreview.end();
    _meleeAimPreview.end();
    _forceAimCancelSignal.value = _forceAimCancelSignal.value + 1;
    _actions.pumpHeldInputs();
  }

  void _onControllerTick() {
    _emitChargeHaptics();

    final damageTick = _controller.snapshot.hud.lastDamageTick;
    if (damageTick <= _lastPlayerDamageTick) return;
    _lastPlayerDamageTick = damageTick;
    final hud = _controller.snapshot.hud;
    if (hud.chargeEnabled && hud.chargeActive) {
      _cancelHeldChargedAim();
    }
  }

  void _emitChargeHaptics() {
    final hud = _controller.snapshot.hud;
    final active = hud.chargeEnabled && hud.chargeActive;
    final nextTier = active ? hud.chargeTier : 0;

    if (active && nextTier > _lastChargeTier) {
      if (_lastChargeTier < 1 && nextTier >= 1) {
        _haptics.trigger(UiHapticsCue.chargeHalfTierReached);
      }
      if (_lastChargeTier < 2 && nextTier >= 2) {
        _haptics.trigger(UiHapticsCue.chargeFullTierReached);
      }
    }

    _lastChargeTier = nextTier;
  }

  UiHapticsIntensity _impactHapticsIntensity(int amount100) {
    if (amount100 >= 1400) return UiHapticsIntensity.heavy;
    if (amount100 >= 700) return UiHapticsIntensity.medium;
    return UiHapticsIntensity.light;
  }

  AppState? _maybeAppState() {
    try {
      return Provider.of<AppState>(context, listen: false);
    } on ProviderNotFoundException {
      return null;
    }
  }

  int _verifiedGoldForGameOver() {
    final appState = _maybeAppState();
    final value = appState?.progression.gold ?? 0;
    return value < 0 ? 0 : value;
  }

  void _validateInitialRunInputs() {
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
    if (event is PlayerImpactFeedbackEvent) {
      _haptics.trigger(
        UiHapticsCue.playerHit,
        intensityOverride: _impactHapticsIntensity(event.amount100),
      );
      _playerImpactFeedbackSignal.value = _playerImpactFeedbackSignal.value + 1;
      return;
    }
    if (event is AbilityHoldEndedEvent) {
      switch (event.reason) {
        case AbilityHoldEndReason.timeout:
          _haptics.trigger(UiHapticsCue.holdAbilityTimedOut);
        case AbilityHoldEndReason.staminaDepleted:
          _haptics.trigger(UiHapticsCue.holdAbilityStaminaDepleted);
      }
      return;
    }
    if (event is AbilityChargeEndedEvent) {
      switch (event.reason) {
        case AbilityChargeEndReason.timeout:
          _haptics.trigger(UiHapticsCue.holdAbilityTimedOut);
      }
      _cancelHeldChargedAim();
      return;
    }
    if (event is! RunEndedEvent) return;
    _captureProvisionalGold(event);
    _enqueueReplaySubmission(event);
  }

  void _captureProvisionalGold(RunEndedEvent event) {
    _provisionalGoldEarned = event.goldEarned;
  }

  void _enqueueReplaySubmission(RunEndedEvent event) {
    if (_runSubmissionRunSessionId == _runSessionId) {
      return;
    }
    _runSubmissionRunSessionId = _runSessionId;
    setState(() {
      _runReplayJournaled = false;
      _runReplayJournalInFlight = true;
      _runReplayJournalError = null;
    });
    unawaited(_journalReplayForSubmission(event));
  }

  Future<void> _journalReplayForSubmission(RunEndedEvent event) async {
    final appState = _maybeAppState();

    final recorder = _runRecorder;
    if (appState == null || recorder == null) {
      if (!mounted) return;
      setState(() {
        _runReplayJournalInFlight = false;
        _runReplayJournalError = 'Replay saving prerequisites were unavailable. Retry before leaving.';
        _runSubmissionStatus = RunSubmissionStatus(
          runSessionId: _runSessionId,
          phase: RunSubmissionPhase.internalError,
          updatedAtMs: DateTime.now().millisecondsSinceEpoch,
          message: 'Replay submission prerequisites were unavailable.',
        );
      });
      return;
    }

    try {
      final summary = _buildReplayProvisionalSummary(event);
      final finalized = await recorder.finalize(clientSummary: summary);
      final replaySize = await finalized.replayBlobFile.length();
      final journaledStatus = await appState.journalRunReplay(
        runSessionId: _runSessionId,
        runMode: _runMode,
        replayFilePath: finalized.replayBlobFile.path,
        canonicalSha256: finalized.replayBlob.canonicalSha256,
        contentLengthBytes: replaySize,
        provisionalSummary: summary,
      );
      if (!mounted) return;
      setState(() {
        _runReplayJournaled = true;
        _runReplayJournalInFlight = false;
        _runReplayJournalError = null;
        _runSubmissionStatus = journaledStatus;
      });
      unawaited(
        _processJournaledReplayForValidation(
          appState: appState,
          runSessionId: _runSessionId,
        ),
      );
    } catch (error) {
      debugPrint(
        'Replay journaling failed for runSessionId=$_runSessionId: $error',
      );
      if (!mounted) return;
      setState(() {
        _runReplayJournalInFlight = false;
        _runReplayJournalError = '$error';
        _runSubmissionStatus = RunSubmissionStatus(
          runSessionId: _runSessionId,
          phase: RunSubmissionPhase.internalError,
          updatedAtMs: DateTime.now().millisecondsSinceEpoch,
          message: 'Replay could not be saved. Retry before leaving.',
        );
      });
    }
  }

  Future<void> _processJournaledReplayForValidation({
    required AppState appState,
    required String runSessionId,
  }) async {
    try {
      final status = await appState.processJournaledRunReplay(
        runSessionId: runSessionId,
      );
      if (!mounted || runSessionId != _runSessionId) return;
      setState(() => _runSubmissionStatus = status);
      _scheduleSubmissionStatusPolling(
        appState: appState,
        runSessionId: runSessionId,
        initialStatus: status,
      );
    } catch (error) {
      debugPrint(
        'Replay submission processing failed for runSessionId=$runSessionId: '
        '$error',
      );
      if (!mounted || runSessionId != _runSessionId) return;
      setState(() {
        _runSubmissionStatus = RunSubmissionStatus(
          runSessionId: runSessionId,
          phase: RunSubmissionPhase.internalError,
          updatedAtMs: DateTime.now().millisecondsSinceEpoch,
          message: '$error',
        );
      });
    }
  }

  Map<String, Object?> _buildReplayProvisionalSummary(RunEndedEvent event) {
    return <String, Object?>{
      'runId': event.runId,
      'tick': event.tick,
      'distance': event.distance,
      'reason': event.reason.name,
      'goldEarned': event.goldEarned,
      'collectibles': event.stats.collectibles,
      'collectibleScore': event.stats.collectibleScore,
      'enemyKillCounts': event.stats.enemyKillCounts,
      'rescuedNpcs': event.stats.rescuedNpcs,
      'rescuePoints': event.stats.rescuePoints,
    };
  }

  void _scheduleSubmissionStatusPolling({
    required AppState appState,
    required String runSessionId,
    required RunSubmissionStatus initialStatus,
  }) {
    _stopSubmissionStatusPolling();
    if (initialStatus.isTerminal) {
      return;
    }
    _runSubmissionPollingStartedAt = DateTime.now();
    _runSubmissionPollingFast = true;
    _startSubmissionStatusPollingTimer(
      interval: _initialSubmissionPollInterval,
      appState: appState,
      runSessionId: runSessionId,
    );
  }

  void _startSubmissionStatusPollingTimer({
    required Duration interval,
    required AppState appState,
    required String runSessionId,
  }) {
    _runSubmissionPollTimer = Timer.periodic(interval, (_) {
      unawaited(
        _refreshSubmissionStatus(
          appState: appState,
          runSessionId: runSessionId,
        ),
      );
    });
  }

  Future<void> _refreshSubmissionStatus({
    required AppState appState,
    required String runSessionId,
  }) async {
    if (_runSubmissionPollInFlight) {
      return;
    }
    _runSubmissionPollInFlight = true;
    try {
      final status = await appState.refreshRunSubmissionStatus(
        runSessionId: runSessionId,
      );
      if (!mounted || runSessionId != _runSessionId) {
        return;
      }
      setState(() => _runSubmissionStatus = status);
      if (status.isTerminal) {
        _stopSubmissionStatusPolling();
      }
    } catch (error) {
      debugPrint(
        'Replay status refresh failed for runSessionId=$runSessionId: $error',
      );
    } finally {
      _runSubmissionPollInFlight = false;
      _backOffSubmissionStatusPollingIfNeeded(
        appState: appState,
        runSessionId: runSessionId,
      );
    }
  }

  void _backOffSubmissionStatusPollingIfNeeded({
    required AppState appState,
    required String runSessionId,
  }) {
    if (runSessionId != _runSessionId) {
      return;
    }
    final startedAt = _runSubmissionPollingStartedAt;
    if (!_runSubmissionPollingFast || startedAt == null) {
      return;
    }
    if (DateTime.now().difference(startedAt) < _initialSubmissionPollWindow) {
      return;
    }
    _runSubmissionPollTimer?.cancel();
    _runSubmissionPollTimer = null;
    _runSubmissionPollingFast = false;
    _startSubmissionStatusPollingTimer(
      interval: _steadySubmissionPollInterval,
      appState: appState,
      runSessionId: runSessionId,
    );
  }

  void _stopSubmissionStatusPolling() {
    _runSubmissionPollTimer?.cancel();
    _runSubmissionPollTimer = null;
    _runSubmissionPollInFlight = false;
    _runSubmissionPollingStartedAt = null;
    _runSubmissionPollingFast = false;
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

  void _startGame() {
    if (_started || !_session.isReady) return;
    setState(() => _started = true);
    _clearInputs();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _pausedByLifecycle =
        lifecycle != null && lifecycle != AppLifecycleState.resumed;
    _controller.setPaused(_pausedByLifecycle);
  }

  void _onRestartPressed() {
    if (_restartInFlight) return;
    unawaited(_restartGame());
  }

  Future<void> _restartGame() async {
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
        expectedMode: _runMode,
        expectedLevelId: _levelId,
      ),
    );
    _restartPreparation = preparation;
    try {
      final descriptor = await preparation.prepare();
      if (!mounted) return;
      if (descriptor != null) {
        _restartWithDescriptor(descriptor);
      } else if (preparation.error case final error?) {
        _showRestartFailure(error);
      }
    } catch (error) {
      if (!mounted) return;
      _showRestartFailure(error);
    } finally {
      if (identical(_restartPreparation, preparation)) {
        _restartPreparation = null;
        preparation.dispose();
      }
      if (mounted) setState(() => _restartInFlight = false);
    }
  }

  void _showRestartFailure(Object error) {
    final message = RunStartPreparation.messageFor(error);
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  void _restartWithDescriptor(RunStartDescriptor descriptor) {
    final oldSession = _session;
    final oldAimCancelHitboxRect = _aimCancelHitboxRect;
    final oldForceAimCancelSignal = _forceAimCancelSignal;
    final oldPlayerImpactFeedbackSignal = _playerImpactFeedbackSignal;
    oldSession.controller.removeEventListener(_handleGameEvent);
    oldSession.controller.removeListener(_onControllerTick);
    unawaited(
      oldSession.stop().catchError((Object error) {
        debugPrint('Run cleanup failed: $error');
      }),
    );
    _stopSubmissionStatusPolling();

    setState(() {
      _pausedByLifecycle = false;
      _started = false;
      _exitConfirmOpen = false;
      _descriptor = descriptor;
      _provisionalGoldEarned = null;
      _runSubmissionStatus = null;
      _runSubmissionRunSessionId = null;
      _runReplayJournaled = false;
      _runReplayJournalInFlight = false;
      _runReplayJournalError = null;
      _initGame();
    });
    _controller.setPaused(true);
    _clearInputs();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      oldSession.dispose();
      oldAimCancelHitboxRect.dispose();
      oldForceAimCancelSignal.dispose();
      oldPlayerImpactFeedbackSignal.dispose();
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
  }

  void _closeExitConfirm({required bool resume}) {
    setState(() => _exitConfirmOpen = false);
    if (resume) {
      _controller.setPaused(_pausedBeforeExitConfirm);
    }
  }

  void _confirmExitGiveUp() {
    setState(() => _exitConfirmOpen = false);
    _controller.giveUp();
  }

  void _togglePause() {
    final paused = _controller.snapshot.paused;
    if (!paused) _clearInputs();
    _controller.setPaused(!paused);
  }

  AbilityInputMode _resolveInputMode(RunnerGameplayAction action) {
    final hud = _controller.snapshot.hud;
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

  void _initGame() {
    _session =
        widget.sessionFactory?.call(_descriptor) ??
        RunnerRunSession(descriptor: _descriptor);
    _controller.addEventListener(_handleGameEvent);
    _controller.addListener(_onControllerTick);
    _actions = RunnerSemanticActionDispatcher(
      input: _session.input,
      resolveInputMode: _resolveInputMode,
    );
    _aimCancelHitboxRect = ValueNotifier<Rect?>(null);
    _forceAimCancelSignal = ValueNotifier<int>(0);
    _playerImpactFeedbackSignal = ValueNotifier<int>(0);
    _lastPlayerDamageTick = _controller.snapshot.hud.lastDamageTick;
    _lastChargeTier = 0;
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
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to release the previous run. Exit and try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingRetryInFlight = false);
    }
  }

  void _disposeGame() {
    _stopSubmissionStatusPolling();
    _clearInputs();
    _controller.removeEventListener(_handleGameEvent);
    _controller.removeListener(_onControllerTick);
    _session.dispose();
    _aimCancelHitboxRect.dispose();
    _forceAimCancelSignal.dispose();
    _playerImpactFeedbackSignal.dispose();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _restartPreparation?.dispose();
    _restartPreparation = null;
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
            final session = _session;
            final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
            final metrics = computeViewportMetrics(
              constraints,
              devicePixelRatio,
              virtualWidth,
              virtualHeight,
              widget.viewportMode,
              alignment: widget.viewportAlignment,
            );
            Widget gameView = GameViewport(
              metrics: metrics,
              child: GameWidget(
                key: ValueKey(_game),
                game: _game,
                autofocus: false,
                loadingBuilder: (_) => const SizedBox.shrink(),
                errorBuilder: (_, error) =>
                    _RunLoadFailureReporter(session: session, error: error),
              ),
            );

            return gameView;
          },
        ),
        AnimatedBuilder(
          animation: _session,
          builder: (context, _) {
            final runLoaded = _session.isReady;
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final uiState = _buildUiState(runLoaded: runLoaded);
                if (uiState.showLoadingOverlay) {
                  return _RunLoadingView(
                    message: _session.loadingMessage,
                    errorMessage: _session.errorMessage,
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
                    runEndedEvent: runEndedEvent,
                    scoreTuning: _controller.scoreTuning,
                    tickHz: _controller.tickHz,
                    provisionalGoldEarned: _provisionalGoldEarned,
                    verifiedGold: _verifiedGoldForGameOver(),
                    runSubmissionStatus: _runSubmissionStatus,
                    replaySubmissionJournaled: _runReplayJournaled,
                    replaySubmissionJournalError: _runReplayJournalError,
                    onRetryReplayJournal: _runReplayJournalInFlight
                        ? null
                        : () {
                            final event = _controller.lastRunEndedEvent;
                            if (event == null) return;
                            setState(() {
                              _runReplayJournalInFlight = true;
                              _runReplayJournalError = null;
                            });
                            unawaited(_journalReplayForSubmission(event));
                          },
                  );
                }
                return GameOverlay(
                  controller: _controller,
                  input: _actions,
                  projectileAimPreview: _projectileAimPreview,
                  meleeAimPreview: _meleeAimPreview,
                  aimCancelHitboxRect: _aimCancelHitboxRect,
                  forceAimCancelSignal: _forceAimCancelSignal,
                  playerImpactFeedbackSignal: _playerImpactFeedbackSignal,
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
              },
            );
          },
        ),
      ],
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
          errorTitle: 'Unable to start run',
          errorMessage: errorMessage,
          onContinue: onRetry,
        ),
        if (onExit != null)
          TextButton(onPressed: onExit, child: const Text('Exit')),
      ],
    ),
  );
}

/// Forwards errors from GameWidget mounting without notifying during build.
class _RunLoadFailureReporter extends StatefulWidget {
  const _RunLoadFailureReporter({required this.session, required this.error});
  final RunnerRunSession session;
  final Object error;

  @override
  State<_RunLoadFailureReporter> createState() =>
      _RunLoadFailureReporterState();
}

class _RunLoadFailureReporterState extends State<_RunLoadFailureReporter> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.session.reportHostLoadFailure(widget.error);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
