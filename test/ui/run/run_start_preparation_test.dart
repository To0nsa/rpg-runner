import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:rpg_runner/ui/app/ui_routes.dart';
import 'package:rpg_runner/ui/run/run_start_preparation.dart';
import 'package:rpg_runner/ui/state/app/app_state.dart';
import 'package:rpg_runner/ui/state/ownership/selection_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('duplicate starts do not issue another ticket request', () async {
    final app = _App();
    final pending = Completer<RunStartDescriptor>();
    app.prepareResult = pending.future;
    final preparation = RunStartPreparation(
      appState: app,
      request: const RunStartBootstrapArgs(),
    );
    addTearDown(app.dispose);
    addTearDown(preparation.dispose);
    final first = preparation.prepare();
    expect(preparation.inFlight, isTrue);
    expect(await preparation.prepare(), isNull);
    pending.complete(_descriptor);
    expect(await first, same(_descriptor));
    expect(app.prepareCalls, 1);
    expect(preparation.inFlight, isFalse);
  });

  test('disposal during selection prevents ticket creation', () async {
    final app = _App();
    final selection = Completer<void>();
    app.modeResult = selection.future;
    final preparation = RunStartPreparation(
      appState: app,
      request: const RunStartBootstrapArgs(
        selectMode: RunMode.competitive,
        ghostEntryId: 'ghost',
      ),
    );
    addTearDown(app.dispose);
    final pending = preparation.prepare();
    preparation.dispose();
    selection.complete();
    expect(await pending, isNull);
    expect(app.prepareCalls, 0);
  });

  test('disposal suppresses a late descriptor', () async {
    final app = _App();
    final result = Completer<RunStartDescriptor>();
    app.prepareResult = result.future;
    final preparation = RunStartPreparation(
      appState: app,
      request: const RunStartBootstrapArgs(),
    );
    addTearDown(app.dispose);
    final pending = preparation.prepare();
    preparation.dispose();
    result.complete(_descriptor);
    expect(await pending, isNull);
  });

  test(
    'retry clears failure and preserves restart and ghost constraints',
    () async {
      final app = _App();
      app.fail = true;
      final preparation = RunStartPreparation(
        appState: app,
        request: const RunStartBootstrapArgs(
          expectedMode: RunMode.competitive,
          expectedLevelId: LevelId.field,
          ghostEntryId: 'ghost',
        ),
      );
      addTearDown(app.dispose);
      addTearDown(preparation.dispose);
      expect(await preparation.prepare(), isNull);
      expect(preparation.errorMessage, isNotNull);
      app.fail = false;
      expect(await preparation.prepare(), same(_descriptor));
      expect(preparation.error, isNull);
      expect(app.expectedMode, RunMode.competitive);
      expect(app.expectedLevel, LevelId.field);
      expect(app.ghostId, 'ghost');
    },
  );
}

class _App extends ChangeNotifier implements AppState {
  @override
  SelectionState get selection => SelectionState.defaults;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  Future<RunStartDescriptor>? prepareResult;
  Future<void>? modeResult;
  int prepareCalls = 0;
  bool fail = false;
  RunMode? expectedMode;
  LevelId? expectedLevel;
  String? ghostId;

  @override
  Future<void> setRunMode(RunMode mode) async => await modeResult;

  @override
  Future<RunStartDescriptor> prepareRunStartDescriptor({
    RunMode? expectedMode,
    LevelId? expectedLevelId,
    String? ghostEntryId,
  }) async {
    prepareCalls++;
    this.expectedMode = expectedMode;
    expectedLevel = expectedLevelId;
    ghostId = ghostEntryId;
    if (fail) throw StateError('offline');
    return prepareResult ?? _descriptor;
  }
}

const _descriptor = RunStartDescriptor(
  runSessionId: 'preflight-test',
  runId: 1,
  seed: 42,
  tickHz: 60,
  levelId: LevelId.field,
  playerCharacterId: PlayerCharacterId.eloise,
  runMode: RunMode.practice,
  equippedLoadout: EquippedLoadoutDef(),
);
