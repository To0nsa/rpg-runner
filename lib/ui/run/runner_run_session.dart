import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flame/cache.dart';
import 'package:run_protocol/replay_blob.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_registry.dart';

import '../../game/game_controller.dart';
import '../../game/input/aim_preview.dart';
import '../../game/input/runner_input_router.dart';
import '../../game/replay/buffered_ghost_playback.dart';
import '../../game/replay/ghost_render_frame.dart';
import '../../game/replay/run_recorder.dart';
import '../../game/runner_flame_game.dart';
import '../../game/terrain/prepared_terrain_assets.dart';
import '../app/ui_routes.dart';
import '../state/ownership/selection_state.dart';
import 'run_startup_diagnostics.dart';

/// The required dependency that prevented a run from becoming playable.
enum RunStartupFailure { world, recorder }

/// Owns one attempt for an online or debug developer Practice descriptor.
///
/// The controller stays paused until the host starts it. Readiness requires the
/// initial rendered world and, for online runs, the recorder. Ghost failures are
/// contained by playback/rendering. Stop fences late asynchronous completion.
class RunnerRunSession extends ChangeNotifier {
  RunnerRunSession({
    required this.descriptor,
    Future<RunRecorder> Function(RunRecorderHeader)? createRecorder,
    @visibleForTesting Images? imageCache,
  }) {
    if (descriptor.isDeveloperPractice &&
        (!kDebugMode ||
            descriptor.runMode != RunMode.practice ||
            descriptor.boardId != null ||
            descriptor.boardKey != null ||
            descriptor.ghostReplayBootstrap != null)) {
      throw StateError(
        'Developer sessions require debug, local Practice only.',
      );
    }
    final character = PlayerCharacterRegistry.resolve(
      descriptor.playerCharacterId,
    );
    controller = GameController(
      core: GameCore(
        terrainPreparation: PreparedTerrainAssets().prepare,
        seed: descriptor.seed,
        runId: descriptor.runId,
        tickHz: descriptor.tickHz,
        levelDefinition: LevelRegistry.byId(descriptor.levelId),
        playerCharacter: character,
        equippedLoadoutOverride: descriptor.equippedLoadout,
      ),
      tickHz: descriptor.tickHz,
    )..setPaused(true);
    _constructionMicros = _startupWatch?.elapsedMicroseconds;
    input = RunnerInputRouter(controller: controller);
    if (!descriptor.isDeveloperPractice) {
      controller.addAppliedCommandFrameListener(_recordFrame);
    }
    final replay = descriptor.ghostReplayBootstrap?.replayBlob;
    if (replay != null) {
      _ghost = BufferedGhostPlayback(replayBlob: replay)
        ..addListener(_publishGhost);
      controller.addListener(_advanceGhost);
    }
    game = RunnerFlameGame(
      controller: controller,
      input: input,
      imageCache: imageCache,
      projectileAimPreview: projectileAimPreview,
      meleeAimPreview: meleeAimPreview,
      playerCharacter: character,
      ghostRenderListenable: _ghostFeed,
      ghostPreparation: _ghost?.prepare(),
    );
    game.loadState.addListener(_onWorldChanged);
    _recorderPreparation = descriptor.isDeveloperPractice
        ? Future<void>.value()
        : _prepareRecorder(createRecorder ?? _createRecorder);
  }

  final RunStartDescriptor descriptor;
  final Stopwatch? _startupWatch = RunStartupDiagnostics.enabled
      ? (Stopwatch()..start())
      : null;
  int? _constructionMicros;
  bool _startupReported = false;
  late final GameController controller;
  late final RunnerInputRouter input;
  late final RunnerFlameGame game;
  final AimPreviewModel projectileAimPreview = AimPreviewModel();
  final AimPreviewModel meleeAimPreview = AimPreviewModel();
  final ValueNotifier<GhostRenderFrame?> _ghostFeed = ValueNotifier(null);
  BufferedGhostPlayback? _ghost;
  RunRecorder? _recorder;
  Object? _recorderError;
  Object? _hostLoadError;
  late final Future<void> _recorderPreparation;
  Future<void>? _closing;
  bool _stopped = false;

  RunRecorder? get recorder => _recorder;
  bool get isReady =>
      !_stopped &&
      failure == null &&
      game.loadState.value.phase == RunLoadPhase.worldReady &&
      (descriptor.isDeveloperPractice || _recorder != null);

  RunStartupFailure? get failure {
    if (_hostLoadError != null ||
        game.loadState.value.phase == RunLoadPhase.failed) {
      return RunStartupFailure.world;
    }
    return _recorderError == null ? null : RunStartupFailure.recorder;
  }

  String get loadingMessage => switch (game.loadState.value.phase) {
    RunLoadPhase.worldReady => 'Preparing replay recorder...',
    RunLoadPhase.terrainPreparing => 'Preparing terrain...',
    RunLoadPhase.registriesLoaded => 'Preparing ghost...',
    RunLoadPhase.playerAnimationsLoaded => 'Loading game art...',
    _ => 'Building level...',
  };

  String? get errorMessage => switch (failure) {
    RunStartupFailure.world =>
      'Unable to load the level. Retry or return to the previous screen.',
    RunStartupFailure.recorder =>
      'Unable to prepare replay recording. Check available storage and retry.',
    null => null,
  };

  Future<void> _prepareRecorder(
    Future<RunRecorder> Function(RunRecorderHeader) create,
  ) async {
    try {
      _recorder = await RunStartupDiagnostics.measure(
        'recorder',
        () => create(
          RunRecorderHeader(
            runSessionId: descriptor.runSessionId,
            boardId: descriptor.boardId,
            boardKey: descriptor.boardKey,
            tickHz: descriptor.tickHz,
            seed: descriptor.seed,
            levelId: descriptor.levelId.name,
            playerCharacterId: descriptor.playerCharacterId.name,
            loadoutSnapshot: _loadoutSnapshot(descriptor.equippedLoadout),
          ),
        ),
      );
    } catch (error, stack) {
      _recorderError = error;
      debugPrintStack(
        label: 'Run recorder preparation failed: $error',
        stackTrace: stack,
        maxFrames: 12,
      );
    }
    if (!_stopped) {
      _reportStartup();
      notifyListeners();
    }
  }

  static Future<RunRecorder> _createRecorder(RunRecorderHeader header) =>
      RunRecorder.create(
        header: header,
      );

  /// Reports host mounting failures outside Flame's onLoad future.
  /// The widget forwards these after its build, never during notifier dispatch.
  void reportHostLoadFailure(Object error) {
    if (_stopped || failure == RunStartupFailure.world) return;
    _hostLoadError = error;
    debugPrint('Run host loading failed: $error');
    notifyListeners();
  }

  void _recordFrame(ReplayCommandFrameV1 frame) {
    try {
      _recorder?.appendFrame(frame);
    } catch (error) {
      debugPrint('Replay frame append failed: $error');
    }
  }

  void _onWorldChanged() {
    if (!_stopped) {
      _reportStartup();
      notifyListeners();
    }
  }

  void _reportStartup() {
    final watch = _startupWatch;
    if (watch == null || _startupReported) return;
    final ready = isReady;
    RunStartupDiagnostics.emit(ready ? 'ready' : 'worldProgress', {
      'elapsedMs': watch.elapsedMicroseconds / 1000,
      'worldPhase': game.loadState.value.phase.name,
      if (ready) ...{
        'constructionMs': (_constructionMicros ?? 0) / 1000,
        'level': descriptor.levelId.name,
        'seed': descriptor.seed,
        'character': descriptor.playerCharacterId.name,
        'developerPractice': descriptor.isDeveloperPractice,
        'tasksMs': game.loadTimings.map(
          (name, duration) => MapEntry(name, duration.inMicroseconds / 1000),
        ),
        'imageCount': game.images.keys.length,
      },
    });
    if (ready) {
      watch.stop();
      _startupReported = true;
    }
  }

  void _advanceGhost() => _ghost?.advanceToTick(controller.tick);

  void _publishGhost() {
    if (_stopped) return;
    _ghostFeed.value = _ghost?.frame;
    if (_ghost?.error case final error?) {
      debugPrint('Ghost playback failed: $error');
    }
  }

  /// Stops work immediately; completion also closes any late-created recorder.
  /// Await before retrying the same ticket, whose recorder uses the same files.
  Future<void> stop() {
    if (_closing != null) return _closing!;
    _stopped = true;
    game.loadState.removeListener(_onWorldChanged);
    game.cancelPreparation();
    controller.removeListener(_advanceGhost);
    controller.removeAppliedCommandFrameListener(_recordFrame);
    controller.shutdown();
    _ghost?.dispose();
    _ghost = null;
    _closing = _closeRecorder();
    return _closing!;
  }

  Future<void> _closeRecorder() async {
    await _recorderPreparation;
    final recorder = _recorder;
    _recorder = null;
    await recorder?.close();
  }

  @override
  void dispose() {
    unawaited(
      stop().catchError((Object error, StackTrace stack) {
        debugPrintStack(
          label: 'Run recorder cleanup failed: $error',
          stackTrace: stack,
          maxFrames: 12,
        );
      }),
    );
    controller.dispose();
    projectileAimPreview.dispose();
    meleeAimPreview.dispose();
    _ghostFeed.dispose();
    super.dispose();
  }
}

Map<String, Object?> _loadoutSnapshot(EquippedLoadoutDef loadout) => {
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
