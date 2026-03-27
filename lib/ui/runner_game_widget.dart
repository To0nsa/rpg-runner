import 'dart:async';
import 'dart:io';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:run_protocol/board_key.dart';
import 'package:run_protocol/replay_blob.dart';

import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/contracts/render_contract.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/snapshots/game_state_snapshot.dart';
import '../game/game_controller.dart';
import '../game/input/aim_preview.dart';
import '../game/replay/run_recorder.dart';
import '../game/replay/ghost_playback_runner.dart';
import '../game/input/runner_input_router.dart';
import '../game/runner_flame_game.dart';
import 'app/ui_routes.dart';
import 'hud/game/game_overlay.dart';
import 'hud/gameover/game_over_overlay.dart';
import 'haptics/haptics_cue.dart';
import 'haptics/haptics_service.dart';
import 'runner_game_ui_state.dart';
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
/// cleans it up on dispose.
///
/// Viewport scaling is applied by [GameViewport] to keep the fixed virtual
/// resolution fitted to the available screen.
class RunnerGameWidget extends StatefulWidget {
  const RunnerGameWidget({
    super.key,
    required this.runSessionId,
    required this.runId,
    required this.seed,
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
  });

  /// Master RNG seed for deterministic generation.
  final int seed;

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

  @override
  State<RunnerGameWidget> createState() => _RunnerGameWidgetState();
}

class _RunnerGameWidgetState extends State<RunnerGameWidget>
    with WidgetsBindingObserver {
  final UiHaptics _haptics = const UiHapticsService();
  final ValueNotifier<GameStateSnapshot?> _ghostSnapshotBridge =
      ValueNotifier<GameStateSnapshot?>(null);
  final ValueNotifier<List<GameEvent>> _ghostEventsBridge =
      ValueNotifier<List<GameEvent>>(const <GameEvent>[]);
    final ValueNotifier<ReplayBlobV1?> _ghostReplayBlobBridge =
      ValueNotifier<ReplayBlobV1?>(null);

  bool _pausedByLifecycle = false;
  bool _started = false;
  bool _exitConfirmOpen = false;
  bool _pausedBeforeExitConfirm = false;
  bool _restartInFlight = false;

  late String _runSessionId;
  late int _seed;
  late LevelId _levelId;
  late PlayerCharacterId _playerCharacterId;
  late RunMode _runMode;
  late EquippedLoadoutDef _equippedLoadout;
  late String? _boardId;
  late BoardKey? _boardKey;
  GhostReplayBootstrap? _ghostReplayBootstrap;
  GhostPlaybackRunner? _ghostPlaybackRunner;

  late int _runId;
  int? _provisionalGoldEarned;
  RunSubmissionStatus? _runSubmissionStatus;
  Timer? _runSubmissionPollTimer;
  bool _runSubmissionPollInFlight = false;
  String? _runSubmissionRunSessionId;

  late GameController _controller;
  late RunnerInputRouter _input;
  late AimPreviewModel _projectileAimPreview;
  late AimPreviewModel _meleeAimPreview;
  late ValueNotifier<Rect?> _aimCancelHitboxRect;
  late ValueNotifier<int> _forceAimCancelSignal;
  late ValueNotifier<int> _playerImpactFeedbackSignal;
  int _lastPlayerDamageTick = -1;
  int _lastChargeTier = 0;
  late RunnerFlameGame _game;
  RunRecorder? _runRecorder;
  bool _runRecorderInitializing = false;
  String? _runRecorderInitError;
  int _runRecorderGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _validateInitialRunInputs();
    _runSessionId = widget.runSessionId;
    _runId = widget.runId;
    _seed = widget.seed;
    _levelId = widget.levelId;
    _playerCharacterId = widget.playerCharacterId;
    _runMode = widget.runMode;
    _equippedLoadout = widget.equippedLoadout;
    _boardId = widget.boardId;
    _boardKey = widget.boardKey;
    _ghostReplayBootstrap = widget.ghostReplayBootstrap;
    _initGame();

    // Start in "ready" (paused) until the user taps to begin.
    _controller.setPaused(true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _onLifecycle(state);

  void _onLifecycle(AppLifecycleState state) {
    final runLoaded = _game.loadState.value.phase == RunLoadPhase.worldReady;
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
    _input.setMoveAxis(0);
    _input.clearAimDir();
    _input.endPrimaryHold();
    _input.endSecondaryHold();
    _input.endMobilityHold();
    _input.endAbilitySlotHold(AbilitySlot.projectile);
    _projectileAimPreview.end();
    _meleeAimPreview.end();
    _input.pumpHeldInputs();
  }

  void _cancelHeldChargedAim() {
    _input.clearAimDir();
    _projectileAimPreview.end();
    _meleeAimPreview.end();
    _forceAimCancelSignal.value = _forceAimCancelSignal.value + 1;
    _input.pumpHeldInputs();
  }

  void _onControllerTick() {
    _advanceGhostPlaybackToPlayerTick();
    _emitChargeHaptics();

    final damageTick = _controller.snapshot.hud.lastDamageTick;
    if (damageTick <= _lastPlayerDamageTick) return;
    _lastPlayerDamageTick = damageTick;
    final hud = _controller.snapshot.hud;
    if (hud.chargeEnabled && hud.chargeActive) {
      _cancelHeldChargedAim();
    }
  }

  void _advanceGhostPlaybackToPlayerTick() {
    final runner = _ghostPlaybackRunner;
    if (runner == null || runner.isComplete) {
      return;
    }
    try {
      runner.advanceToTick(_controller.tick);
      _publishGhostRenderFeed();
    } catch (error) {
      debugPrint('Ghost playback failed: $error');
      _ghostPlaybackRunner = null;
      _clearGhostRenderFeed();
    }
  }

  void _publishGhostRenderFeed() {
    final runner = _ghostPlaybackRunner;
    if (runner == null) {
      _clearGhostRenderFeed();
      return;
    }
    _ghostReplayBlobBridge.value = runner.replayBlob;
    _ghostSnapshotBridge.value = runner.snapshot;
    if (runner.drainedEvents.isEmpty) {
      _ghostEventsBridge.value = const <GameEvent>[];
      return;
    }
    _ghostEventsBridge.value = List<GameEvent>.unmodifiable(runner.drainedEvents);
    runner.clearDrainedEvents();
  }

  void _clearGhostRenderFeed() {
    _ghostReplayBlobBridge.value = null;
    _ghostSnapshotBridge.value = null;
    _ghostEventsBridge.value = const <GameEvent>[];
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
    unawaited(_submitReplayForValidation(event));
  }

  Future<void> _submitReplayForValidation(RunEndedEvent event) async {
    final appState = _maybeAppState();
    if (_runRecorder == null && _runRecorderInitializing) {
      await _waitForRunRecorderReady();
    }
    final recorder = _runRecorder;
    if (appState == null || recorder == null) {
      if (!mounted) return;
      setState(() {
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
      final status = await appState.submitRunReplay(
        runSessionId: _runSessionId,
        runMode: _runMode,
        replayFilePath: finalized.replayBlobFile.path,
        canonicalSha256: finalized.replayBlob.canonicalSha256,
        contentLengthBytes: replaySize,
        provisionalSummary: summary,
      );
      if (!mounted) return;
      setState(() => _runSubmissionStatus = status);
      _scheduleSubmissionStatusPolling(
        appState: appState,
        runSessionId: _runSessionId,
        initialStatus: status,
      );
    } catch (error) {
      debugPrint(
        'Replay submission failed for runSessionId=$_runSessionId: $error',
      );
      if (!mounted) return;
      setState(() {
        _runSubmissionStatus = RunSubmissionStatus(
          runSessionId: _runSessionId,
          phase: RunSubmissionPhase.internalError,
          updatedAtMs: DateTime.now().millisecondsSinceEpoch,
          message: '$error',
        );
      });
    }
  }

  Future<void> _waitForRunRecorderReady() async {
    const pollStep = Duration(milliseconds: 50);
    const maxWait = Duration(seconds: 2);
    var waited = Duration.zero;
    while (_runRecorder == null &&
        _runRecorderInitializing &&
        waited < maxWait) {
      await Future<void>.delayed(pollStep);
      waited += pollStep;
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
    _runSubmissionPollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
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
    }
  }

  void _stopSubmissionStatusPolling() {
    _runSubmissionPollTimer?.cancel();
    _runSubmissionPollTimer = null;
    _runSubmissionPollInFlight = false;
  }

  void _onAppliedCommandFrame(ReplayCommandFrameV1 frame) {
    final recorder = _runRecorder;
    if (recorder == null) {
      return;
    }
    try {
      recorder.appendFrame(frame);
    } catch (error) {
      _runRecorderInitError = 'Replay recorder frame append failed: $error';
      debugPrint(_runRecorderInitError);
    }
  }

  Future<void> _initializeRunRecorder() async {
    if (_runRecorderInitializing) {
      return;
    }
    _runRecorderInitializing = true;
    final generation = ++_runRecorderGeneration;
    try {
      final spoolDirectory = Directory(
        '${Directory.systemTemp.path}${Platform.pathSeparator}rpg_runner${Platform.pathSeparator}replay_spool',
      );
      final recorder = await RunRecorder.create(
        header: RunRecorderHeader(
          runSessionId: _runSessionId,
          boardId: _boardId,
          boardKey: _boardKey,
          tickHz: _controller.tickHz,
          seed: _seed,
          levelId: _levelId.name,
          playerCharacterId: _playerCharacterId.name,
          loadoutSnapshot: _loadoutSnapshot(_equippedLoadout),
        ),
        spoolDirectory: spoolDirectory,
        fileStem: _runSessionId,
      );
      if (!mounted || generation != _runRecorderGeneration) {
        await recorder.close();
        return;
      }
      _runRecorder = recorder;
      _runRecorderInitError = null;
    } catch (error) {
      if (!mounted || generation != _runRecorderGeneration) {
        return;
      }
      _runRecorderInitError = 'Replay recorder initialization failed: $error';
      debugPrint(_runRecorderInitError);
    } finally {
      if (mounted && generation == _runRecorderGeneration) {
        _runRecorderInitializing = false;
      }
    }
  }

  void _initializeGhostPlaybackRunner() {
    final bootstrap = _ghostReplayBootstrap;
    if (bootstrap == null) {
      _ghostPlaybackRunner = null;
      _clearGhostRenderFeed();
      return;
    }
    try {
      final runner = GhostPlaybackRunner.fromReplayBlob(bootstrap.replayBlob);
      _ghostPlaybackRunner = runner;
      _publishGhostRenderFeed();
    } catch (error) {
      _ghostPlaybackRunner = null;
      _clearGhostRenderFeed();
      debugPrint(
        'Ghost playback initialization failed for entryId='
        '${bootstrap.manifest.entryId}: $error',
      );
    }
  }

  Map<String, Object?> _loadoutSnapshot(EquippedLoadoutDef loadout) {
    return <String, Object?>{
      'mask': loadout.mask,
      'mainWeaponId': loadout.mainWeaponId.name,
      'offhandWeaponId': loadout.offhandWeaponId.name,
      'spellBookId': loadout.spellBookId.name,
      'projectileSlotSpellId': loadout.projectileSlotSpellId.name,
      'accessoryId': loadout.accessoryId.name,
      'abilityPrimaryId': loadout.abilityPrimaryId,
      'abilitySecondaryId': loadout.abilitySecondaryId,
      'abilityProjectileId': loadout.abilityProjectileId,
      'abilitySpellId': loadout.abilitySpellId,
      'abilityMobilityId': loadout.abilityMobilityId,
      'abilityJumpId': loadout.abilityJumpId,
    };
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
    if (_runRecorder == null) {
      if (!_runRecorderInitializing) {
        unawaited(_initializeRunRecorder());
      }
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger != null) {
        final message = _runRecorderInitError == null
            ? 'Preparing replay recorder. Try starting again.'
            : 'Replay recorder failed to initialize. Restart run to retry.';
        messenger.showSnackBar(SnackBar(content: Text(message)));
      }
      return;
    }
    setState(() => _started = true);
    _clearInputs();
    _controller.setPaused(false);
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
    try {
      final descriptor = await appState.prepareRunStartDescriptor(
        expectedMode: _runMode,
        expectedLevelId: _levelId,
      );
      if (!mounted) return;
      _restartWithDescriptor(descriptor);
    } catch (error) {
      if (!mounted) return;
      _showRestartFailure(error);
    } finally {
      if (mounted) {
        setState(() => _restartInFlight = false);
      }
    }
  }

  void _showRestartFailure(Object error) {
    final message =
        error is RunStartRemoteException && error.isPreconditionFailed
        ? 'Run restart requirements changed. Return to hub and start a new run.'
        : 'Unable to restart run right now. Check your connection and try again.';
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  void _restartWithDescriptor(RunStartDescriptor descriptor) {
    final oldController = _controller;
    final oldProjectilePreview = _projectileAimPreview;
    final oldMeleePreview = _meleeAimPreview;
    final oldAimCancelHitboxRect = _aimCancelHitboxRect;
    final oldForceAimCancelSignal = _forceAimCancelSignal;
    final oldPlayerImpactFeedbackSignal = _playerImpactFeedbackSignal;
    final oldRecorder = _runRecorder;
    oldController.removeEventListener(_handleGameEvent);
    oldController.removeListener(_onControllerTick);
    oldController.removeAppliedCommandFrameListener(_onAppliedCommandFrame);
    _stopSubmissionStatusPolling();

    setState(() {
      _pausedByLifecycle = false;
      _started = false;
      _exitConfirmOpen = false;
      _runSessionId = descriptor.runSessionId;
      _runId = descriptor.runId;
      _seed = descriptor.seed;
      _levelId = descriptor.levelId;
      _playerCharacterId = descriptor.playerCharacterId;
      _runMode = descriptor.runMode;
      _equippedLoadout = descriptor.equippedLoadout;
      _boardId = descriptor.boardId;
      _boardKey = descriptor.boardKey;
      _ghostReplayBootstrap = descriptor.ghostReplayBootstrap;
      _provisionalGoldEarned = null;
      _runSubmissionStatus = null;
      _runSubmissionRunSessionId = null;
      _runRecorder = null;
      _runRecorderInitError = null;
      _runRecorderInitializing = false;
      _ghostPlaybackRunner = null;
      _initGame();
    });
    _controller.setPaused(true);
    _clearInputs();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      oldController.shutdown();
      oldController.dispose();
      oldProjectilePreview.dispose();
      oldMeleePreview.dispose();
      oldAimCancelHitboxRect.dispose();
      oldForceAimCancelSignal.dispose();
      oldPlayerImpactFeedbackSignal.dispose();
      unawaited(oldRecorder?.close() ?? Future<void>.value());
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

  void _initGame() {
    final playerCharacter = PlayerCharacterRegistry.resolve(_playerCharacterId);
    _controller = GameController(
      core: GameCore(
        seed: _seed,
        runId: _runId,
        levelDefinition: LevelRegistry.byId(_levelId),
        playerCharacter: playerCharacter,
        equippedLoadoutOverride: _equippedLoadout,
      ),
    );
    _controller.addEventListener(_handleGameEvent);
    _controller.addListener(_onControllerTick);
    _controller.addAppliedCommandFrameListener(_onAppliedCommandFrame);
    _input = RunnerInputRouter(controller: _controller);
    _projectileAimPreview = AimPreviewModel();
    _meleeAimPreview = AimPreviewModel();
    _aimCancelHitboxRect = ValueNotifier<Rect?>(null);
    _forceAimCancelSignal = ValueNotifier<int>(0);
    _playerImpactFeedbackSignal = ValueNotifier<int>(0);
    _lastPlayerDamageTick = _controller.snapshot.hud.lastDamageTick;
    _lastChargeTier = 0;
    _game = RunnerFlameGame(
      controller: _controller,
      input: _input,
      projectileAimPreview: _projectileAimPreview,
      meleeAimPreview: _meleeAimPreview,
      playerCharacter: playerCharacter,
      ghostSnapshotListenable: _ghostSnapshotBridge,
      ghostEventsListenable: _ghostEventsBridge,
      ghostReplayBlobListenable: _ghostReplayBlobBridge,
    );
    _runRecorder = null;
    _runRecorderInitError = null;
    _runRecorderInitializing = false;
    _initializeGhostPlaybackRunner();
    unawaited(_initializeRunRecorder());
  }

  void _disposeGame() {
    _stopSubmissionStatusPolling();
    _controller.removeEventListener(_handleGameEvent);
    _controller.removeListener(_onControllerTick);
    _controller.removeAppliedCommandFrameListener(_onAppliedCommandFrame);
    _controller.shutdown();
    _controller.dispose();
    unawaited(_runRecorder?.close() ?? Future<void>.value());
    _runRecorder = null;
    _ghostPlaybackRunner = null;
    _clearGhostRenderFeed();
    _projectileAimPreview.dispose();
    _meleeAimPreview.dispose();
    _aimCancelHitboxRect.dispose();
    _forceAimCancelSignal.dispose();
    _playerImpactFeedbackSignal.dispose();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeGame();
    _ghostReplayBlobBridge.dispose();
    _ghostSnapshotBridge.dispose();
    _ghostEventsBridge.dispose();
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
                loadingBuilder: null,
              ),
            );

            return gameView;
          },
        ),
        ValueListenableBuilder<RunLoadState>(
          valueListenable: _game.loadState,
          builder: (context, loadState, _) {
            final runLoaded = loadState.phase == RunLoadPhase.worldReady;
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final uiState = _buildUiState(runLoaded: runLoaded);
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
                    levelId: _controller.snapshot.levelId,
                    runMode: _runMode,
                    runEndedEvent: runEndedEvent,
                    scoreTuning: _controller.scoreTuning,
                    tickHz: _controller.tickHz,
                    provisionalGoldEarned: _provisionalGoldEarned,
                    verifiedGold: _verifiedGoldForGameOver(),
                    runSubmissionStatus: _runSubmissionStatus,
                  );
                }
                return GameOverlay(
                  controller: _controller,
                  input: _input,
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
