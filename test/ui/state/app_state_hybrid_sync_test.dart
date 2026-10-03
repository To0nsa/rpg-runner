import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/meta/meta_service.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:rpg_runner/ui/state/app/app_state.dart';
import 'package:rpg_runner/ui/state/auth/auth_api.dart';
import 'package:rpg_runner/ui/state/ownership/loadout_ownership_api.dart';
import 'package:rpg_runner/ui/state/ownership/ownership_outbox_store.dart';
import 'package:rpg_runner/ui/state/ownership/ownership_pending_command.dart';
import 'package:rpg_runner/ui/state/ownership/ownership_sync_policy.dart';
import 'package:rpg_runner/ui/state/ownership/progression_state.dart';
import 'package:rpg_runner/ui/state/run/run_start_remote_exception.dart';
import 'package:rpg_runner/ui/state/ownership/selection_state.dart';

void main() {
  test('concurrent bootstrap calls share one canonical read', () async {
    final ownership = _DelayedCanonicalOwnershipApi();
    final app = AppState(
      authApi: _StaticAuthApi.authenticated(),
      loadoutOwnershipApi: ownership,
    );
    addTearDown(app.dispose);
    ownership.holdNextRead = true;
    final first = app.bootstrap();
    await ownership.readStarted.future;
    final second = app.bootstrap(force: true);
    expect(ownership.loadCanonicalCalls, 1);
    ownership.releaseRead.complete();
    await Future.wait([first, second]);
    expect(app.isBootstrapped, isTrue);
    expect(ownership.loadCanonicalCalls, 1);
  });

  test('resume waits for an active ownership flush before loading', () async {
    final ownership = _DelayedFirstSelectionOwnershipApi();
    final app = AppState(
      authApi: _StaticAuthApi.authenticated(),
      loadoutOwnershipApi: ownership,
    );
    addTearDown(app.dispose);
    await app.bootstrap();
    await app.setRunMode(RunMode.competitive);
    final flush = app.flushOwnershipEdits(
      trigger: OwnershipFlushTrigger.manual,
    );
    await ownership.waitForFirstSelectionSend();
    final resume = app.bootstrap(force: true);
    await Future<void>.delayed(Duration.zero);
    expect(ownership.loadCanonicalCalls, 1);
    ownership.releaseFirstSelectionSend();
    await Future.wait([flush, resume]);
    expect(ownership.loadCanonicalCalls, 2);
    expect(app.selection.selectedRunMode, RunMode.competitive);
    expect(app.ownershipRevision, 1);
  });

  test('a delayed bootstrap read cannot overwrite newer ownership', () async {
    final ownership = _DelayedCanonicalOwnershipApi();
    final app = AppState(
      authApi: _StaticAuthApi.authenticated(),
      loadoutOwnershipApi: ownership,
    );
    addTearDown(app.dispose);
    await app.bootstrap();
    ownership.holdNextRead = true;
    final resume = app.bootstrap(force: true);
    await ownership.readStarted.future;
    await app.setRunMode(RunMode.competitive);
    await app.flushOwnershipEdits(trigger: OwnershipFlushTrigger.manual);
    ownership.releaseRead.complete();
    await resume;
    expect(app.ownershipRevision, 1);
    expect(app.selection.selectedRunMode, RunMode.competitive);
  });

  test('resume preserves queued selection when delivery fails', () async {
    final app = AppState(
      authApi: _StaticAuthApi.authenticated(),
      loadoutOwnershipApi: _FailingSelectionOwnershipApi(),
    );
    addTearDown(app.dispose);
    await app.bootstrap();
    await app.setRunMode(RunMode.competitive);
    await app.bootstrap(force: true);
    expect(app.selection.selectedRunMode, RunMode.competitive);
    expect(app.ownershipSyncStatus.pendingSelectionCount, 1);
  });

  test(
    'warmup waits for bootstrap and can retry a local cache failure',
    () async {
      final outbox = _FailOnceWarmupOutbox();
      final app = AppState(
        authApi: _StaticAuthApi.authenticated(),
        loadoutOwnershipApi: _RecordingOwnershipApi(),
        ownershipOutboxStore: outbox,
      );
      addTearDown(app.dispose);
      app.startWarmup();
      await Future<void>.delayed(Duration.zero);
      expect(outbox.loadCalls, 0);
      await app.bootstrap();
      app.startWarmup();
      await Future<void>.delayed(Duration.zero);
      expect(outbox.loadCalls, 1);
      app.startWarmup();
      await Future<void>.delayed(Duration.zero);
      expect(outbox.loadCalls, 2);
    },
  );

  test('disposed app ignores a pending bootstrap response', () async {
    final ownership = _DelayedCanonicalOwnershipApi()..holdNextRead = true;
    final app = AppState(
      authApi: _StaticAuthApi.authenticated(),
      loadoutOwnershipApi: ownership,
    );
    final pending = app.bootstrap();
    await ownership.readStarted.future;
    app.dispose();
    ownership.releaseRead.complete();
    await pending;
    expect(app.isBootstrapped, isFalse);
  });

  test('setRunMode updates selection optimistically before flush', () async {
    final ownershipApi = _RecordingOwnershipApi();
    final appState = AppState(
      authApi: _StaticAuthApi.authenticated(),
      loadoutOwnershipApi: ownershipApi,
    );

    await appState.bootstrap(force: true);
    expect(appState.selection.selectedRunMode, RunMode.practice);

    await appState.setRunMode(RunMode.competitive);

    expect(appState.selection.selectedRunMode, RunMode.competitive);
    expect(ownershipApi.setSelectionCalls, 0);
    expect(appState.ownershipSyncStatus.pendingSelectionCount, 1);

    await appState.flushOwnershipEdits(trigger: OwnershipFlushTrigger.manual);

    expect(ownershipApi.setSelectionCalls, 1);
    expect(appState.ownershipSyncStatus.pendingSelectionCount, 0);
  });

  test('setCharacter updates selection optimistically before flush', () async {
    final ownershipApi = _RecordingOwnershipApi();
    final appState = AppState(
      authApi: _StaticAuthApi.authenticated(),
      loadoutOwnershipApi: ownershipApi,
    );

    await appState.bootstrap(force: true);
    expect(appState.selection.selectedCharacterId, PlayerCharacterId.eloise);

    await appState.setCharacter(PlayerCharacterId.eloiseWip);

    expect(appState.selection.selectedCharacterId, PlayerCharacterId.eloiseWip);
    expect(ownershipApi.setSelectionCalls, 0);

    await appState.flushOwnershipEdits(trigger: OwnershipFlushTrigger.manual);

    expect(ownershipApi.setSelectionCalls, 1);
    expect(appState.ownershipSyncStatus.pendingSelectionCount, 0);
  });

  test('run mode + level changes coalesce to one selection command', () async {
    final ownershipApi = _RecordingOwnershipApi();
    final appState = AppState(
      authApi: _StaticAuthApi.authenticated(),
      loadoutOwnershipApi: ownershipApi,
    );

    await appState.bootstrap(force: true);

    await appState.setRunMode(RunMode.competitive);
    await appState.setLevel(LevelId.forest);

    expect(appState.selection.selectedRunMode, RunMode.competitive);
    expect(appState.selection.selectedLevelId, LevelId.forest);
    expect(appState.ownershipSyncStatus.pendingSelectionCount, 1);

    await appState.flushOwnershipEdits(trigger: OwnershipFlushTrigger.manual);

    expect(ownershipApi.setSelectionCalls, 1);
    expect(appState.selection.selectedRunMode, RunMode.competitive);
    expect(appState.selection.selectedLevelId, LevelId.forest);
  });

  test(
    'older in-flight selection response is ignored after newer change',
    () async {
      final ownershipApi = _DelayedFirstSelectionOwnershipApi();
      final appState = AppState(
        authApi: _StaticAuthApi.authenticated(),
        loadoutOwnershipApi: ownershipApi,
      );

      await appState.bootstrap(force: true);
      await appState.setRunMode(RunMode.competitive);

      final firstFlush = appState.flushOwnershipEdits(
        trigger: OwnershipFlushTrigger.manual,
      );
      await ownershipApi.waitForFirstSelectionSend();

      await appState.setLevel(LevelId.forest);
      ownershipApi.releaseFirstSelectionSend();

      await firstFlush;
      await appState.flushOwnershipEdits(trigger: OwnershipFlushTrigger.manual);

      expect(ownershipApi.setSelectionCalls, 2);
      expect(appState.selection.selectedRunMode, RunMode.competitive);
      expect(appState.selection.selectedLevelId, LevelId.forest);
      expect(appState.ownershipSyncStatus.pendingSelectionCount, 0);
    },
  );

  test(
    'setAbilitySlot coalesces rapid writes into one remote command',
    () async {
      final ownershipApi = _RecordingOwnershipApi();
      final appState = AppState(
        authApi: _StaticAuthApi.authenticated(),
        loadoutOwnershipApi: ownershipApi,
      );

      await appState.bootstrap(force: true);
      final characterId = appState.selection.selectedCharacterId;

      await appState.setAbilitySlot(
        characterId: characterId,
        slot: AbilitySlot.spell,
        abilityId: 'eloise.arcane_haste',
      );
      await appState.setAbilitySlot(
        characterId: characterId,
        slot: AbilitySlot.spell,
        abilityId: 'eloise.crystal_volley',
      );

      expect(ownershipApi.setAbilitySlotCalls, 0);
      await appState.flushOwnershipEdits(trigger: OwnershipFlushTrigger.manual);

      expect(ownershipApi.setAbilitySlotCalls, 1);
      expect(ownershipApi.lastSetAbilityId, 'eloise.crystal_volley');
    },
  );

  test('run-start sync fails closed when pending edits cannot flush', () async {
    final ownershipApi = _FailingSelectionOwnershipApi();
    final appState = AppState(
      authApi: _StaticAuthApi.authenticated(),
      loadoutOwnershipApi: ownershipApi,
    );

    await appState.bootstrap(force: true);
    await appState.setRunMode(RunMode.competitive);

    expect(
      () => appState.ensureOwnershipSyncedBeforeRunStart(),
      throwsA(isA<RunStartRemoteException>()),
    );
  });

  test('selection retry reuses the same commandId across attempts', () async {
    final ownershipApi = _RetryingSelectionOwnershipApi();
    final appState = AppState(
      authApi: _StaticAuthApi.authenticated(),
      loadoutOwnershipApi: ownershipApi,
      ownershipSyncPolicy: const OwnershipSyncPolicy(
        tierBDebounceMs: 750,
        tierCDebounceMs: 150,
        maxStalenessMs: 8000,
        retryInitialDelayMs: 0,
        retryMaxDelayMs: 0,
        retryJitterRatio: 0,
      ),
    );

    await appState.bootstrap(force: true);
    await appState.setRunMode(RunMode.competitive);

    await appState.flushOwnershipEdits(trigger: OwnershipFlushTrigger.manual);
    await appState.flushOwnershipEdits(trigger: OwnershipFlushTrigger.manual);

    expect(ownershipApi.commandIds, hasLength(2));
    expect(ownershipApi.commandIds[0], ownershipApi.commandIds[1]);
    expect(appState.ownershipSyncStatus.pendingSelectionCount, 0);
  });

  test(
    'flush prioritizes Tier C selection commands over Tier B commands',
    () async {
      final ownershipApi = _OrderingOwnershipApi();
      final appState = AppState(
        authApi: _StaticAuthApi.authenticated(),
        loadoutOwnershipApi: ownershipApi,
      );

      await appState.bootstrap(force: true);
      final characterId = appState.selection.selectedCharacterId;
      await appState.setAbilitySlot(
        characterId: characterId,
        slot: AbilitySlot.spell,
        abilityId: 'eloise.arcane_haste',
      );
      await appState.setRunMode(RunMode.competitive);

      await appState.flushOwnershipEdits(trigger: OwnershipFlushTrigger.manual);

      expect(ownershipApi.commandOrder, hasLength(2));
      expect(ownershipApi.commandOrder.first, 'setSelection');
      expect(ownershipApi.commandOrder.last, 'setAbilitySlot');
    },
  );

  test(
    'queued stale-revision command reloads canonical then reapplies draft',
    () async {
      final ownershipApi = _StaleThenAcceptAbilityOwnershipApi();
      final appState = AppState(
        authApi: _StaticAuthApi.authenticated(),
        loadoutOwnershipApi: ownershipApi,
        ownershipSyncPolicy: const OwnershipSyncPolicy(
          tierBDebounceMs: 750,
          tierCDebounceMs: 150,
          maxStalenessMs: 8000,
          retryInitialDelayMs: 0,
          retryMaxDelayMs: 0,
          retryJitterRatio: 0,
        ),
      );

      await appState.bootstrap(force: true);
      final characterId = appState.selection.selectedCharacterId;

      await appState.setAbilitySlot(
        characterId: characterId,
        slot: AbilitySlot.spell,
        abilityId: 'eloise.crystal_volley',
      );

      expect(
        appState.selection.loadoutFor(characterId).abilitySpellId,
        'eloise.crystal_volley',
      );

      await appState.flushOwnershipEdits(trigger: OwnershipFlushTrigger.manual);
      expect(appState.ownershipSyncStatus.conflictCount, 1);
      expect(ownershipApi.setAbilitySlotCalls, 2);
      expect(appState.ownershipSyncStatus.pendingCount, 0);
      expect(
        appState.selection.loadoutFor(characterId).abilitySpellId,
        'eloise.crystal_volley',
      );
    },
  );

  test('leave-level-setup barrier flushes pending selection edits', () async {
    final ownershipApi = _RecordingOwnershipApi();
    final appState = AppState(
      authApi: _StaticAuthApi.authenticated(),
      loadoutOwnershipApi: ownershipApi,
    );

    await appState.bootstrap(force: true);
    await appState.setLevel(LevelId.forest);
    expect(ownershipApi.setSelectionCalls, 0);
    expect(appState.ownershipSyncStatus.pendingSelectionCount, 1);

    await appState.ensureSelectionSyncedBeforeLeavingLevelSetup();

    expect(ownershipApi.setSelectionCalls, 1);
    expect(appState.ownershipSyncStatus.pendingSelectionCount, 0);
  });

  test(
    'does not deliver prior-account ownership work after a user switch',
    () async {
      final ownershipApi = _RecordingOwnershipApi();
      final outbox = InMemoryOwnershipOutboxStore();
      final authApi = _MutableAuthApi(userId: 'user_a', sessionId: 'session_a');
      final appState = AppState(
        authApi: authApi,
        loadoutOwnershipApi: ownershipApi,
        ownershipOutboxStore: outbox,
      );

      await appState.bootstrap(force: true);
      await appState.setRunMode(RunMode.competitive);
      authApi.setSession(userId: 'user_b', sessionId: 'session_b');

      await appState.flushOwnershipEdits(trigger: OwnershipFlushTrigger.manual);

      expect(ownershipApi.setSelectionCalls, 0);
      expect(await outbox.loadAll(ownerUserId: 'user_a'), hasLength(1));
      expect(await outbox.loadAll(ownerUserId: 'user_b'), isEmpty);
    },
  );

  test('max staleness forces delivery before next scheduled attempt', () async {
    final ownershipApi = _RecordingOwnershipApi();
    final outbox = InMemoryOwnershipOutboxStore();
    final appState = AppState(
      authApi: _StaticAuthApi.authenticated(),
      loadoutOwnershipApi: ownershipApi,
      ownershipOutboxStore: outbox,
      ownershipSyncPolicy: const OwnershipSyncPolicy(
        tierBDebounceMs: 750,
        tierCDebounceMs: 150,
        maxStalenessMs: 10,
        retryInitialDelayMs: 1000,
        retryMaxDelayMs: 1000,
        retryJitterRatio: 0,
      ),
    );

    await appState.bootstrap(force: true);
    await appState.setRunMode(RunMode.competitive);
    final pendingSelection = await outbox.loadByCoalesceKey(
      ownerUserId: 'user_1',
      coalesceKey: 'selection',
    );
    expect(pendingSelection, isNotNull);

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await outbox.replaceAll(
      commands: <OwnershipPendingCommand>[
        pendingSelection!.copyWith(
          createdAtMs: nowMs - 1000,
          updatedAtMs: nowMs - 1000,
          deliveryAttempt: OwnershipDeliveryAttempt(
            commandId: 'cmd_stale_test',
            expectedRevision: 0,
            attemptCount: 1,
            nextAttemptAtMs: nowMs + 60000,
            sentPayloadHash: 'hash',
          ),
        ),
      ],
    );

    expect(ownershipApi.setSelectionCalls, 0);
    await appState.flushOwnershipEdits(trigger: OwnershipFlushTrigger.manual);

    expect(ownershipApi.setSelectionCalls, 1);
    expect(appState.ownershipSyncStatus.pendingCount, 0);
  });

  test(
    'run-start sync fast-path skips flush when known-clean status is fresh',
    () async {
      final ownershipApi = _RecordingOwnershipApi();
      final outbox = _CountingOwnershipOutboxStore();
      final appState = AppState(
        authApi: _StaticAuthApi.authenticated(),
        loadoutOwnershipApi: ownershipApi,
        ownershipOutboxStore: outbox,
      );

      await appState.bootstrap(force: true);
      appState.startWarmup();
      await outbox.waitForLoadAllAtLeast(1);

      final loadAllCallsBeforeRunStart = outbox.loadAllCalls;
      await appState.ensureOwnershipSyncedBeforeRunStart();

      expect(outbox.loadAllCalls, loadAllCallsBeforeRunStart);
    },
  );

  test(
    'run-start sync does full path when sync-status freshness is unknown',
    () async {
      final ownershipApi = _RecordingOwnershipApi();
      final outbox = _CountingOwnershipOutboxStore();
      final appState = AppState(
        authApi: _StaticAuthApi.authenticated(),
        loadoutOwnershipApi: ownershipApi,
        ownershipOutboxStore: outbox,
      );

      await appState.bootstrap(force: true);
      expect(outbox.loadAllCalls, 0);

      await appState.ensureOwnershipSyncedBeforeRunStart();

      expect(outbox.loadAllCalls, greaterThan(0));
    },
  );
}

class _CountingOwnershipOutboxStore implements OwnershipOutboxStore {
  final InMemoryOwnershipOutboxStore _delegate = InMemoryOwnershipOutboxStore();

  int loadAllCalls = 0;

  @override
  Future<void> clear() {
    return _delegate.clear();
  }

  @override
  Future<OwnershipPendingCommand?> loadByCoalesceKey({
    required String ownerUserId,
    required String coalesceKey,
  }) {
    return _delegate.loadByCoalesceKey(
      ownerUserId: ownerUserId,
      coalesceKey: coalesceKey,
    );
  }

  @override
  Future<List<OwnershipPendingCommand>> loadAll({
    required String ownerUserId,
  }) async {
    loadAllCalls += 1;
    return _delegate.loadAll(ownerUserId: ownerUserId);
  }

  @override
  Future<void> removeByCoalesceKey({
    required String ownerUserId,
    required String coalesceKey,
  }) {
    return _delegate.removeByCoalesceKey(
      ownerUserId: ownerUserId,
      coalesceKey: coalesceKey,
    );
  }

  @override
  Future<void> replaceAll({required List<OwnershipPendingCommand> commands}) {
    return _delegate.replaceAll(commands: commands);
  }

  @override
  Future<void> upsertCoalesced({required OwnershipPendingCommand command}) {
    return _delegate.upsertCoalesced(command: command);
  }

  Future<void> waitForLoadAllAtLeast(int count) async {
    for (var i = 0; i < 40; i++) {
      if (loadAllCalls >= count) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('Timed out waiting for loadAllCalls >= $count. Actual: $loadAllCalls');
  }
}

class _RecordingOwnershipApi implements LoadoutOwnershipApi {
  int loadCanonicalCalls = 0;
  int _revision = 0;
  int setSelectionCalls = 0;
  int setAbilitySlotCalls = 0;
  AbilityKey? lastSetAbilityId;
  SelectionState _selection = SelectionState.defaults;
  final MetaService _metaService = const MetaService();

  OwnershipCanonicalState _canonical() {
    return OwnershipCanonicalState(
      profileId: 'test_profile',
      revision: _revision,
      selection: _selection,
      meta: _metaService.createNew(),
      progression: ProgressionState.initial,
    );
  }

  OwnershipCommandResult _acceptedResult() {
    _revision += 1;
    final canonical = _canonical();
    return OwnershipCommandResult(
      canonicalState: canonical,
      newRevision: canonical.revision,
      replayedFromIdempotency: false,
    );
  }

  @override
  Future<OwnershipCanonicalState> loadCanonicalState({
    required String userId,
    required String sessionId,
  }) async {
    loadCanonicalCalls += 1;
    return _canonical();
  }

  @override
  Future<OwnershipCommandResult> setSelection(
    SetSelectionCommand command,
  ) async {
    setSelectionCalls += 1;
    _selection = command.selection;
    return _acceptedResult();
  }

  @override
  Future<OwnershipCommandResult> equipGear(EquipGearCommand command) async =>
      _acceptedResult();

  @override
  Future<OwnershipCommandResult> setLoadout(SetLoadoutCommand command) async =>
      _acceptedResult();

  @override
  Future<OwnershipCommandResult> setAbilitySlot(
    SetAbilitySlotCommand command,
  ) async {
    setAbilitySlotCalls += 1;
    lastSetAbilityId = command.abilityId;
    return _acceptedResult();
  }

  @override
  Future<OwnershipCommandResult> setProjectileSpell(
    SetProjectileSpellCommand command,
  ) async => _acceptedResult();

  @override
  Future<OwnershipCommandResult> purchaseStoreOffer(
    PurchaseStoreOfferCommand command,
  ) async => _acceptedResult();

  @override
  Future<OwnershipCommandResult> refreshStore(
    RefreshStoreCommand command,
  ) async => _acceptedResult();
}

class _DelayedCanonicalOwnershipApi extends _RecordingOwnershipApi {
  bool holdNextRead = false;
  final readStarted = Completer<void>();
  final releaseRead = Completer<void>();

  @override
  Future<OwnershipCanonicalState> loadCanonicalState({
    required String userId,
    required String sessionId,
  }) async {
    final snapshot = await super.loadCanonicalState(
      userId: userId,
      sessionId: sessionId,
    );
    if (holdNextRead) {
      holdNextRead = false;
      readStarted.complete();
      await releaseRead.future;
    }
    return snapshot;
  }
}

class _FailOnceWarmupOutbox extends InMemoryOwnershipOutboxStore {
  int loadCalls = 0;

  @override
  Future<List<OwnershipPendingCommand>> loadAll({required String ownerUserId}) {
    if (++loadCalls == 1) throw StateError('local cache unavailable');
    return super.loadAll(ownerUserId: ownerUserId);
  }
}

class _FailingSelectionOwnershipApi extends _RecordingOwnershipApi {
  @override
  Future<OwnershipCommandResult> setSelection(
    SetSelectionCommand command,
  ) async {
    throw Exception('network down');
  }
}

class _RetryingSelectionOwnershipApi extends _RecordingOwnershipApi {
  final List<String> commandIds = <String>[];
  bool _failedFirstAttempt = false;

  @override
  Future<OwnershipCommandResult> setSelection(
    SetSelectionCommand command,
  ) async {
    commandIds.add(command.commandId);
    if (!_failedFirstAttempt) {
      _failedFirstAttempt = true;
      throw Exception('transient error');
    }
    return super.setSelection(command);
  }
}

class _DelayedFirstSelectionOwnershipApi extends _RecordingOwnershipApi {
  final Completer<void> _firstSelectionSendStarted = Completer<void>();
  final Completer<void> _releaseFirstSelectionSend = Completer<void>();
  bool _firstSelectionHeld = false;

  Future<void> waitForFirstSelectionSend() => _firstSelectionSendStarted.future;

  void releaseFirstSelectionSend() {
    if (!_releaseFirstSelectionSend.isCompleted) {
      _releaseFirstSelectionSend.complete();
    }
  }

  @override
  Future<OwnershipCommandResult> setSelection(
    SetSelectionCommand command,
  ) async {
    if (!_firstSelectionHeld) {
      _firstSelectionHeld = true;
      if (!_firstSelectionSendStarted.isCompleted) {
        _firstSelectionSendStarted.complete();
      }
      await _releaseFirstSelectionSend.future;
    }
    return super.setSelection(command);
  }
}

class _OrderingOwnershipApi extends _RecordingOwnershipApi {
  final List<String> commandOrder = <String>[];

  @override
  Future<OwnershipCommandResult> setSelection(
    SetSelectionCommand command,
  ) async {
    commandOrder.add('setSelection');
    return super.setSelection(command);
  }

  @override
  Future<OwnershipCommandResult> setAbilitySlot(
    SetAbilitySlotCommand command,
  ) async {
    commandOrder.add('setAbilitySlot');
    return super.setAbilitySlot(command);
  }
}

class _StaleThenAcceptAbilityOwnershipApi implements LoadoutOwnershipApi {
  int _revision = 0;
  bool _returnedStaleOnce = false;
  int setAbilitySlotCalls = 0;
  SelectionState _selection = SelectionState.defaults;
  final MetaService _metaService = const MetaService();

  OwnershipCanonicalState _canonical() {
    return OwnershipCanonicalState(
      profileId: 'test_profile',
      revision: _revision,
      selection: _selection,
      meta: _metaService.createNew(),
      progression: ProgressionState.initial,
    );
  }

  @override
  Future<OwnershipCanonicalState> loadCanonicalState({
    required String userId,
    required String sessionId,
  }) async {
    return _canonical();
  }

  @override
  Future<OwnershipCommandResult> setAbilitySlot(
    SetAbilitySlotCommand command,
  ) async {
    setAbilitySlotCalls += 1;
    final canonical = _canonical();
    if (!_returnedStaleOnce) {
      _returnedStaleOnce = true;
      _revision = canonical.revision + 1;
      return OwnershipCommandResult(
        canonicalState: _canonical(),
        newRevision: _revision,
        replayedFromIdempotency: false,
        rejectedReason: OwnershipRejectedReason.staleRevision,
      );
    }

    final currentLoadout = _selection.loadoutFor(command.characterId);
    final nextLoadout = EquippedLoadoutDef(
      mask: currentLoadout.mask,
      mainWeaponId: currentLoadout.mainWeaponId,
      offhandWeaponId: currentLoadout.offhandWeaponId,
      spellBookId: currentLoadout.spellBookId,
      projectileSlotSpellId: currentLoadout.projectileSlotSpellId,
      accessoryId: currentLoadout.accessoryId,
      abilityPrimaryId: currentLoadout.abilityPrimaryId,
      abilitySecondaryId: currentLoadout.abilitySecondaryId,
      abilityProjectileId: currentLoadout.abilityProjectileId,
      abilitySpellId: command.slot == AbilitySlot.spell
          ? command.abilityId
          : currentLoadout.abilitySpellId,
      abilityMobilityId: currentLoadout.abilityMobilityId,
      abilityJumpId: currentLoadout.abilityJumpId,
    );
    _selection = _selection.withLoadoutFor(command.characterId, nextLoadout);
    _revision += 1;
    final nextCanonical = _canonical();
    return OwnershipCommandResult(
      canonicalState: nextCanonical,
      newRevision: nextCanonical.revision,
      replayedFromIdempotency: false,
    );
  }

  @override
  Future<OwnershipCommandResult> setSelection(
    SetSelectionCommand command,
  ) async => _acceptedNoop();

  @override
  Future<OwnershipCommandResult> equipGear(EquipGearCommand command) async =>
      _acceptedNoop();

  @override
  Future<OwnershipCommandResult> setLoadout(SetLoadoutCommand command) async =>
      _acceptedNoop();

  @override
  Future<OwnershipCommandResult> setProjectileSpell(
    SetProjectileSpellCommand command,
  ) async => _acceptedNoop();

  @override
  Future<OwnershipCommandResult> purchaseStoreOffer(
    PurchaseStoreOfferCommand command,
  ) async => _acceptedNoop();

  @override
  Future<OwnershipCommandResult> refreshStore(
    RefreshStoreCommand command,
  ) async => _acceptedNoop();

  OwnershipCommandResult _acceptedNoop() {
    final canonical = _canonical();
    return OwnershipCommandResult(
      canonicalState: canonical,
      newRevision: canonical.revision,
      replayedFromIdempotency: false,
    );
  }
}

class _StaticAuthApi implements AuthApi {
  _StaticAuthApi.authenticated()
    : _session = AuthSession(
        userId: 'user_1',
        sessionId: 'session_1',
        isAnonymous: false,
        expiresAtMs: DateTime.now().millisecondsSinceEpoch + 60000,
      );

  final AuthSession _session;

  @override
  Future<AuthSession> ensureAuthenticatedSession() async => _session;

  @override
  Future<void> clearSession() async {}

  @override
  Future<AuthLinkResult> linkAuthProvider(AuthLinkProvider provider) async {
    return AuthLinkResult(
      provider: provider,
      status: AuthLinkStatus.unsupported,
      session: _session,
    );
  }

  @override
  Future<AuthSession> loadSession() async => _session;

  @override
  Future<AuthSession> reauthenticateForSensitiveOperation() =>
      ensureAuthenticatedSession();
}

class _MutableAuthApi implements AuthApi {
  _MutableAuthApi({required String userId, required String sessionId})
    : _session = _sessionFor(userId: userId, sessionId: sessionId);

  AuthSession _session;

  void setSession({required String userId, required String sessionId}) {
    _session = _sessionFor(userId: userId, sessionId: sessionId);
  }

  @override
  Future<void> clearSession() async {}

  @override
  Future<AuthSession> ensureAuthenticatedSession() async => _session;

  @override
  Future<AuthLinkResult> linkAuthProvider(AuthLinkProvider provider) async {
    return AuthLinkResult(
      provider: provider,
      status: AuthLinkStatus.alreadyLinked,
      session: _session,
    );
  }

  @override
  Future<AuthSession> loadSession() async => _session;

  @override
  Future<AuthSession> reauthenticateForSensitiveOperation() =>
      ensureAuthenticatedSession();
}

AuthSession _sessionFor({required String userId, required String sessionId}) {
  return AuthSession(
    userId: userId,
    sessionId: sessionId,
    isAnonymous: false,
    expiresAtMs: 0,
    linkedProviders: const <AuthLinkProvider>{AuthLinkProvider.playGames},
  );
}
