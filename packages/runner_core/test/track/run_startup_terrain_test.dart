import 'dart:async';

import 'package:runner_core/commands/command.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/track/staged_terrain_preparer.dart';
import 'package:runner_core/track/staged_terrain_stream_candidate.dart';
import 'package:test/test.dart';

void main() {
  test('startup overlaps native jobs but waits for all eight states', () async {
    const lanes = bool.fromEnvironment('dart.library.js_interop') ? 1 : 2;
    final firstBatch = Completer<void>();
    final tail = Completer<void>();
    final started = Completer<void>();
    final tailStarted = Completer<void>();
    var calls = 0;
    var ready = false;
    final core = _core((bindings, profiles) async {
      calls++;
      if (calls == lanes) started.complete();
      if (calls == lanes + 1) tailStarted.complete();
      if (calls <= lanes) {
        await firstBatch.future;
      } else {
        await tail.future;
      }
      return const StagedTerrainStreamCandidateBuilder().buildFromBindings(
        bindings: bindings,
        geometryVersion: 0,
        groundEnemyProfiles: profiles,
      );
    });
    addTearDown(core.stopTerrainPreparation);
    final pending = core.prepareTerrainForRun().then((_) => ready = true);
    await started.future;
    expect(calls, lanes);
    expect(ready, isFalse);
    firstBatch.complete();
    await tailStarted.future;
    expect(ready, isFalse);
    tail.complete();
    await pending;
    expect(core.tick, 0);
    expect(core.terrainPreparationStats!.completed, 8);
    expect(core.terrainPreparationStats!.ready, 8);
  });

  test(
    'parallel failure drains its sibling and rejects late publication',
    () async {
      final first = Completer<void>();
      final second = Completer<void>();
      final started = Completer<void>();
      var calls = 0;
      var settled = false;
      final core = _core((bindings, profiles) async {
        calls++;
        final ordinal = calls;
        if (calls == 2) started.complete();
        await (ordinal == 1 ? first.future : second.future);
        return const StagedTerrainStreamCandidateBuilder().buildFromBindings(
          bindings: bindings,
          geometryVersion: 0,
          groundEnemyProfiles: profiles,
        );
      });
      addTearDown(core.stopTerrainPreparation);
      final checked = expectLater(
        core.prepareTerrainForRun(),
        throwsStateError,
      ).then((_) => settled = true);
      await started.future;
      first.completeError(StateError('first worker failed'));
      await Future<void>.delayed(Duration.zero);
      expect(settled, isFalse);
      second.complete();
      await checked;
      expect(calls, 2);
      expect(core.terrainPreparationStats!.ready, 0);
      expect(core.terrainPreparationStats!.discarded, 1);
    },
    skip: const bool.fromEnvironment('dart.library.js_interop'),
  );

  test('failed startup warmup is reported before play', () async {
    final core = _core((_, _) async => throw StateError('broken worker'));
    addTearDown(core.stopTerrainPreparation);
    await expectLater(
      core.prepareTerrainForRun(),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('broken worker'),
        ),
      ),
    );
    expect(core.tick, 0);
  });

  test('closing during startup cannot restart speculative work', () async {
    final entered = Completer<void>();
    final finish = Completer<void>();
    var calls = 0;
    final core = _core((bindings, profiles) async {
      calls++;
      if (!entered.isCompleted) entered.complete();
      await finish.future;
      return const StagedTerrainStreamCandidateBuilder().buildFromBindings(
        bindings: bindings,
        geometryVersion: 0,
        groundEnemyProfiles: profiles,
      );
    });
    final pending = core.prepareTerrainForRun();
    await entered.future;
    core.stopTerrainPreparation();
    finish.complete();
    await pending;
    await Future<void>.delayed(Duration.zero);
    expect(
      calls,
      const bool.fromEnvironment('dart.library.js_interop') ? 1 : 2,
    );
    expect(core.terrainPreparationStats, isNull);
    expect(core.tick, 0);
  });

  test(
    'startup warmup preserves seeded gameplay through terrain transitions',
    () async {
      final cold = _core(prepareTerrainCandidate);
      final live = _core(prepareTerrainCandidate);
      addTearDown(live.stopTerrainPreparation);
      await live.prepareTerrainForRun();
      var versions = <int>{};
      for (var tick = 1; tick <= 600 && !cold.gameOver; tick++) {
        await live.prepareNextTick();
        final commands = <Command>[MoveAxisCommand(tick: tick, axis: 1)];
        cold.applyCommands(commands);
        live.applyCommands(commands);
        cold.stepOneTick();
        live.stepOneTick();
        final a = cold.buildSnapshot();
        final b = live.buildSnapshot();
        expect(b.tick, a.tick);
        expect(b.distance, a.distance);
        expect(b.playerEntity?.pos, a.playerEntity?.pos);
        expect(b.gameOver, a.gameOver);
        final terrain = b.stagedTerrainRenderSnapshot!;
        versions.add(terrain.geometryVersion);
        expect(
          terrain.geometryVersion,
          a.stagedTerrainRenderSnapshot!.geometryVersion,
        );
        expect(
          terrain.edges.map((e) => e.id),
          a.stagedTerrainRenderSnapshot!.edges.map((e) => e.id),
        );
        expect(
          live.drainEvents().map((e) => e.runtimeType),
          cold.drainEvents().map((e) => e.runtimeType),
        );
      }
      expect(versions.length, greaterThan(2));
      expect(live.terrainPreparationStats!.lastError, isNull);
    },
  );
}

GameCore _core(TerrainCandidatePreparation prepare) => GameCore(
  seed: 42,
  levelDefinition: LevelRegistry.byId(LevelId.field)
      .copyWith(noEnemyChunks: 9999),
  playerCharacter: PlayerCharacterRegistry.eloise,
  terrainPreparation: prepare,
);
