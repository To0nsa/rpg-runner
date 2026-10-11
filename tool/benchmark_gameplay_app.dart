import 'dart:async';
import 'dart:convert';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/track/staged_terrain_preparer.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:rpg_runner/game/game_controller.dart';
import 'package:rpg_runner/game/input/aim_preview.dart';
import 'package:rpg_runner/game/input/runner_gameplay_action.dart';
import 'package:rpg_runner/game/input/runner_input_router.dart';
import 'package:rpg_runner/game/input/runner_semantic_action_dispatcher.dart';
import 'package:rpg_runner/game/runner_flame_game.dart';

/// Autonomous smoke runs with normal gameplay and real assets.
/// Death ends each attempt; this is not a level-completion or boss-combat gate.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: _GameplayBenchmark()));
}

class _GameplayBenchmark extends StatefulWidget {
  const _GameplayBenchmark();
  @override
  State<_GameplayBenchmark> createState() => _GameplayBenchmarkState();
}

class _GameplayBenchmarkState extends State<_GameplayBenchmark> {
  final _scenarios = [
    (LevelId.forest, 857469563, PlayerCharacterRegistry.eloise),
    (LevelId.forest, 42, PlayerCharacterRegistry.eloise),
    (LevelId.field, 42, PlayerCharacterRegistry.eloise),
    (LevelId.new_level, 42, PlayerCharacterRegistry.eloise),
    for (final player in PlayerCharacterRegistry.all)
      if (player.id != PlayerCharacterRegistry.eloise.id)
        (LevelId.forest, 857469563, player),
  ];
  final _rows = <Map<String, Object?>>[];
  final _aim = ValueNotifier(AimPreviewState.inactive);
  GameController? _controller;
  _BenchmarkGame? _game;
  String? _summary;

  @override
  void initState() {
    super.initState();
    _startNext();
  }

  void _startNext() {
    final (levelId, seed, player) = _scenarios[_rows.length];
    final core = GameCore(
      seed: seed,
      levelDefinition: LevelRegistry.byId(levelId),
      playerCharacter: player,
      terrainPreparation: (bindings, profiles) async {
        final delayMs =
            int.tryParse(Uri.base.queryParameters['terrainDelayMs'] ?? '') ?? 0;
        if (delayMs > 0) {
          await Future<void>.delayed(Duration(milliseconds: delayMs));
        }
        return prepareTerrainCandidate(bindings, profiles);
      },
    );
    final controller = Uri.base.queryParameters['coldTerrain'] == '1'
        ? _ColdTerrainController(core: core)
        : GameController(core: core);
    _controller = controller;
    _game = _BenchmarkGame(
      core: core,
      levelId: levelId,
      seed: seed,
      controller: controller,
      input: RunnerInputRouter(controller: controller),
      playerCharacter: player,
      aim: _aim,
      complete: _completeAttempt,
    );
  }

  void _completeAttempt(Map<String, Object?> row) {
    if (!mounted) return;
    _rows.add(row);
    debugPrint('GAMEPLAY_BENCHMARK_ROW ${jsonEncode(row)}');
    final previous = _controller!;
    previous.shutdown();
    setState(() {
      _game = null;
      _controller = null;
    });
    // Remove the old Flame scene before constructing another run and cache.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      previous.dispose();
      if (!mounted) return;
      if (_rows.length == _scenarios.length) {
        final result = {'attempts': _rows.length, 'runs': _rows};
        debugPrint('GAMEPLAY_BENCHMARK_SUMMARY ${jsonEncode(result)}');
        setState(() {
          _summary = const JsonEncoder.withIndent('  ').convert(result);
        });
      } else {
        setState(_startNext);
      }
    });
  }

  @override
  void dispose() {
    _controller?.shutdown();
    _controller?.dispose();
    _aim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: switch ((_game, _summary)) {
      (final game?, _) => GameWidget(game: game, key: ObjectKey(game)),
      (_, final summary?) => SingleChildScrollView(
        child: SelectableText(summary),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    },
  );
}

// Deliberately omit the startup cache only in this standalone fault-injection
// harness. Live stepping still uses the unmodified production controller.
class _ColdTerrainController extends GameController {
  _ColdTerrainController({required super.core});
  @override
  Future<void> prepareTerrainAhead() async {}
}

class _BenchmarkGame extends RunnerFlameGame {
  _BenchmarkGame({
    required this.core,
    required this.levelId,
    required this.seed,
    required super.controller,
    required super.input,
    required super.playerCharacter,
    required ValueNotifier<AimPreviewState> aim,
    required this.complete,
  }) : super(projectileAimPreview: aim, meleeAimPreview: aim) {
    _actions = RunnerSemanticActionDispatcher(
      input: input,
      resolveInputMode: (action) => switch (action) {
        RunnerGameplayAction.primary => controller.snapshot.hud.meleeInputMode,
        RunnerGameplayAction.secondary =>
          controller.snapshot.hud.secondaryInputMode,
        RunnerGameplayAction.projectile =>
          controller.snapshot.hud.projectileInputMode,
        RunnerGameplayAction.mobility =>
          controller.snapshot.hud.mobilityInputMode,
        _ => AbilityInputMode.tap,
      },
    );
  }

  final GameCore core;
  final LevelId levelId;
  final int seed;
  final void Function(Map<String, Object?>) complete;
  late final RunnerSemanticActionDispatcher _actions;
  final _watch = Stopwatch();
  final _geometryVersions = <int>{};
  int _frames = 0;
  int _maxEntities = 0;
  bool _started = false;
  bool _finished = false;
  final _terrainWaitWatch = Stopwatch();
  int _terrainWaits = 0;
  int _terrainWaitFrames = 0;
  int _terrainFailures = 0;
  TerrainReadiness _lastReadiness = TerrainReadiness.ready;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    controller.setPaused(false);
    debugPrint(
      'GAMEPLAY_BENCHMARK_ACTIVE '
      '${levelId.name}/${playerCharacter.id.name}/$seed',
    );
    _watch.start();
    _started = true;
  }

  @override
  void update(double dt) {
    if (_started && !_finished) {
      _actions.setMoveAxis(1);
      if (_frames % 32 == 0) {
        _actions.triggerAction(RunnerGameplayAction.jump);
      }
      _cycle(RunnerGameplayAction.primary, 48, 8);
      _cycle(RunnerGameplayAction.projectile, 110, 17);
      _cycle(RunnerGameplayAction.secondary, 180, 12);
      _cycle(RunnerGameplayAction.mobility, 220, 5);
      if (_frames % 240 == 0) {
        _actions.triggerAction(RunnerGameplayAction.spell);
      }
      if (_frames % 110 < 17) _actions.setAimDir(0.8, -0.6);
    }
    super.update(dt);
    if (!_started || _finished) return;
    _frames++;
    final readiness = controller.terrainReadiness;
    if (readiness == TerrainReadiness.preparing) {
      _terrainWaitFrames++;
      if (_lastReadiness != readiness) {
        _terrainWaits++;
        _terrainWaitWatch.start();
      }
    } else {
      _terrainWaitWatch.stop();
    }
    if (readiness == TerrainReadiness.failed && _lastReadiness != readiness) {
      _terrainFailures++;
    }
    _lastReadiness = readiness;
    final snapshot = controller.snapshot;
    if (snapshot.entities.length > _maxEntities) {
      _maxEntities = snapshot.entities.length;
    }
    final geometry = snapshot.stagedTerrainRenderSnapshot;
    if (geometry != null) _geometryVersions.add(geometry.geometryVersion);
    if (!snapshot.gameOver && _watch.elapsed.inSeconds < 45) return;
    _finished = true;
    _watch.stop();
    _actions.cancelAll();
    controller.setPaused(true);
    final stats = core.terrainPreparationStats;
    final row = <String, Object?>{
      'level': levelId.name,
      'seed': seed,
      'character': playerCharacter.id.name,
      'ticks': snapshot.tick,
      'wallMs': _watch.elapsedMicroseconds / 1000,
      'frames': _frames,
      'distance': snapshot.distance,
      'maxEntities': _maxEntities,
      'geometryVersions': _geometryVersions.length,
      'endedNaturally': snapshot.gameOver,
      'hits': stats?.hits,
      'misses': stats?.misses,
      'preparationError': stats?.lastError,
      'terrainWaits': _terrainWaits,
      'terrainWaitFrames': _terrainWaitFrames,
      'terrainWaitWallMs': _terrainWaitWatch.elapsedMicroseconds / 1000,
      'terrainFailures': _terrainFailures,
      'coldTerrain': Uri.base.queryParameters['coldTerrain'] == '1',
      'terrainDelayMs':
          int.tryParse(Uri.base.queryParameters['terrainDelayMs'] ?? '') ?? 0,
    };
    unawaited(Future<void>(() => complete(row)));
  }

  void _cycle(RunnerGameplayAction action, int period, int releaseAt) {
    if (_frames % period == 0) _actions.beginAction(action);
    if (_frames % period == releaseAt) _actions.releaseAction(action);
  }
}
