import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/abilities/ability_def.dart';
import '../core/contracts/render_contract.dart';
import '../core/events/game_event.dart';
import '../core/ecs/stores/combat/equipped_loadout_store.dart';
import '../core/game_core.dart';
import '../core/levels/level_id.dart';
import '../core/levels/level_registry.dart';
import '../core/players/player_character_definition.dart';
import '../core/players/player_character_registry.dart';
import '../game/game_controller.dart';
import '../game/input/aim_preview.dart';
import '../game/input/runner_input_router.dart';
import '../game/runner_flame_game.dart';
import 'hud/game/game_overlay.dart';
import 'hud/gameover/game_over_overlay.dart';
import 'bootstrap/loader_content.dart';
import 'components/menu_layout.dart';
import 'haptics/haptics_cue.dart';
import 'haptics/haptics_service.dart';
import 'runner_game_ui_state.dart';
import 'state/app_state.dart';
import 'state/profile_counter_keys.dart';
import 'state/selection_state.dart';
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
    this.runId = 0,
    this.seed = 1,
    required this.levelId,
    this.playerCharacterId = PlayerCharacterId.eloise,
    this.runType = RunType.practice,
    this.equippedLoadout = const EquippedLoadoutDef(),
    this.onExit,
    this.showExitButton = true,
    this.viewportMode = ViewportScaleMode.pixelPerfectContain,
    this.viewportAlignment = Alignment.center,
  });

  /// Master RNG seed for deterministic generation.
  final int seed;

  /// Unique identifier for this run session (replay/ghost).
  final int runId;

  /// Which core level definition to run.
  final LevelId levelId;

  /// Which player character to use for this run.
  final PlayerCharacterId playerCharacterId;

  /// Menu-selected run type (practice/competitive). Used by UI (e.g. leaderboard
  /// namespacing) and may later affect rules/tuning.
  final RunType runType;

  /// Per-run loadout override (from menu / meta inventory).
  final EquippedLoadoutDef equippedLoadout;

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
  final Random _runIdRandom = Random();
  final UiHaptics _haptics = const UiHapticsService();

  bool _pausedByLifecycle = false;
  bool _started = false;
  bool _exitConfirmOpen = false;
  bool _pausedBeforeExitConfirm = false;

  late int _runId;
  int? _lastRewardedRunId;
  int? _lastGoldEarned;
  int? _lastGoldTotal;

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _runId = widget.runId != 0 ? widget.runId : _createFallbackRunId();
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

  int _createFallbackRunId() {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final salt = _runIdRandom.nextInt(1 << 20);
    return (nowMs << 20) | salt;
  }

  int _nextRunId() {
    final appState = _maybeAppState();
    if (appState != null) return appState.createRunId();
    return _createFallbackRunId();
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
    _grantGold(event);
  }

  void _grantGold(RunEndedEvent event) {
    final runId = event.runId;
    if (_lastRewardedRunId == runId) return;

    _lastRewardedRunId = runId;
    _lastGoldEarned = event.goldEarned;

    final appState = _maybeAppState();
    if (appState == null) {
      _lastGoldTotal = null;
      return;
    }

    final currentGold = appState.profile.counters[ProfileCounterKeys.gold] ?? 0;
    final nextGold = currentGold + event.goldEarned;
    _lastGoldTotal = nextGold;

    appState.updateProfile((current) {
      final counters = Map<String, int>.from(current.counters);
      counters[ProfileCounterKeys.gold] = nextGold;
      return current.copyWith(counters: counters);
    });
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
    setState(() => _started = true);
    _clearInputs();
    _controller.setPaused(false);
  }

  void _restartGame() {
    final oldController = _controller;
    final oldProjectilePreview = _projectileAimPreview;
    final oldMeleePreview = _meleeAimPreview;
    final oldAimCancelHitboxRect = _aimCancelHitboxRect;
    final oldForceAimCancelSignal = _forceAimCancelSignal;
    final oldPlayerImpactFeedbackSignal = _playerImpactFeedbackSignal;
    oldController.removeEventListener(_handleGameEvent);
    oldController.removeListener(_onControllerTick);

    setState(() {
      _pausedByLifecycle = false;
      _started = false;
      _exitConfirmOpen = false;
      _runId = _nextRunId();
      _lastGoldEarned = null;
      _lastGoldTotal = null;
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
    final playerCharacter = PlayerCharacterRegistry.resolve(
      widget.playerCharacterId,
    );
    _controller = GameController(
      core: GameCore(
        seed: widget.seed,
        runId: _runId,
        levelDefinition: LevelRegistry.byId(widget.levelId),
        playerCharacter: playerCharacter,
        equippedLoadoutOverride: widget.equippedLoadout,
      ),
    );
    _controller.addEventListener(_handleGameEvent);
    _controller.addListener(_onControllerTick);
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
    );
  }

  void _disposeGame() {
    _controller.removeEventListener(_handleGameEvent);
    _controller.removeListener(_onControllerTick);
    _controller.shutdown();
    _controller.dispose();
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
                loadingBuilder: (_) => const _RunLoadingView(),
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
                      'gameOver-$runEndKey-${runEndedEvent?.reason}',
                    ),
                    visible: true,
                    onRestart: _restartGame,
                    onExit: widget.onExit,
                    showExitButton: widget.showExitButton,
                    levelId: _controller.snapshot.levelId,
                    runType: widget.runType,
                    runEndedEvent: runEndedEvent,
                    scoreTuning: _controller.scoreTuning,
                    tickHz: _controller.tickHz,
                    goldEarned: _lastGoldEarned,
                    totalGold: _lastGoldTotal,
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

class _RunLoadingView extends StatelessWidget {
  const _RunLoadingView();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: MenuLayout(
        alignment: Alignment.center,
        scrollable: false,
        child: const LoaderContent(),
      ),
    );
  }
}
