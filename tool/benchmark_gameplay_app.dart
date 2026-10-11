import 'dart:async';
import 'dart:convert';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:rpg_runner/game/debug/render_debug_flags.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/abilities/ability_def.dart';
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
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }
  RenderDebugFlags.drawActorHitboxes = false;
  runApp(const MaterialApp(home: _GameplayBenchmark()));
}

// Native profile builds accept the same options as browser queries.
final _benchmarkOptions = {
  ...Uri.splitQueryString(const String.fromEnvironment('BENCHMARK_OPTIONS')),
  ...Uri.base.queryParameters,
};

class _GameplayBenchmark extends StatefulWidget {
  const _GameplayBenchmark();
  @override
  State<_GameplayBenchmark> createState() => _GameplayBenchmarkState();
}

class _GameplayBenchmarkState extends State<_GameplayBenchmark> {
  late final _scenarios =
      [
            (LevelId.forest, 857469563, PlayerCharacterRegistry.eloise),
            (LevelId.forest, 42, PlayerCharacterRegistry.eloise),
            (LevelId.field, 42, PlayerCharacterRegistry.eloise),
            (LevelId.new_level, 42, PlayerCharacterRegistry.eloise),
            for (final player in PlayerCharacterRegistry.all)
              if (player.id != PlayerCharacterRegistry.eloise.id)
                (LevelId.forest, 857469563, player),
          ]
          .where((scenario) {
            final query = _benchmarkOptions;
            return (query['level'] == null ||
                    scenario.$1.name == query['level']) &&
                (query['seed'] == null ||
                    scenario.$2.toString() == query['seed']) &&
                (query['character'] == null ||
                    scenario.$3.id.name == query['character']);
          })
          .expand(
            (scenario) => [
              // Serial, parallel, parallel, serial in one build/process.
              for (
                var repeat = 0;
                repeat < (_benchmarkOptions['compareWarmup'] == '1' ? 4 : 1);
                repeat++
              )
                scenario,
            ],
          )
          .toList();
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
    final startupWatch = Stopwatch()..start();
    final core = GameCore(
      seed: seed,
      levelDefinition: LevelRegistry.byId(levelId),
      playerCharacter: player,
      terrainPreparation: (bindings, profiles) async {
        final delayMs =
            int.tryParse(_benchmarkOptions['terrainDelayMs'] ?? '') ?? 0;
        if (delayMs > 0) {
          await Future<void>.delayed(Duration(milliseconds: delayMs));
        }
        return prepareTerrainCandidate(bindings, profiles);
      },
    );
    final fullWarmup = _benchmarkOptions['compareWarmup'] == '1'
        ? _rows.length % 4 == 0 || _rows.length % 4 == 3
        : _benchmarkOptions['fullWarmup'] == '1';
    final controller = _benchmarkOptions['coldTerrain'] == '1'
        ? _ColdTerrainController(core: core)
        : fullWarmup
        ? _FullTerrainController(core: core)
        : GameController(core: core);
    _controller = controller;
    _game = _BenchmarkGame(
      core: core,
      fullWarmup: fullWarmup,
      coreConstructionMicros: startupWatch.elapsedMicroseconds,
      startupWatch: startupWatch,
      levelId: levelId,
      seed: seed,
      controller: controller,
      input: _benchmarkOptions['scriptedInput'] == '1'
          ? _ScriptedBenchmarkInput(controller: controller)
          : RunnerInputRouter(controller: controller),
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

// Comparison controls stay in tooling; production always uses its startup gate.
class _FullTerrainController extends GameController {
  _FullTerrainController({required super.core}) : _core = core;
  final GameCore _core;
  @override
  Future<void> prepareTerrainAhead() => _core.prepareTerrainAhead();
}

// A fixed command tape makes warmup comparisons independent of rendered frame
// count, terrain waits, and catch-up. Commands still use live controller admission.
class _ScriptedBenchmarkInput extends RunnerInputRouter {
  _ScriptedBenchmarkInput({required super.controller}) {
    for (var tick = 1; tick <= 1800; tick++) {
      controller.enqueue(MoveAxisCommand(tick: tick, axis: 1));
      controller.enqueue(AimDirCommand(tick: tick, x: 0.8, y: -0.6));
      if (tick % 32 == 1) controller.enqueue(JumpPressedCommand(tick: tick));
      for (final (slot, period, release) in [
        (AbilitySlot.primary, 48, 8),
        (AbilitySlot.projectile, 110, 17),
        (AbilitySlot.secondary, 180, 12),
        (AbilitySlot.mobility, 220, 5),
      ]) {
        if (tick % period == 1 || tick % period == release) {
          controller.enqueue(
            AbilitySlotHeldCommand(
              tick: tick,
              slot: slot,
              held: tick % period == 1,
            ),
          );
        }
      }
      if (tick % 240 == 1) controller.enqueue(SpellPressedCommand(tick: tick));
    }
  }

  @override
  void pumpHeldInputs() {}
}

class _BenchmarkGame extends RunnerFlameGame {
  _BenchmarkGame({
    required this.core,
    required this.fullWarmup,
    required this.coreConstructionMicros,
    required this.startupWatch,
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
  final bool fullWarmup;
  final int coreConstructionMicros;
  final Stopwatch startupWatch;
  int _startupMicros = 0;
  int _startupPrepared = 0;
  final LevelId levelId;
  final int seed;
  final void Function(Map<String, Object?>) complete;
  late final RunnerSemanticActionDispatcher _actions;
  final _watch = Stopwatch();
  final _geometryVersions = <int>{};
  int _frames = 0;
  int _maxEntities = 0;
  final bool _scripted = _benchmarkOptions['scriptedInput'] == '1';
  int? _firstTerrainWaitTick;
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
    startupWatch.stop();
    _startupMicros = startupWatch.elapsedMicroseconds;
    _startupPrepared = core.terrainPreparationStats?.completed ?? 0;
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
    if (_started && !_finished && !_scripted) {
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
        _firstTerrainWaitTick ??= controller.tick;
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
    if (!snapshot.gameOver &&
        (_scripted
            ? snapshot.tick < 1800 && _watch.elapsed.inSeconds < 90
            : _watch.elapsed.inSeconds < 45)) {
      return;
    }
    _finished = true;
    _watch.stop();
    _actions.cancelAll();
    controller.setPaused(true);
    final stats = core.terrainPreparationStats;
    final row = <String, Object?>{
      'level': levelId.name,
      'seed': seed,
      'character': playerCharacter.id.name,
      'startupTasksMs': loadTimings.map(
        (name, elapsed) => MapEntry(name, elapsed.inMicroseconds / 1000),
      ),
      'startupMs': _startupMicros / 1000,
      'coreConstructionMs': coreConstructionMicros / 1000,
      'startupPrepared': _startupPrepared,
      'imageCount': images.keys.length,
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
      'firstTerrainWaitTick': _firstTerrainWaitTick,
      'scriptedInput': _scripted,
      'fullWarmup': fullWarmup,
      'terrainWaitFrames': _terrainWaitFrames,
      'terrainWaitWallMs': _terrainWaitWatch.elapsedMicroseconds / 1000,
      'terrainFailures': _terrainFailures,
      'coldTerrain': _benchmarkOptions['coldTerrain'] == '1',
      'terrainDelayMs':
          int.tryParse(_benchmarkOptions['terrainDelayMs'] ?? '') ?? 0,
    };
    unawaited(Future<void>(() => complete(row)));
  }

  void _cycle(RunnerGameplayAction action, int period, int releaseAt) {
    if (_frames % period == 0) _actions.beginAction(action);
    if (_frames % period == releaseAt) _actions.releaseAction(action);
  }
}
