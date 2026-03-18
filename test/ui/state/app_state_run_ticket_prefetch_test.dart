import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/meta/meta_service.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:run_protocol/board_key.dart';
import 'package:run_protocol/run_ticket.dart';
import 'package:run_protocol/submission_status.dart';
import 'package:rpg_runner/ui/state/app_state.dart';
import 'package:rpg_runner/ui/state/auth_api.dart';
import 'package:rpg_runner/ui/state/loadout_ownership_api.dart';
import 'package:rpg_runner/ui/state/progression_state.dart';
import 'package:rpg_runner/ui/state/run_session_api.dart';
import 'package:rpg_runner/ui/state/selection_state.dart';

void main() {
  test('prefetch concurrent requests issue only one run-session call', () async {
    final runSessionApi = _RecordingRunSessionApi(holdResponses: true);
    final appState = AppState(
      authApi: _StaticAuthApi.authenticated(),
      loadoutOwnershipApi: _NoopOwnershipApi(),
      runSessionApi: runSessionApi,
    );

    final first = appState.startRunTicketPrefetchForCurrentSelection();
    final second = appState.startRunTicketPrefetchForCurrentSelection();

    await Future<void>.delayed(Duration.zero);
    expect(runSessionApi.createRunSessionCalls, 1);

    runSessionApi.completePending();
    await Future.wait(<Future<void>>[first, second]);
    expect(runSessionApi.createRunSessionCalls, 1);
  });

  test('prefetch request budget suppresses immediate duplicate request', () async {
    final runSessionApi = _RecordingRunSessionApi();
    final appState = AppState(
      authApi: _StaticAuthApi.authenticated(),
      loadoutOwnershipApi: _NoopOwnershipApi(),
      runSessionApi: runSessionApi,
    );

    await appState.startRunTicketPrefetchForCurrentSelection();
    await appState.startRunTicketPrefetchForCurrentSelection();

    expect(runSessionApi.createRunSessionCalls, 1);
  });

  test('weekly prefetch normalizes level to featured weekly level', () async {
    final runSessionApi = _RecordingRunSessionApi();
    final appState = AppState(
      authApi: _StaticAuthApi.authenticated(),
      loadoutOwnershipApi: _NoopOwnershipApi(),
      runSessionApi: runSessionApi,
    );

    await appState.startRunTicketPrefetchFor(
      mode: RunMode.weekly,
      levelId: LevelId.forest,
    );

    expect(runSessionApi.createRunSessionCalls, 1);
    expect(runSessionApi.requestedModes.single, RunMode.weekly);
    expect(runSessionApi.requestedLevels.single, LevelId.field);
  });

  test('prefetch is a no-op when run-session API is unavailable', () async {
    final appState = AppState(
      authApi: _StaticAuthApi.authenticated(),
      loadoutOwnershipApi: _NoopOwnershipApi(),
    );

    await appState.startRunTicketPrefetchForCurrentSelection();
  });

  test('prepareRunStartDescriptor reuses prefetched ticket on exact match', () async {
    final runSessionApi = _RecordingRunSessionApi(
      ticketBuilder: (request) {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        return _ticketForRequest(
          request: request,
          runSessionId: request.callIndex == 1
              ? 'prefetched_run_session'
              : 'fallback_run_session',
          expiresAtMs: nowMs + 60000,
        );
      },
    );
    final appState = AppState(
      authApi: _StaticAuthApi.authenticated(),
      loadoutOwnershipApi: _NoopOwnershipApi(),
      runSessionApi: runSessionApi,
    );

    await appState.startRunTicketPrefetchForCurrentSelection();
    final descriptor = await appState.prepareRunStartDescriptor();

    expect(runSessionApi.createRunSessionCalls, 1);
    expect(descriptor.runSessionId, 'prefetched_run_session');
  });

  test('prefetched ticket is consumed once then falls back to remote', () async {
    final runSessionApi = _RecordingRunSessionApi(
      ticketBuilder: (request) {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        return _ticketForRequest(
          request: request,
          runSessionId: request.callIndex == 1
              ? 'prefetched_once'
              : 'remote_after_consume',
          expiresAtMs: nowMs + 60000,
        );
      },
    );
    final appState = AppState(
      authApi: _StaticAuthApi.authenticated(),
      loadoutOwnershipApi: _NoopOwnershipApi(),
      runSessionApi: runSessionApi,
    );

    await appState.startRunTicketPrefetchForCurrentSelection();
    final first = await appState.prepareRunStartDescriptor();
    final second = await appState.prepareRunStartDescriptor();

    expect(first.runSessionId, 'prefetched_once');
    expect(second.runSessionId, 'remote_after_consume');
    expect(runSessionApi.createRunSessionCalls, 2);
  });

  test('expired prefetched ticket falls back to remote createRunSession', () async {
    final runSessionApi = _RecordingRunSessionApi(
      ticketBuilder: (request) {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        if (request.callIndex == 1) {
          return _ticketForRequest(
            request: request,
            runSessionId: 'expired_prefetch',
            expiresAtMs: nowMs + 1000,
          );
        }
        return _ticketForRequest(
          request: request,
          runSessionId: 'remote_fallback',
          expiresAtMs: nowMs + 60000,
        );
      },
    );
    final appState = AppState(
      authApi: _StaticAuthApi.authenticated(),
      loadoutOwnershipApi: _NoopOwnershipApi(),
      runSessionApi: runSessionApi,
    );

    await appState.startRunTicketPrefetchForCurrentSelection();
    final descriptor = await appState.prepareRunStartDescriptor();

    expect(descriptor.runSessionId, 'remote_fallback');
    expect(runSessionApi.createRunSessionCalls, 2);
  });

  test('prefetch key mismatch falls back to remote createRunSession', () async {
    final runSessionApi = _RecordingRunSessionApi(
      ticketBuilder: (request) {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        if (request.callIndex == 1) {
          final ticket = _ticketForRequest(
            request: request,
            runSessionId: 'mismatch_prefetch',
            expiresAtMs: nowMs + 60000,
          );
          return RunTicket(
            runSessionId: ticket.runSessionId,
            uid: ticket.uid,
            mode: ticket.mode,
            seed: ticket.seed,
            tickHz: ticket.tickHz,
            gameCompatVersion: ticket.gameCompatVersion,
            levelId: ticket.levelId,
            playerCharacterId: ticket.playerCharacterId,
            loadoutSnapshot: ticket.loadoutSnapshot,
            loadoutDigest: 'intentionally_wrong_digest',
            issuedAtMs: ticket.issuedAtMs,
            expiresAtMs: ticket.expiresAtMs,
            singleUseNonce: ticket.singleUseNonce,
            boardId: ticket.boardId,
            boardKey: ticket.boardKey,
            rulesetVersion: ticket.rulesetVersion,
            scoreVersion: ticket.scoreVersion,
            ghostVersion: ticket.ghostVersion,
          );
        }
        return _ticketForRequest(
          request: request,
          runSessionId: 'remote_after_mismatch',
          expiresAtMs: nowMs + 60000,
        );
      },
    );
    final appState = AppState(
      authApi: _StaticAuthApi.authenticated(),
      loadoutOwnershipApi: _NoopOwnershipApi(),
      runSessionApi: runSessionApi,
    );

    await appState.startRunTicketPrefetchForCurrentSelection();
    final descriptor = await appState.prepareRunStartDescriptor();

    expect(descriptor.runSessionId, 'remote_after_mismatch');
    expect(runSessionApi.createRunSessionCalls, 2);
  });

  test('restart path does not consume prefetched ticket', () async {
    final runSessionApi = _RecordingRunSessionApi(
      ticketBuilder: (request) {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        return _ticketForRequest(
          request: request,
          runSessionId: request.callIndex == 1
              ? 'prefetched_for_restart'
              : 'restart_remote_ticket',
          expiresAtMs: nowMs + 60000,
        );
      },
    );
    final appState = AppState(
      authApi: _StaticAuthApi.authenticated(),
      loadoutOwnershipApi: _NoopOwnershipApi(),
      runSessionApi: runSessionApi,
    );

    await appState.startRunTicketPrefetchForCurrentSelection();
    final descriptor = await appState.prepareRunStartDescriptor(
      expectedMode: RunMode.practice,
      expectedLevelId: LevelId.field,
    );

    expect(descriptor.runSessionId, 'restart_remote_ticket');
    expect(runSessionApi.createRunSessionCalls, 2);
  });

  test('prefetch cache is invalidated when canonical state is re-applied', () async {
    final runSessionApi = _RecordingRunSessionApi(
      ticketBuilder: (request) {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        return _ticketForRequest(
          request: request,
          runSessionId: request.callIndex == 1
              ? 'prefetched_before_bootstrap'
              : 'remote_after_bootstrap',
          expiresAtMs: nowMs + 60000,
        );
      },
    );
    final appState = AppState(
      authApi: _StaticAuthApi.authenticated(),
      loadoutOwnershipApi: _NoopOwnershipApi(),
      runSessionApi: runSessionApi,
    );

    await appState.startRunTicketPrefetchForCurrentSelection();
    await appState.bootstrap(force: true);
    final descriptor = await appState.prepareRunStartDescriptor();

    expect(descriptor.runSessionId, 'remote_after_bootstrap');
    expect(runSessionApi.createRunSessionCalls, 2);
  });

  test('prefetch cache is invalidated on auth session transition', () async {
    final authApi = _MutableAuthApi.initialUser('user_1', 'session_1');
    final runSessionApi = _RecordingRunSessionApi(
      ticketBuilder: (request) {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        return _ticketForRequest(
          request: request,
          runSessionId: 'ticket_${request.userId}_${request.callIndex}',
          expiresAtMs: nowMs + 60000,
        );
      },
    );
    final appState = AppState(
      authApi: authApi,
      loadoutOwnershipApi: _NoopOwnershipApi(),
      runSessionApi: runSessionApi,
    );

    await appState.startRunTicketPrefetchForCurrentSelection();
    authApi.setUser('user_2', 'session_2');
    final descriptor = await appState.prepareRunStartDescriptor();

    expect(descriptor.runSessionId, 'ticket_user_2_2');
    expect(runSessionApi.createRunSessionCalls, 2);
  });

  test('prefetch LRU evicts oldest key beyond max entries', () async {
    final runSessionApi = _RecordingRunSessionApi();
    final appState = AppState(
      authApi: _StaticAuthApi.authenticated(),
      loadoutOwnershipApi: _NoopOwnershipApi(),
      runSessionApi: runSessionApi,
    );

    await appState.startRunTicketPrefetchFor(
      mode: RunMode.practice,
      levelId: LevelId.field,
    );
    await appState.startRunTicketPrefetchFor(
      mode: RunMode.practice,
      levelId: LevelId.forest,
    );
    await appState.startRunTicketPrefetchFor(
      mode: RunMode.competitive,
      levelId: LevelId.field,
    );
    await appState.startRunTicketPrefetchFor(
      mode: RunMode.competitive,
      levelId: LevelId.forest,
    );
    await appState.startRunTicketPrefetchFor(
      mode: RunMode.weekly,
      levelId: LevelId.forest,
    );

    await appState.startRunTicketPrefetchFor(
      mode: RunMode.practice,
      levelId: LevelId.field,
    );

    expect(runSessionApi.createRunSessionCalls, 6);
  });

  test('startWarmup prefetches current and weekly combinations', () async {
    final runSessionApi = _RecordingRunSessionApi();
    final appState = AppState(
      authApi: _StaticAuthApi.authenticated(),
      loadoutOwnershipApi: _NoopOwnershipApi(),
      runSessionApi: runSessionApi,
    );

    appState.startWarmup();
    await _waitForCalls(runSessionApi, minimumCalls: 2);

    expect(runSessionApi.requestedModes, contains(RunMode.practice));
    expect(runSessionApi.requestedModes, contains(RunMode.weekly));
    expect(runSessionApi.requestedLevels, contains(LevelId.field));
  });

  test('startWarmup is idempotent for prefetch triggers', () async {
    final runSessionApi = _RecordingRunSessionApi();
    final appState = AppState(
      authApi: _StaticAuthApi.authenticated(),
      loadoutOwnershipApi: _NoopOwnershipApi(),
      runSessionApi: runSessionApi,
    );

    appState.startWarmup();
    await _waitForCalls(runSessionApi, minimumCalls: 2);
    final callsAfterFirstWarmup = runSessionApi.createRunSessionCalls;

    appState.startWarmup();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(runSessionApi.createRunSessionCalls, callsAfterFirstWarmup);
  });
}

class _RecordingRunSessionApi implements RunSessionApi {
  _RecordingRunSessionApi({
    this.holdResponses = false,
    this.ticketBuilder,
  });

  final bool holdResponses;
  final RunTicket Function(_RunSessionRequest request)? ticketBuilder;
  int createRunSessionCalls = 0;
  final List<RunMode> requestedModes = <RunMode>[];
  final List<LevelId> requestedLevels = <LevelId>[];
  Completer<RunTicket>? _pendingTicket;

  @override
  Future<RunTicket> createRunSession({
    required String userId,
    required String sessionId,
    required RunMode mode,
    required LevelId levelId,
    required String gameCompatVersion,
  }) {
    createRunSessionCalls += 1;
    requestedModes.add(mode);
    requestedLevels.add(levelId);
    if (holdResponses) {
      _pendingTicket ??= Completer<RunTicket>();
      return _pendingTicket!.future;
    }
    final request = _RunSessionRequest(
      callIndex: createRunSessionCalls,
      userId: userId,
      mode: mode,
      levelId: levelId,
      gameCompatVersion: gameCompatVersion,
    );
    final customTicket = ticketBuilder?.call(request);
    if (customTicket != null) {
      return Future<RunTicket>.value(customTicket);
    }
    return Future<RunTicket>.value(
      _ticketForRequest(
        request: request,
        runSessionId: 'run_session_${request.callIndex}',
        expiresAtMs: DateTime.now().millisecondsSinceEpoch + 60000,
      ),
    );
  }

  void completePending() {
    final pending = _pendingTicket;
    if (pending == null || pending.isCompleted) {
      return;
    }
    pending.complete(
      _ticketForRequest(
        request: _RunSessionRequest(
          callIndex: createRunSessionCalls,
          userId: 'user_1',
          mode: requestedModes.last,
          levelId: requestedLevels.last,
          gameCompatVersion: '2026.03.0',
        ),
        runSessionId: 'run_session_$createRunSessionCalls',
        expiresAtMs: DateTime.now().millisecondsSinceEpoch + 60000,
      ),
    );
  }

  @override
  Future<RunUploadGrant> createUploadGrant({
    required String userId,
    required String sessionId,
    required String runSessionId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<SubmissionStatus> finalizeUpload({
    required String userId,
    required String sessionId,
    required String runSessionId,
    required String canonicalSha256,
    required int contentLengthBytes,
    String? contentType,
    String? objectPath,
    Map<String, Object?>? provisionalSummary,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<SubmissionStatus> loadSubmissionStatus({
    required String userId,
    required String sessionId,
    required String runSessionId,
  }) {
    throw UnimplementedError();
  }
}

class _NoopOwnershipApi implements LoadoutOwnershipApi {
  int _revision = 0;
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

  OwnershipCommandResult _accepted() {
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
    return _canonical();
  }

  @override
  Future<OwnershipCommandResult> setSelection(SetSelectionCommand command) async {
    _selection = command.selection;
    return _accepted();
  }

  @override
  Future<OwnershipCommandResult> resetOwnership(
    ResetOwnershipCommand command,
  ) async => _accepted();

  @override
  Future<OwnershipCommandResult> equipGear(EquipGearCommand command) async =>
      _accepted();

  @override
  Future<OwnershipCommandResult> setLoadout(SetLoadoutCommand command) async =>
      _accepted();

  @override
  Future<OwnershipCommandResult> setAbilitySlot(
    SetAbilitySlotCommand command,
  ) async => _accepted();

  @override
  Future<OwnershipCommandResult> setProjectileSpell(
    SetProjectileSpellCommand command,
  ) async => _accepted();

  @override
  Future<OwnershipCommandResult> learnProjectileSpell(
    LearnProjectileSpellCommand command,
  ) async => _accepted();

  @override
  Future<OwnershipCommandResult> learnSpellAbility(
    LearnSpellAbilityCommand command,
  ) async => _accepted();

  @override
  Future<OwnershipCommandResult> unlockGear(UnlockGearCommand command) async =>
      _accepted();

  @override
  Future<OwnershipCommandResult> awardRunGold(
    AwardRunGoldCommand command,
  ) async => _accepted();

  @override
  Future<OwnershipCommandResult> purchaseStoreOffer(
    PurchaseStoreOfferCommand command,
  ) async => _accepted();

  @override
  Future<OwnershipCommandResult> refreshStore(
    RefreshStoreCommand command,
  ) async => _accepted();
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
}

class _MutableAuthApi implements AuthApi {
  _MutableAuthApi.initialUser(String userId, String sessionId)
    : _session = AuthSession(
        userId: userId,
        sessionId: sessionId,
        isAnonymous: false,
        expiresAtMs: DateTime.now().millisecondsSinceEpoch + 60000,
      );

  AuthSession _session;

  void setUser(String userId, String sessionId) {
    _session = AuthSession(
      userId: userId,
      sessionId: sessionId,
      isAnonymous: false,
      expiresAtMs: DateTime.now().millisecondsSinceEpoch + 60000,
    );
  }

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
}

class _RunSessionRequest {
  const _RunSessionRequest({
    required this.callIndex,
    required this.userId,
    required this.mode,
    required this.levelId,
    required this.gameCompatVersion,
  });

  final int callIndex;
  final String userId;
  final RunMode mode;
  final LevelId levelId;
  final String gameCompatVersion;
}

RunTicket _ticketForRequest({
  required _RunSessionRequest request,
  required String runSessionId,
  required int expiresAtMs,
}) {
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  final loadout = SelectionState.defaults.loadoutFor(PlayerCharacterId.eloise);
  final loadoutSnapshot = <String, Object?>{
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
  if (!request.mode.requiresBoard) {
    return RunTicket(
      runSessionId: runSessionId,
      uid: request.userId,
      mode: request.mode,
      seed: 12345 + request.callIndex,
      tickHz: 60,
      gameCompatVersion: request.gameCompatVersion,
      levelId: request.levelId.name,
      playerCharacterId: PlayerCharacterId.eloise.name,
      loadoutSnapshot: loadoutSnapshot,
      loadoutDigest: _digestForLoadout(loadout),
      issuedAtMs: nowMs,
      expiresAtMs: expiresAtMs,
      singleUseNonce: 'nonce_${request.callIndex}',
    );
  }
  return RunTicket(
    runSessionId: runSessionId,
    uid: request.userId,
    mode: request.mode,
    boardId: 'board_${request.mode.name}_${request.levelId.name}',
    boardKey: BoardKey(
      mode: request.mode,
      levelId: request.levelId.name,
      windowId: request.mode == RunMode.weekly ? '2026-W11' : '2026-03',
      rulesetVersion: 'rules-v1',
      scoreVersion: 'score-v1',
    ),
    seed: 12345 + request.callIndex,
    tickHz: 60,
    gameCompatVersion: request.gameCompatVersion,
    rulesetVersion: 'rules-v1',
    scoreVersion: 'score-v1',
    ghostVersion: 'ghost-v1',
    levelId: request.levelId.name,
    playerCharacterId: PlayerCharacterId.eloise.name,
    loadoutSnapshot: loadoutSnapshot,
    loadoutDigest: _digestForLoadout(loadout),
    issuedAtMs: nowMs,
    expiresAtMs: expiresAtMs,
    singleUseNonce: 'nonce_${request.callIndex}',
  );
}

String _digestForLoadout(EquippedLoadoutDef loadout) {
  final canonical = <String>[
    loadout.mask.toString(),
    loadout.mainWeaponId.name,
    loadout.offhandWeaponId.name,
    loadout.spellBookId.name,
    loadout.projectileSlotSpellId.name,
    loadout.accessoryId.name,
    loadout.abilityPrimaryId,
    loadout.abilitySecondaryId,
    loadout.abilityProjectileId,
    loadout.abilitySpellId,
    loadout.abilityMobilityId,
    loadout.abilityJumpId,
  ].join('|');
  return crypto.sha256.convert(utf8.encode(canonical)).toString();
}

Future<void> _waitForCalls(
  _RecordingRunSessionApi runSessionApi, {
  required int minimumCalls,
}) async {
  for (var i = 0; i < 40; i++) {
    if (runSessionApi.createRunSessionCalls >= minimumCalls) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail(
    'Timed out waiting for run-session calls >= $minimumCalls '
    '(actual: ${runSessionApi.createRunSessionCalls}).',
  );
}
