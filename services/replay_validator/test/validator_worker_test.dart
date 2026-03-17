import 'dart:convert';

import 'package:run_protocol/replay_blob.dart';
import 'package:run_protocol/replay_digest.dart';
import 'package:run_protocol/run_mode.dart';
import 'package:run_protocol/run_ticket.dart';
import 'package:run_protocol/validated_run.dart';
import 'package:test/test.dart';

import 'package:replay_validator/src/board_repository.dart';
import 'package:replay_validator/src/ghost_publisher.dart';
import 'package:replay_validator/src/leaderboard_projector.dart';
import 'package:replay_validator/src/metrics.dart';
import 'package:replay_validator/src/replay_loader.dart';
import 'package:replay_validator/src/reward_settlement_writer.dart';
import 'package:replay_validator/src/run_session_repository.dart';
import 'package:replay_validator/src/validator_worker.dart';

void main() {
  test('distanceUnitsToMeters converts world units to meters', () {
    expect(distanceUnitsToMeters(0), 0);
    expect(distanceUnitsToMeters(49.9), 0);
    expect(distanceUnitsToMeters(50), 1);
    expect(distanceUnitsToMeters(99.9), 1);
    expect(distanceUnitsToMeters(149.9), 2);
  });

  test('accepted practice replay marks terminal validated and writes reward', () async {
    final replayBlob = ReplayBlobV1.withComputedDigest(
      runSessionId: 'run_accepted',
      tickHz: 60,
      seed: 1234,
      levelId: 'field',
      playerCharacterId: 'eloise',
      loadoutSnapshot: _defaultLoadoutSnapshot(),
      totalTicks: 0,
      commandStream: const <ReplayCommandFrameV1>[],
    );
    final replayBytes = utf8.encode(jsonEncode(replayBlob.toJson()));
    final session = _session(
      runSessionId: replayBlob.runSessionId,
      mode: RunMode.practice,
      seed: replayBlob.seed,
      digest: replayBlob.canonicalSha256,
      contentLengthBytes: replayBytes.length,
      validationAttempt: 1,
    );
    final repo = _FakeRunSessionRepository(
      leaseResult: RunSessionLeaseAcquireResult(
        status: RunSessionLeaseStatus.acquired,
        session: session,
      ),
    );
    final loader = _FakeReplayLoader(
      bytesByRunSession: <String, List<int>>{
        replayBlob.runSessionId: replayBytes,
      },
    );
    final rewards = _FakeRewardGrantWriter();
    final leaderboard = _FakeLeaderboardProjector();
    final ghosts = _FakeGhostPublisher();
    final metrics = _FakeValidatorMetrics();
    final worker = DeterministicValidatorWorker(
      replayLoader: loader,
      boardRepository: _FakeBoardRepository(),
      runSessionRepository: repo,
      leaderboardProjector: leaderboard,
      rewardGrantWriter: rewards,
      ghostPublisher: ghosts,
      metrics: metrics,
      clockMs: () => 10_000,
    );

    final result = await worker.validateRunSession(
      runSessionId: replayBlob.runSessionId,
    );

    expect(result.status, ValidationDispatchStatus.accepted);
    expect(repo.persistedValidatedRuns, hasLength(1));
    expect(repo.persistedValidatedRuns.single.accepted, isTrue);
    expect(rewards.validatedRunSessionIds, <String>[replayBlob.runSessionId]);
    expect(rewards.revokedSettlements, isEmpty);
    expect(leaderboard.runSessionIds, isEmpty);
    expect(ghosts.runSessionIds, isEmpty);
    expect(repo.terminalWrites, hasLength(1));
    expect(
      repo.terminalWrites.single.terminalState,
      RunSessionTerminalState.validated,
    );
    expect(metrics.records.last.status, ValidationDispatchStatus.accepted.name);
  });

  test('invalid replay digest is rejected and terminalized', () async {
    final validBlob = ReplayBlobV1.withComputedDigest(
      runSessionId: 'run_bad_digest',
      tickHz: 60,
      seed: 77,
      levelId: 'field',
      playerCharacterId: 'eloise',
      loadoutSnapshot: _defaultLoadoutSnapshot(),
      totalTicks: 0,
      commandStream: const <ReplayCommandFrameV1>[],
    );
    final tampered = <String, Object?>{
      ...validBlob.toJson(),
      'canonicalSha256':
          'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
    };
    final replayBytes = utf8.encode(jsonEncode(tampered));
    final session = _session(
      runSessionId: validBlob.runSessionId,
      mode: RunMode.practice,
      seed: validBlob.seed,
      digest:
          'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
      contentLengthBytes: replayBytes.length,
      validationAttempt: 1,
    );
    final repo = _FakeRunSessionRepository(
      leaseResult: RunSessionLeaseAcquireResult(
        status: RunSessionLeaseStatus.acquired,
        session: session,
      ),
    );
    final loader = _FakeReplayLoader(
      bytesByRunSession: <String, List<int>>{
        validBlob.runSessionId: replayBytes,
      },
    );
    final rewards = _FakeRewardGrantWriter();
    final worker = DeterministicValidatorWorker(
      replayLoader: loader,
      boardRepository: _FakeBoardRepository(),
      runSessionRepository: repo,
      leaderboardProjector: _FakeLeaderboardProjector(),
      rewardGrantWriter: rewards,
      ghostPublisher: _FakeGhostPublisher(),
      metrics: _FakeValidatorMetrics(),
      clockMs: () => 20_000,
    );

    final result = await worker.validateRunSession(
      runSessionId: validBlob.runSessionId,
    );

    expect(result.status, ValidationDispatchStatus.rejected);
    expect(repo.persistedValidatedRuns, hasLength(1));
    expect(repo.persistedValidatedRuns.single.accepted, isFalse);
    expect(repo.persistedValidatedRuns.single.rejectionReason, 'protocol_invalid');
    expect(rewards.validatedRunSessionIds, isEmpty);
    expect(rewards.revokedSettlements, hasLength(1));
    expect(rewards.revokedSettlements.single.runSessionId, validBlob.runSessionId);
    expect(rewards.revokedSettlements.single.reason, 'protocol_invalid');
    expect(repo.terminalWrites, hasLength(1));
    expect(
      repo.terminalWrites.single.terminalState,
      RunSessionTerminalState.rejected,
    );
  });

  test('duplicate task is idempotent when lease is already terminal', () async {
    final repo = _FakeRunSessionRepository(
      leaseResult: const RunSessionLeaseAcquireResult(
        status: RunSessionLeaseStatus.alreadyTerminal,
        message: 'already terminal',
      ),
    );
    final worker = DeterministicValidatorWorker(
      replayLoader: _FakeReplayLoader(bytesByRunSession: const {}),
      boardRepository: _FakeBoardRepository(),
      runSessionRepository: repo,
      leaderboardProjector: _FakeLeaderboardProjector(),
      rewardGrantWriter: _FakeRewardGrantWriter(),
      ghostPublisher: _FakeGhostPublisher(),
      metrics: _FakeValidatorMetrics(),
      clockMs: () => 30_000,
    );

    final result = await worker.validateRunSession(runSessionId: 'run_terminal');

    expect(result.status, ValidationDispatchStatus.accepted);
    expect(repo.persistedValidatedRuns, isEmpty);
    expect(repo.terminalWrites, isEmpty);
    expect(repo.pendingRetryWrites, isEmpty);
  });

  test('transient failures schedule retry using backoff', () async {
    final session = _session(
      runSessionId: 'run_retry',
      mode: RunMode.practice,
      seed: 9,
      digest:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      contentLengthBytes: 16,
      validationAttempt: 2,
    );
    final repo = _FakeRunSessionRepository(
      leaseResult: RunSessionLeaseAcquireResult(
        status: RunSessionLeaseStatus.acquired,
        session: session,
      ),
    );
    final loader = _FakeReplayLoader(
      bytesByRunSession: const {},
      errorByRunSession: <String, Object>{
        'run_retry': Exception('temporary storage outage'),
      },
    );
    final worker = DeterministicValidatorWorker(
      replayLoader: loader,
      boardRepository: _FakeBoardRepository(),
      runSessionRepository: repo,
      leaderboardProjector: _FakeLeaderboardProjector(),
      rewardGrantWriter: _FakeRewardGrantWriter(),
      ghostPublisher: _FakeGhostPublisher(),
      metrics: _FakeValidatorMetrics(),
      clockMs: () => 1_000,
    );

    final result = await worker.validateRunSession(runSessionId: 'run_retry');

    expect(result.status, ValidationDispatchStatus.retryScheduled);
    expect(repo.pendingRetryWrites, hasLength(1));
    expect(repo.pendingRetryWrites.single.nextAttemptAtMs, 121000);
    expect(repo.terminalWrites, isEmpty);
  });

  test('reward settlement writes can be disabled via rollout toggle', () async {
    final replayBlob = ReplayBlobV1.withComputedDigest(
      runSessionId: 'run_no_settlement_writes',
      tickHz: 60,
      seed: 1337,
      levelId: 'field',
      playerCharacterId: 'eloise',
      loadoutSnapshot: _defaultLoadoutSnapshot(),
      totalTicks: 0,
      commandStream: const <ReplayCommandFrameV1>[],
    );
    final replayBytes = utf8.encode(jsonEncode(replayBlob.toJson()));
    final session = _session(
      runSessionId: replayBlob.runSessionId,
      mode: RunMode.practice,
      seed: replayBlob.seed,
      digest: replayBlob.canonicalSha256,
      contentLengthBytes: replayBytes.length,
      validationAttempt: 1,
    );
    final repo = _FakeRunSessionRepository(
      leaseResult: RunSessionLeaseAcquireResult(
        status: RunSessionLeaseStatus.acquired,
        session: session,
      ),
    );
    final loader = _FakeReplayLoader(
      bytesByRunSession: <String, List<int>>{
        replayBlob.runSessionId: replayBytes,
      },
    );
    final rewards = _FakeRewardGrantWriter();
    final worker = DeterministicValidatorWorker(
      replayLoader: loader,
      boardRepository: _FakeBoardRepository(),
      runSessionRepository: repo,
      leaderboardProjector: _FakeLeaderboardProjector(),
      rewardGrantWriter: rewards,
      ghostPublisher: _FakeGhostPublisher(),
      metrics: _FakeValidatorMetrics(),
      enableRewardSettlementWrites: false,
      clockMs: () => 1000,
    );

    final result = await worker.validateRunSession(
      runSessionId: replayBlob.runSessionId,
    );

    expect(result.status, ValidationDispatchStatus.accepted);
    expect(rewards.validatedRunSessionIds, isEmpty);
    expect(rewards.revokedSettlements, isEmpty);
    expect(repo.terminalWrites, hasLength(1));
    expect(
      repo.terminalWrites.single.terminalState,
      RunSessionTerminalState.validated,
    );
  });

  test('attempt budget exhaustion enters internal-error grace window', () async {
    final session = _session(
      runSessionId: 'run_exhausted',
      mode: RunMode.practice,
      seed: 11,
      digest:
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      contentLengthBytes: 16,
      validationAttempt: 8,
    );
    final repo = _FakeRunSessionRepository(
      leaseResult: RunSessionLeaseAcquireResult(
        status: RunSessionLeaseStatus.acquired,
        session: session,
      ),
    );
    final loader = _FakeReplayLoader(
      bytesByRunSession: const {},
      errorByRunSession: <String, Object>{
        'run_exhausted': Exception('persistent failure'),
      },
    );
    final rewards = _FakeRewardGrantWriter();
    final worker = DeterministicValidatorWorker(
      replayLoader: loader,
      boardRepository: _FakeBoardRepository(),
      runSessionRepository: repo,
      leaderboardProjector: _FakeLeaderboardProjector(),
      rewardGrantWriter: rewards,
      ghostPublisher: _FakeGhostPublisher(),
      metrics: _FakeValidatorMetrics(),
      clockMs: () => 1_000,
    );

    final result = await worker.validateRunSession(runSessionId: 'run_exhausted');

    expect(result.status, ValidationDispatchStatus.retryScheduled);
    expect(repo.pendingRetryWrites, hasLength(1));
    expect(repo.pendingRetryWrites.single.internalErrorFirstAtMs, 1000);
    expect(rewards.validatedRunSessionIds, isEmpty);
    expect(rewards.revokedSettlements, isEmpty);
    expect(repo.terminalWrites, isEmpty);
  });

  test('grace window expiry auto-revokes and terminalizes internal_error', () async {
    final session = _session(
      runSessionId: 'run_grace_expired',
      mode: RunMode.practice,
      seed: 12,
      digest:
          'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
      contentLengthBytes: 16,
      validationAttempt: 9,
      internalErrorFirstAtMs: 1000,
    );
    final repo = _FakeRunSessionRepository(
      leaseResult: RunSessionLeaseAcquireResult(
        status: RunSessionLeaseStatus.acquired,
        session: session,
      ),
    );
    final loader = _FakeReplayLoader(
      bytesByRunSession: const {},
      errorByRunSession: <String, Object>{
        'run_grace_expired': Exception('persistent failure'),
      },
    );
    final rewards = _FakeRewardGrantWriter();
    final worker = DeterministicValidatorWorker(
      replayLoader: loader,
      boardRepository: _FakeBoardRepository(),
      runSessionRepository: repo,
      leaderboardProjector: _FakeLeaderboardProjector(),
      rewardGrantWriter: rewards,
      ghostPublisher: _FakeGhostPublisher(),
      metrics: _FakeValidatorMetrics(),
      internalErrorGraceWindow: const Duration(seconds: 1),
      clockMs: () => 3000,
    );

    final result = await worker.validateRunSession(
      runSessionId: 'run_grace_expired',
    );

    expect(result.status, ValidationDispatchStatus.rejected);
    expect(repo.pendingRetryWrites, isEmpty);
    expect(rewards.revokedSettlements, hasLength(1));
    expect(rewards.revokedSettlements.single.runSessionId, 'run_grace_expired');
    expect(repo.terminalWrites, hasLength(1));
    expect(
      repo.terminalWrites.single.terminalState,
      RunSessionTerminalState.internalError,
    );
  });

  test('incident mode pauses auto-revoke even after grace expiry', () async {
    final session = _session(
      runSessionId: 'run_incident_pause',
      mode: RunMode.practice,
      seed: 13,
      digest:
          'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
      contentLengthBytes: 16,
      validationAttempt: 9,
      internalErrorFirstAtMs: 1000,
    );
    final repo = _FakeRunSessionRepository(
      leaseResult: RunSessionLeaseAcquireResult(
        status: RunSessionLeaseStatus.acquired,
        session: session,
      ),
    );
    final loader = _FakeReplayLoader(
      bytesByRunSession: const {},
      errorByRunSession: <String, Object>{
        'run_incident_pause': Exception('persistent failure'),
      },
    );
    final rewards = _FakeRewardGrantWriter();
    final worker = DeterministicValidatorWorker(
      replayLoader: loader,
      boardRepository: _FakeBoardRepository(),
      runSessionRepository: repo,
      leaderboardProjector: _FakeLeaderboardProjector(),
      rewardGrantWriter: rewards,
      ghostPublisher: _FakeGhostPublisher(),
      metrics: _FakeValidatorMetrics(),
      internalErrorGraceWindow: const Duration(seconds: 1),
      incidentModeAutoRevokePaused: true,
      incidentModeRetryDelay: const Duration(seconds: 30),
      clockMs: () => 5000,
    );

    final result = await worker.validateRunSession(
      runSessionId: 'run_incident_pause',
    );

    expect(result.status, ValidationDispatchStatus.retryScheduled);
    expect(repo.pendingRetryWrites, hasLength(1));
    expect(repo.pendingRetryWrites.single.nextAttemptAtMs, 35000);
    expect(repo.pendingRetryWrites.single.internalErrorFirstAtMs, 1000);
    expect(rewards.revokedSettlements, isEmpty);
    expect(repo.terminalWrites, isEmpty);
  });
}

ValidatorRunSession _session({
  required String runSessionId,
  required RunMode mode,
  required int seed,
  required String digest,
  required int contentLengthBytes,
  required int validationAttempt,
  int? internalErrorFirstAtMs,
}) {
  assert(
    ReplayDigest.isValidSha256Hex(digest),
    'Digest must be valid SHA-256 hex.',
  );
  return ValidatorRunSession(
    runSessionId: runSessionId,
    uid: 'uid_1',
    runTicket: RunTicket(
      runSessionId: runSessionId,
      uid: 'uid_1',
      mode: mode,
      seed: seed,
      tickHz: 60,
      gameCompatVersion: '2026.03.0',
      levelId: 'field',
      playerCharacterId: 'eloise',
      loadoutSnapshot: _defaultLoadoutSnapshot(),
      loadoutDigest:
          '0123456789012345678901234567890123456789012345678901234567890123',
      issuedAtMs: 1,
      expiresAtMs: 2,
      singleUseNonce: 'nonce',
    ),
    uploadedReplay: UploadedReplayRef(
      objectPath: 'replay-submissions/pending/uid_1/$runSessionId/replay.bin.gz',
      canonicalSha256: digest,
      contentLengthBytes: contentLengthBytes,
      contentType: 'application/octet-stream',
    ),
    validationAttempt: validationAttempt,
    internalErrorFirstAtMs: internalErrorFirstAtMs,
  );
}

Map<String, Object?> _defaultLoadoutSnapshot() {
  return const <String, Object?>{
    'mask': 0,
    'mainWeaponId': 'plainsteel',
    'offhandWeaponId': 'roadguard',
    'spellBookId': 'apprenticePrimer',
    'projectileSlotSpellId': 'iceBolt',
    'accessoryId': 'strengthBelt',
    'abilityPrimaryId': 'eloise.seeker_slash',
    'abilitySecondaryId': 'eloise.shield_block',
    'abilityProjectileId': 'eloise.snap_shot',
    'abilitySpellId': 'eloise.arcane_haste',
    'abilityMobilityId': 'eloise.dash',
    'abilityJumpId': 'eloise.jump',
  };
}

class _FakeRunSessionRepository implements RunSessionRepository {
  _FakeRunSessionRepository({required this.leaseResult});

  final RunSessionLeaseAcquireResult leaseResult;
  final List<ValidatedRun> persistedValidatedRuns = <ValidatedRun>[];
  final List<_TerminalWrite> terminalWrites = <_TerminalWrite>[];
  final List<_PendingRetryWrite> pendingRetryWrites = <_PendingRetryWrite>[];

  @override
  Future<RunSessionLeaseAcquireResult> acquireValidationLease({
    required String runSessionId,
  }) async {
    return leaseResult;
  }

  @override
  Future<void> markPendingValidationRetry({
    required String runSessionId,
    required int nextAttemptAtMs,
    required String message,
    int? internalErrorFirstAtMs,
  }) async {
    pendingRetryWrites.add(
      _PendingRetryWrite(
        runSessionId: runSessionId,
        nextAttemptAtMs: nextAttemptAtMs,
        message: message,
        internalErrorFirstAtMs: internalErrorFirstAtMs,
      ),
    );
  }

  @override
  Future<void> markTerminal({
    required String runSessionId,
    required RunSessionTerminalState terminalState,
    String? message,
  }) async {
    terminalWrites.add(
      _TerminalWrite(
        runSessionId: runSessionId,
        terminalState: terminalState,
        message: message,
      ),
    );
  }

  @override
  Future<void> persistValidatedRun({
    required ValidatedRun validatedRun,
  }) async {
    persistedValidatedRuns.add(validatedRun);
  }
}

class _TerminalWrite {
  const _TerminalWrite({
    required this.runSessionId,
    required this.terminalState,
    this.message,
  });

  final String runSessionId;
  final RunSessionTerminalState terminalState;
  final String? message;
}

class _PendingRetryWrite {
  const _PendingRetryWrite({
    required this.runSessionId,
    required this.nextAttemptAtMs,
    required this.message,
    this.internalErrorFirstAtMs,
  });

  final String runSessionId;
  final int nextAttemptAtMs;
  final String message;
  final int? internalErrorFirstAtMs;
}

class _FakeReplayLoader implements ReplayLoader {
  const _FakeReplayLoader({
    required this.bytesByRunSession,
    this.errorByRunSession = const <String, Object>{},
  });

  final Map<String, List<int>> bytesByRunSession;
  final Map<String, Object> errorByRunSession;

  @override
  Future<LoadedReplay> loadReplay({
    required String runSessionId,
    required String objectPath,
  }) async {
    final error = errorByRunSession[runSessionId];
    if (error != null) {
      throw error;
    }
    final bytes = bytesByRunSession[runSessionId];
    if (bytes == null) {
      throw StateError('Missing replay bytes for runSessionId=$runSessionId');
    }
    return LoadedReplay(
      runSessionId: runSessionId,
      objectPath: objectPath,
      bytes: bytes,
    );
  }
}

class _FakeBoardRepository implements BoardRepository {
  @override
  Future<Map<String, Object?>?> loadBoardForRunSession({
    required String runSessionId,
  }) async {
    return null;
  }
}

class _FakeLeaderboardProjector implements LeaderboardProjector {
  final List<String> runSessionIds = <String>[];

  @override
  Future<void> projectValidatedRun({
    required String runSessionId,
  }) async {
    runSessionIds.add(runSessionId);
  }
}

class _FakeRewardGrantWriter implements RewardGrantWriter {
  final List<String> validatedRunSessionIds = <String>[];
  final List<_RevokedSettlement> revokedSettlements = <_RevokedSettlement>[];

  @override
  Future<void> settleValidatedRewardGrant({
    required String runSessionId,
  }) async {
    validatedRunSessionIds.add(runSessionId);
  }

  @override
  Future<void> settleRevokedRewardGrant({
    required String runSessionId,
    required String settlementReason,
  }) async {
    revokedSettlements.add(
      _RevokedSettlement(runSessionId: runSessionId, reason: settlementReason),
    );
  }
}

class _RevokedSettlement {
  const _RevokedSettlement({
    required this.runSessionId,
    required this.reason,
  });

  final String runSessionId;
  final String reason;
}

class _FakeGhostPublisher implements GhostPublisher {
  final List<String> runSessionIds = <String>[];

  @override
  Future<void> updateGhostArtifacts({
    required String runSessionId,
  }) async {
    runSessionIds.add(runSessionId);
  }
}

class _FakeValidatorMetrics implements ValidatorMetrics {
  final List<_MetricRecord> records = <_MetricRecord>[];

  @override
  Future<void> recordDispatch({
    required String runSessionId,
    required String status,
    String? message,
    int? attempt,
    String? mode,
    String? phase,
    String? rejectionReason,
  }) async {
    records.add(
      _MetricRecord(
        runSessionId: runSessionId,
        status: status,
        message: message,
        attempt: attempt,
        mode: mode,
        phase: phase,
        rejectionReason: rejectionReason,
      ),
    );
  }
}

class _MetricRecord {
  const _MetricRecord({
    required this.runSessionId,
    required this.status,
    this.message,
    this.attempt,
    this.mode,
    this.phase,
    this.rejectionReason,
  });

  final String runSessionId;
  final String status;
  final String? message;
  final int? attempt;
  final String? mode;
  final String? phase;
  final String? rejectionReason;
}
