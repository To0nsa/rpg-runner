import 'dart:convert';
import 'dart:io';

import 'package:run_protocol/board_key.dart';
import 'package:run_protocol/replay_blob.dart';
import 'package:run_protocol/replay_digest.dart';
import 'package:run_protocol/run_mode.dart';
import 'package:run_protocol/run_ticket.dart';
import 'package:run_protocol/validated_run.dart';
import 'package:test/test.dart';

import 'package:replay_validator/src/board_repository.dart';
import 'package:replay_validator/src/metrics.dart';
import 'package:replay_validator/src/replay_loader.dart';
import 'package:replay_validator/src/replay_validation_limits.dart';
import 'package:replay_validator/src/run_session_repository.dart';
import 'package:replay_validator/src/settlement_dispatcher.dart';
import 'package:replay_validator/src/validated_replay_archiver.dart';
import 'package:replay_validator/src/validator_worker.dart';

void main() {
  test('distanceUnitsToMeters converts world units to meters', () {
    expect(distanceUnitsToMeters(0), 0);
    expect(distanceUnitsToMeters(49.9), 0);
    expect(distanceUnitsToMeters(50), 1);
    expect(distanceUnitsToMeters(99.9), 1);
    expect(distanceUnitsToMeters(149.9), 2);
  });

  test('accepted 30 Hz practice replay creates a settlement handoff', () async {
    final replayBlob = ReplayBlobV1.withComputedDigest(
      runSessionId: 'run_accepted',
      tickHz: 30,
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
      tickHz: replayBlob.tickHz,
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
    final metrics = _FakeValidatorMetrics();
    final settlementDispatcher = _FakeSettlementDispatcher();
    final archiver = _FakeValidatedReplayArchiver();
    final worker = DeterministicValidatorWorker(
      replayLoader: loader,
      boardRepository: _FakeBoardRepository(),
      runSessionRepository: repo,
      metrics: metrics,
      settlementDispatcher: settlementDispatcher,
      validatedReplayArchiver: archiver,
      clockMs: () => 10_000,
    );

    final result = await worker.validateRunSession(
      runSessionId: replayBlob.runSessionId,
    );

    expect(result.status, ValidationDispatchStatus.accepted);
    expect(repo.acceptedSettlementHandoffs, hasLength(1));
    expect(repo.acceptedSettlementHandoffs.single.accepted, isTrue);
    expect(
      repo.acceptedSettlementHandoffs.single.replayStorageRef,
      'replay-submissions/validated/${replayBlob.runSessionId}.bin.gz',
    );
    expect(
      repo.acceptedSettlementHandoffs.single.replayStorageGeneration,
      '456',
    );
    expect(archiver.runSessionIds, <String>[replayBlob.runSessionId]);
    expect(settlementDispatcher.runSessionIds, <String>[
      replayBlob.runSessionId,
    ]);
    expect(repo.persistedValidatedRuns, isEmpty);
    expect(repo.terminalWrites, isEmpty);
    expect(metrics.records.last.status, ValidationDispatchStatus.accepted.name);
  });

  test(
    'accepted ranked replay uses immutable ticket board data after board deletion',
    () async {
      final boardKey = BoardKey(
        mode: RunMode.competitive,
        levelId: 'field',
        windowId: '2026-07',
        rulesetVersion: 'rules-v1',
        scoreVersion: 'score-v1',
      );
      final replayBlob = ReplayBlobV1.withComputedDigest(
        runSessionId: 'run_ranked_board_deleted',
        boardId: 'board_1',
        boardKey: boardKey,
        tickHz: 60,
        seed: 1234,
        levelId: 'field',
        playerCharacterId: 'eloise',
        loadoutSnapshot: _defaultLoadoutSnapshot(),
        totalTicks: 0,
        commandStream: const <ReplayCommandFrameV1>[],
      );
      final replayBytes = utf8.encode(jsonEncode(replayBlob.toJson()));
      final repo = _FakeRunSessionRepository(
        leaseResult: RunSessionLeaseAcquireResult(
          status: RunSessionLeaseStatus.acquired,
          session: _session(
            runSessionId: replayBlob.runSessionId,
            mode: RunMode.competitive,
            seed: replayBlob.seed,
            digest: replayBlob.canonicalSha256,
            contentLengthBytes: replayBytes.length,
            validationAttempt: 1,
          ),
        ),
      );
      final worker = DeterministicValidatorWorker(
        replayLoader: _FakeReplayLoader(
          bytesByRunSession: <String, List<int>>{
            replayBlob.runSessionId: replayBytes,
          },
        ),
        boardRepository: _FakeBoardRepository(),
        runSessionRepository: repo,
        metrics: _FakeValidatorMetrics(),
        clockMs: () => 10_000,
      );

      final result = await worker.validateRunSession(
        runSessionId: replayBlob.runSessionId,
      );

      expect(result.status, ValidationDispatchStatus.accepted);
      expect(repo.acceptedSettlementHandoffs, hasLength(1));
    },
  );

  test(
    'missing immutable replay generation is rejected before loading',
    () async {
      final repo = _FakeRunSessionRepository(
        leaseResult: RunSessionLeaseAcquireResult(
          status: RunSessionLeaseStatus.acquired,
          session: _session(
            runSessionId: 'run_missing_generation',
            mode: RunMode.practice,
            seed: 1,
            digest: '1' * 64,
            contentLengthBytes: 16,
            validationAttempt: 1,
            storageGeneration: null,
          ),
        ),
      );
      final worker = DeterministicValidatorWorker(
        replayLoader: _FakeReplayLoader(bytesByRunSession: const {}),
        boardRepository: _FakeBoardRepository(),
        runSessionRepository: repo,
        metrics: _FakeValidatorMetrics(),
        clockMs: () => 10_000,
      );

      final result = await worker.validateRunSession(
        runSessionId: 'run_missing_generation',
      );

      expect(result.status, ValidationDispatchStatus.rejected);
      expect(
        repo.persistedValidatedRuns.single.rejectionReason,
        'replay_generation_missing',
      );
    },
  );

  test('ticket identity mismatch is rejected before replay loading', () async {
    final repo = _FakeRunSessionRepository(
      leaseResult: RunSessionLeaseAcquireResult(
        status: RunSessionLeaseStatus.acquired,
        session: _session(
          runSessionId: 'run_ticket_identity',
          ticketRunSessionId: 'other_run',
          mode: RunMode.practice,
          seed: 1,
          digest: '2' * 64,
          contentLengthBytes: 16,
          validationAttempt: 1,
        ),
      ),
    );
    final worker = DeterministicValidatorWorker(
      replayLoader: _FakeReplayLoader(bytesByRunSession: const {}),
      boardRepository: _FakeBoardRepository(),
      runSessionRepository: repo,
      metrics: _FakeValidatorMetrics(),
      clockMs: () => 10_000,
    );

    final result = await worker.validateRunSession(
      runSessionId: 'run_ticket_identity',
    );

    expect(result.status, ValidationDispatchStatus.rejected);
    expect(
      repo.persistedValidatedRuns.single.rejectionReason,
      'ticket_identity_mismatch',
    );
  });

  test('unsupported game compatibility version is rejected', () async {
    final repo = _FakeRunSessionRepository(
      leaseResult: RunSessionLeaseAcquireResult(
        status: RunSessionLeaseStatus.acquired,
        session: _session(
          runSessionId: 'run_unknown_compat',
          mode: RunMode.practice,
          seed: 1,
          digest: '3' * 64,
          contentLengthBytes: 16,
          validationAttempt: 1,
          gameCompatVersion: '2099.01.0',
        ),
      ),
    );
    final worker = DeterministicValidatorWorker(
      replayLoader: _FakeReplayLoader(bytesByRunSession: const {}),
      boardRepository: _FakeBoardRepository(),
      runSessionRepository: repo,
      metrics: _FakeValidatorMetrics(),
      clockMs: () => 10_000,
    );

    final result = await worker.validateRunSession(
      runSessionId: 'run_unknown_compat',
    );

    expect(result.status, ValidationDispatchStatus.rejected);
    expect(
      repo.persistedValidatedRuns.single.rejectionReason,
      'game_compat_version_unsupported',
    );
  });

  for (final versionCase
      in <
        ({
          String name,
          String? rulesetVersion,
          String? scoreVersion,
          String? ghostVersion,
        })
      >[
        (
          name: 'ruleset',
          rulesetVersion: 'rules-v999',
          scoreVersion: null,
          ghostVersion: null,
        ),
        (
          name: 'score',
          rulesetVersion: null,
          scoreVersion: 'score-v999',
          ghostVersion: null,
        ),
        (
          name: 'ghost',
          rulesetVersion: null,
          scoreVersion: null,
          ghostVersion: 'ghost-v999',
        ),
      ]) {
    test('unsupported ${versionCase.name} version is rejected', () async {
      final runSessionId = 'run_unknown_${versionCase.name}';
      final repo = _FakeRunSessionRepository(
        leaseResult: RunSessionLeaseAcquireResult(
          status: RunSessionLeaseStatus.acquired,
          session: _session(
            runSessionId: runSessionId,
            mode: RunMode.competitive,
            seed: 1,
            digest: '5' * 64,
            contentLengthBytes: 16,
            validationAttempt: 1,
            rulesetVersion: versionCase.rulesetVersion,
            scoreVersion: versionCase.scoreVersion,
            ghostVersion: versionCase.ghostVersion,
          ),
        ),
      );
      final worker = DeterministicValidatorWorker(
        replayLoader: _FakeReplayLoader(bytesByRunSession: const {}),
        boardRepository: _FakeBoardRepository(),
        runSessionRepository: repo,
        metrics: _FakeValidatorMetrics(),
        clockMs: () => 10_000,
      );

      final result = await worker.validateRunSession(
        runSessionId: runSessionId,
      );

      expect(result.status, ValidationDispatchStatus.rejected);
      expect(
        repo.persistedValidatedRuns.single.rejectionReason,
        'board_compat_version_unsupported',
      );
    });
  }

  test('loadout digest mismatch is rejected before replay loading', () async {
    final repo = _FakeRunSessionRepository(
      leaseResult: RunSessionLeaseAcquireResult(
        status: RunSessionLeaseStatus.acquired,
        session: _session(
          runSessionId: 'run_bad_loadout_digest',
          mode: RunMode.practice,
          seed: 1,
          digest: '4' * 64,
          contentLengthBytes: 16,
          validationAttempt: 1,
          loadoutDigest: 'f' * 64,
        ),
      ),
    );
    final worker = DeterministicValidatorWorker(
      replayLoader: _FakeReplayLoader(bytesByRunSession: const {}),
      boardRepository: _FakeBoardRepository(),
      runSessionRepository: repo,
      metrics: _FakeValidatorMetrics(),
      clockMs: () => 10_000,
    );

    final result = await worker.validateRunSession(
      runSessionId: 'run_bad_loadout_digest',
    );

    expect(result.status, ValidationDispatchStatus.rejected);
    expect(
      repo.persistedValidatedRuns.single.rejectionReason,
      'loadout_digest_mismatch',
    );
  });

  test(
    'immediate settlement failure leaves accepted handoff to fallback delivery',
    () async {
      final replayBlob = ReplayBlobV1.withComputedDigest(
        runSessionId: 'run_immediate_dispatch_failure',
        tickHz: 60,
        seed: 5432,
        levelId: 'field',
        playerCharacterId: 'eloise',
        loadoutSnapshot: _defaultLoadoutSnapshot(),
        totalTicks: 0,
        commandStream: const <ReplayCommandFrameV1>[],
      );
      final replayBytes = utf8.encode(jsonEncode(replayBlob.toJson()));
      final repo = _FakeRunSessionRepository(
        leaseResult: RunSessionLeaseAcquireResult(
          status: RunSessionLeaseStatus.acquired,
          session: _session(
            runSessionId: replayBlob.runSessionId,
            mode: RunMode.practice,
            seed: replayBlob.seed,
            digest: replayBlob.canonicalSha256,
            contentLengthBytes: replayBytes.length,
            validationAttempt: 1,
          ),
        ),
      );
      final metrics = _FakeValidatorMetrics();
      final worker = DeterministicValidatorWorker(
        replayLoader: _FakeReplayLoader(
          bytesByRunSession: <String, List<int>>{
            replayBlob.runSessionId: replayBytes,
          },
        ),
        boardRepository: _FakeBoardRepository(),
        runSessionRepository: repo,
        metrics: metrics,
        settlementDispatcher: _FakeSettlementDispatcher(
          error: StateError('immediate endpoint unavailable'),
        ),
        clockMs: () => 10_000,
      );

      final result = await worker.validateRunSession(
        runSessionId: replayBlob.runSessionId,
      );

      expect(result.status, ValidationDispatchStatus.accepted);
      expect(repo.acceptedSettlementHandoffs, hasLength(1));
      expect(repo.pendingRetryWrites, isEmpty);
      expect(
        metrics.records.any(
          (record) => record.phase == 'settlement_dispatch_fallback',
        ),
        isTrue,
      );
    },
  );

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
    final worker = DeterministicValidatorWorker(
      replayLoader: loader,
      boardRepository: _FakeBoardRepository(),
      runSessionRepository: repo,
      metrics: _FakeValidatorMetrics(),
      clockMs: () => 20_000,
    );

    final result = await worker.validateRunSession(
      runSessionId: validBlob.runSessionId,
    );

    expect(result.status, ValidationDispatchStatus.rejected);
    expect(repo.persistedValidatedRuns, hasLength(1));
    expect(repo.persistedValidatedRuns.single.accepted, isFalse);
    expect(
      repo.persistedValidatedRuns.single.rejectionReason,
      'protocol_invalid',
    );
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
      metrics: _FakeValidatorMetrics(),
      clockMs: () => 30_000,
    );

    final result = await worker.validateRunSession(
      runSessionId: 'run_terminal',
    );

    expect(result.status, ValidationDispatchStatus.accepted);
    expect(repo.persistedValidatedRuns, isEmpty);
    expect(repo.terminalWrites, isEmpty);
    expect(repo.pendingRetryWrites, isEmpty);
  });

  test('active validation lease asks Cloud Tasks to retry', () async {
    final repo = _FakeRunSessionRepository(
      leaseResult: const RunSessionLeaseAcquireResult(
        status: RunSessionLeaseStatus.alreadyValidating,
        message: 'active lease',
      ),
    );
    final metrics = _FakeValidatorMetrics();
    final worker = DeterministicValidatorWorker(
      replayLoader: _FakeReplayLoader(bytesByRunSession: const {}),
      boardRepository: _FakeBoardRepository(),
      runSessionRepository: repo,
      metrics: metrics,
    );

    final result = await worker.validateRunSession(
      runSessionId: 'run_active_lease',
    );

    expect(result.status, ValidationDispatchStatus.retryScheduled);
    expect(repo.persistedValidatedRuns, isEmpty);
    expect(metrics.records, hasLength(1));
    expect(
      metrics.records.single.status,
      ValidationDispatchStatus.retryScheduled.name,
    );
    expect(metrics.records.single.phase, 'lease');
  });

  test('accepted handoff lease conflict is a structured task retry', () async {
    final replayBlob = ReplayBlobV1.withComputedDigest(
      runSessionId: 'run_handoff_conflict',
      tickHz: 60,
      seed: 20,
      levelId: 'field',
      playerCharacterId: 'eloise',
      loadoutSnapshot: _defaultLoadoutSnapshot(),
      totalTicks: 1,
      commandStream: const <ReplayCommandFrameV1>[],
    );
    final replayBytes = utf8.encode(jsonEncode(replayBlob.toJson()));
    final repo = _FakeRunSessionRepository(
      leaseResult: RunSessionLeaseAcquireResult(
        status: RunSessionLeaseStatus.acquired,
        session: _session(
          runSessionId: replayBlob.runSessionId,
          mode: RunMode.practice,
          seed: replayBlob.seed,
          digest: replayBlob.canonicalSha256,
          contentLengthBytes: replayBytes.length,
          validationAttempt: 1,
        ),
      ),
      acceptedHandoffError: const StaleValidationLeaseException(
        'run_handoff_conflict',
      ),
    );
    final metrics = _FakeValidatorMetrics();
    final worker = DeterministicValidatorWorker(
      replayLoader: _FakeReplayLoader(
        bytesByRunSession: <String, List<int>>{
          replayBlob.runSessionId: replayBytes,
        },
      ),
      boardRepository: _FakeBoardRepository(),
      runSessionRepository: repo,
      metrics: metrics,
    );

    final result = await worker.validateRunSession(
      runSessionId: replayBlob.runSessionId,
    );

    expect(result.status, ValidationDispatchStatus.retryScheduled);
    expect(metrics.records.last.status, 'retryScheduled');
    expect(metrics.records.last.phase, 'lease_conflict');
    expect(metrics.records.last.message, contains('accepted handoff'));
  });

  test('ticket finalized at expiry is rejected before replay load', () async {
    final repo = _FakeRunSessionRepository(
      leaseResult: RunSessionLeaseAcquireResult(
        status: RunSessionLeaseStatus.acquired,
        session: _session(
          runSessionId: 'run_expired_ticket',
          mode: RunMode.practice,
          seed: 20,
          digest: '1' * 64,
          contentLengthBytes: 16,
          validationAttempt: 1,
          issuedAtMs: 1000,
          finalizedAtMs: 86_401_000,
        ),
      ),
    );
    final worker = DeterministicValidatorWorker(
      replayLoader: _FakeReplayLoader(bytesByRunSession: const {}),
      boardRepository: _FakeBoardRepository(),
      runSessionRepository: repo,
      metrics: _FakeValidatorMetrics(),
      clockMs: () => 86_401_000,
    );

    final result = await worker.validateRunSession(
      runSessionId: 'run_expired_ticket',
    );

    expect(result.status, ValidationDispatchStatus.rejected);
    expect(
      repo.persistedValidatedRuns.single.rejectionReason,
      'ticket_expired',
    );
  });

  test('future-issued ticket beyond clock skew is rejected', () async {
    final repo = _FakeRunSessionRepository(
      leaseResult: RunSessionLeaseAcquireResult(
        status: RunSessionLeaseStatus.acquired,
        session: _session(
          runSessionId: 'run_future_ticket',
          mode: RunMode.practice,
          seed: 20,
          digest: '2' * 64,
          contentLengthBytes: 16,
          validationAttempt: 1,
          issuedAtMs: 301_001,
          finalizedAtMs: 301_002,
        ),
      ),
    );
    final worker = DeterministicValidatorWorker(
      replayLoader: _FakeReplayLoader(bytesByRunSession: const {}),
      boardRepository: _FakeBoardRepository(),
      runSessionRepository: repo,
      metrics: _FakeValidatorMetrics(),
      clockMs: () => 1000,
    );

    final result = await worker.validateRunSession(
      runSessionId: 'run_future_ticket',
    );

    expect(result.status, ValidationDispatchStatus.rejected);
    expect(
      repo.persistedValidatedRuns.single.rejectionReason,
      'ticket_issued_in_future',
    );
  });

  test('ticket with malformed expiry duration is rejected', () async {
    final repo = _FakeRunSessionRepository(
      leaseResult: RunSessionLeaseAcquireResult(
        status: RunSessionLeaseStatus.acquired,
        session: _session(
          runSessionId: 'run_bad_ticket_duration',
          mode: RunMode.practice,
          seed: 20,
          digest: '3' * 64,
          contentLengthBytes: 16,
          validationAttempt: 1,
          issuedAtMs: 1,
          expiresAtMs: 1001,
          finalizedAtMs: 2,
        ),
      ),
    );
    final worker = DeterministicValidatorWorker(
      replayLoader: _FakeReplayLoader(bytesByRunSession: const {}),
      boardRepository: _FakeBoardRepository(),
      runSessionRepository: repo,
      metrics: _FakeValidatorMetrics(),
      clockMs: () => 1000,
    );

    final result = await worker.validateRunSession(
      runSessionId: 'run_bad_ticket_duration',
    );

    expect(result.status, ValidationDispatchStatus.rejected);
    expect(
      repo.persistedValidatedRuns.single.rejectionReason,
      'ticket_expiry_duration_invalid',
    );
  });

  test('ranked ticket issued outside its board window is rejected', () async {
    final repo = _FakeRunSessionRepository(
      leaseResult: RunSessionLeaseAcquireResult(
        status: RunSessionLeaseStatus.acquired,
        session: _session(
          runSessionId: 'run_wrong_board_window',
          mode: RunMode.competitive,
          seed: 20,
          digest: '4' * 64,
          contentLengthBytes: 16,
          validationAttempt: 1,
          issuedAtMs: 1000,
          finalizedAtMs: 1001,
          boardOpensAtMs: 2000,
          boardClosesAtMs: 3000,
        ),
      ),
    );
    final worker = DeterministicValidatorWorker(
      replayLoader: _FakeReplayLoader(bytesByRunSession: const {}),
      boardRepository: _FakeBoardRepository(),
      runSessionRepository: repo,
      metrics: _FakeValidatorMetrics(),
      clockMs: () => 1000,
    );

    final result = await worker.validateRunSession(
      runSessionId: 'run_wrong_board_window',
    );

    expect(result.status, ValidationDispatchStatus.rejected);
    expect(
      repo.persistedValidatedRuns.single.rejectionReason,
      'ticket_board_window_mismatch',
    );
  });

  test(
    'declared compressed replay above limit is rejected before load',
    () async {
      final session = _session(
        runSessionId: 'run_compressed_limit',
        mode: RunMode.practice,
        seed: 21,
        digest: 'e' * 64,
        contentLengthBytes: 5,
        validationAttempt: 1,
      );
      final repo = _FakeRunSessionRepository(
        leaseResult: RunSessionLeaseAcquireResult(
          status: RunSessionLeaseStatus.acquired,
          session: session,
        ),
      );
      final worker = DeterministicValidatorWorker(
        replayLoader: _FakeReplayLoader(bytesByRunSession: const {}),
        boardRepository: _FakeBoardRepository(),
        runSessionRepository: repo,
        metrics: _FakeValidatorMetrics(),
        limits: const ReplayValidationLimits(
          maxCompressedBytes: 4,
          maxExpandedBytes: 4,
        ),
      );

      final result = await worker.validateRunSession(
        runSessionId: session.runSessionId,
      );

      expect(result.status, ValidationDispatchStatus.rejected);
      expect(
        repo.persistedValidatedRuns.single.rejectionReason,
        'replay_compressed_size_limit_exceeded',
      );
    },
  );

  test('gzip replay exceeding expanded limit is rejected', () async {
    final replayBlob = ReplayBlobV1.withComputedDigest(
      runSessionId: 'run_expanded_limit',
      tickHz: 60,
      seed: 22,
      levelId: 'field',
      playerCharacterId: 'eloise',
      loadoutSnapshot: _defaultLoadoutSnapshot(),
      totalTicks: 0,
      commandStream: const <ReplayCommandFrameV1>[],
    );
    final replayBytes = utf8.encode(jsonEncode(replayBlob.toJson()));
    final compressed = gzip.encode(replayBytes);
    expect(replayBytes.length, greaterThan(compressed.length));
    final repo = _FakeRunSessionRepository(
      leaseResult: RunSessionLeaseAcquireResult(
        status: RunSessionLeaseStatus.acquired,
        session: _session(
          runSessionId: replayBlob.runSessionId,
          mode: RunMode.practice,
          seed: replayBlob.seed,
          digest: replayBlob.canonicalSha256,
          contentLengthBytes: compressed.length,
          validationAttempt: 1,
        ),
      ),
    );
    final worker = DeterministicValidatorWorker(
      replayLoader: _FakeReplayLoader(
        bytesByRunSession: <String, List<int>>{
          replayBlob.runSessionId: compressed,
        },
      ),
      boardRepository: _FakeBoardRepository(),
      runSessionRepository: repo,
      metrics: _FakeValidatorMetrics(),
      limits: ReplayValidationLimits(
        maxCompressedBytes: compressed.length,
        maxExpandedBytes: compressed.length,
      ),
    );

    final result = await worker.validateRunSession(
      runSessionId: replayBlob.runSessionId,
    );

    expect(result.status, ValidationDispatchStatus.rejected);
    expect(
      repo.persistedValidatedRuns.single.rejectionReason,
      'replay_expanded_size_limit_exceeded',
    );
  });

  test(
    'command frame count above limit is rejected before simulation',
    () async {
      final replayBlob = ReplayBlobV1.withComputedDigest(
        runSessionId: 'run_frame_limit',
        tickHz: 60,
        seed: 23,
        levelId: 'field',
        playerCharacterId: 'eloise',
        loadoutSnapshot: _defaultLoadoutSnapshot(),
        totalTicks: 2,
        commandStream: <ReplayCommandFrameV1>[
          ReplayCommandFrameV1(tick: 1),
          ReplayCommandFrameV1(tick: 2),
        ],
      );
      final replayBytes = utf8.encode(jsonEncode(replayBlob.toJson()));
      final repo = _FakeRunSessionRepository(
        leaseResult: RunSessionLeaseAcquireResult(
          status: RunSessionLeaseStatus.acquired,
          session: _session(
            runSessionId: replayBlob.runSessionId,
            mode: RunMode.practice,
            seed: replayBlob.seed,
            digest: replayBlob.canonicalSha256,
            contentLengthBytes: replayBytes.length,
            validationAttempt: 1,
          ),
        ),
      );
      final worker = DeterministicValidatorWorker(
        replayLoader: _FakeReplayLoader(
          bytesByRunSession: <String, List<int>>{
            replayBlob.runSessionId: replayBytes,
          },
        ),
        boardRepository: _FakeBoardRepository(),
        runSessionRepository: repo,
        metrics: _FakeValidatorMetrics(),
        limits: const ReplayValidationLimits(maxCommandFrames: 1),
      );

      final result = await worker.validateRunSession(
        runSessionId: replayBlob.runSessionId,
      );

      expect(result.status, ValidationDispatchStatus.rejected);
      expect(
        repo.persistedValidatedRuns.single.rejectionReason,
        'replay_frame_limit_exceeded',
      );
    },
  );

  test('JSON nesting above limit is rejected before protocol decode', () async {
    final replayBytes = utf8.encode('{"ignored":[[[[[]]]]]}');
    final session = _session(
      runSessionId: 'run_json_nesting_limit',
      mode: RunMode.practice,
      seed: 25,
      digest: 'f' * 64,
      contentLengthBytes: replayBytes.length,
      validationAttempt: 1,
    );
    final repo = _FakeRunSessionRepository(
      leaseResult: RunSessionLeaseAcquireResult(
        status: RunSessionLeaseStatus.acquired,
        session: session,
      ),
    );
    final worker = DeterministicValidatorWorker(
      replayLoader: _FakeReplayLoader(
        bytesByRunSession: <String, List<int>>{
          session.runSessionId: replayBytes,
        },
      ),
      boardRepository: _FakeBoardRepository(),
      runSessionRepository: repo,
      metrics: _FakeValidatorMetrics(),
      limits: const ReplayValidationLimits(maxJsonNestingDepth: 4),
    );

    final result = await worker.validateRunSession(
      runSessionId: session.runSessionId,
    );

    expect(result.status, ValidationDispatchStatus.rejected);
    expect(
      repo.persistedValidatedRuns.single.rejectionReason,
      'replay_json_nesting_limit_exceeded',
    );
  });

  test('simulation wall-time limit rejects runaway replay', () async {
    final replayBlob = ReplayBlobV1.withComputedDigest(
      runSessionId: 'run_wall_limit',
      tickHz: 60,
      seed: 24,
      levelId: 'field',
      playerCharacterId: 'eloise',
      loadoutSnapshot: _defaultLoadoutSnapshot(),
      totalTicks: 300,
      commandStream: const <ReplayCommandFrameV1>[],
    );
    final replayBytes = utf8.encode(jsonEncode(replayBlob.toJson()));
    final repo = _FakeRunSessionRepository(
      leaseResult: RunSessionLeaseAcquireResult(
        status: RunSessionLeaseStatus.acquired,
        session: _session(
          runSessionId: replayBlob.runSessionId,
          mode: RunMode.practice,
          seed: replayBlob.seed,
          digest: replayBlob.canonicalSha256,
          contentLengthBytes: replayBytes.length,
          validationAttempt: 1,
        ),
      ),
    );
    var monotonicReadCount = 0;
    final worker = DeterministicValidatorWorker(
      replayLoader: _FakeReplayLoader(
        bytesByRunSession: <String, List<int>>{
          replayBlob.runSessionId: replayBytes,
        },
      ),
      boardRepository: _FakeBoardRepository(),
      runSessionRepository: repo,
      metrics: _FakeValidatorMetrics(),
      limits: const ReplayValidationLimits(
        maxSimulationWallTime: Duration(milliseconds: 1),
      ),
      monotonicClockMicros: () {
        monotonicReadCount += 1;
        return monotonicReadCount == 1 ? 0 : 2000;
      },
    );

    final result = await worker.validateRunSession(
      runSessionId: replayBlob.runSessionId,
    );

    expect(result.status, ValidationDispatchStatus.rejected);
    expect(
      repo.persistedValidatedRuns.single.rejectionReason,
      'simulation_time_limit_exceeded',
    );
  });

  test('transient failure records repair eligibility for lost tasks', () async {
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
      metrics: _FakeValidatorMetrics(),
      clockMs: () => 1_000,
    );

    final result = await worker.validateRunSession(runSessionId: 'run_retry');

    expect(result.status, ValidationDispatchStatus.retryScheduled);
    expect(repo.pendingRetryWrites, hasLength(1));
    expect(repo.pendingRetryWrites.single.nextAttemptAtMs, 901000);
    expect(
      repo.pendingRetryWrites.single.message,
      isNot(contains('temporary storage outage')),
    );
    expect(repo.terminalWrites, isEmpty);
  });

  test('accepted runs cannot bypass the settlement handoff', () async {
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
    final worker = DeterministicValidatorWorker(
      replayLoader: loader,
      boardRepository: _FakeBoardRepository(),
      runSessionRepository: repo,
      metrics: _FakeValidatorMetrics(),
      clockMs: () => 1000,
    );

    final result = await worker.validateRunSession(
      runSessionId: replayBlob.runSessionId,
    );

    expect(result.status, ValidationDispatchStatus.accepted);
    expect(repo.acceptedSettlementHandoffs, hasLength(1));
    expect(repo.persistedValidatedRuns, isEmpty);
    expect(repo.terminalWrites, isEmpty);
  });

  test(
    'attempt budget exhaustion enters internal-error grace window',
    () async {
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
      final worker = DeterministicValidatorWorker(
        replayLoader: loader,
        boardRepository: _FakeBoardRepository(),
        runSessionRepository: repo,
        metrics: _FakeValidatorMetrics(),
        clockMs: () => 1_000,
      );

      final result = await worker.validateRunSession(
        runSessionId: 'run_exhausted',
      );

      expect(result.status, ValidationDispatchStatus.retryScheduled);
      expect(repo.pendingRetryWrites, hasLength(1));
      expect(repo.pendingRetryWrites.single.internalErrorFirstAtMs, 1000);
      expect(repo.terminalWrites, isEmpty);
    },
  );

  test(
    'grace window expiry auto-revokes and terminalizes internal_error',
    () async {
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
      final worker = DeterministicValidatorWorker(
        replayLoader: loader,
        boardRepository: _FakeBoardRepository(),
        runSessionRepository: repo,
        metrics: _FakeValidatorMetrics(),
        internalErrorGraceWindow: const Duration(seconds: 1),
        clockMs: () => 3000,
      );

      final result = await worker.validateRunSession(
        runSessionId: 'run_grace_expired',
      );

      expect(result.status, ValidationDispatchStatus.rejected);
      expect(repo.pendingRetryWrites, isEmpty);
      expect(repo.terminalWrites, hasLength(1));
      expect(
        repo.terminalWrites.single.terminalState,
        RunSessionTerminalState.internalError,
      );
      expect(
        repo.terminalWrites.single.message,
        isNot(contains('persistent failure')),
      );
    },
  );

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
    final worker = DeterministicValidatorWorker(
      replayLoader: loader,
      boardRepository: _FakeBoardRepository(),
      runSessionRepository: repo,
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
  int issuedAtMs = 1,
  int? expiresAtMs,
  int finalizedAtMs = 2,
  int? boardOpensAtMs,
  int? boardClosesAtMs,
  String? storageGeneration = '123',
  String? ticketRunSessionId,
  String gameCompatVersion = '2026.03.0',
  String? rulesetVersion,
  String? scoreVersion,
  String? ghostVersion,
  String? loadoutDigest,
  int tickHz = 60,
}) {
  assert(
    ReplayDigest.isValidSha256Hex(digest),
    'Digest must be valid SHA-256 hex.',
  );
  final boardKey = mode.requiresBoard
      ? BoardKey(
          mode: mode,
          levelId: 'field',
          windowId: '2026-07',
          rulesetVersion: rulesetVersion ?? 'rules-v1',
          scoreVersion: scoreVersion ?? 'score-v1',
        )
      : null;
  return ValidatorRunSession(
    runSessionId: runSessionId,
    uid: 'uid_1',
    runTicket: RunTicket(
      runSessionId: ticketRunSessionId ?? runSessionId,
      uid: 'uid_1',
      mode: mode,
      boardId: mode.requiresBoard ? 'board_1' : null,
      boardKey: boardKey,
      seed: seed,
      tickHz: tickHz,
      gameCompatVersion: gameCompatVersion,
      rulesetVersion: mode.requiresBoard ? rulesetVersion ?? 'rules-v1' : null,
      scoreVersion: mode.requiresBoard ? scoreVersion ?? 'score-v1' : null,
      ghostVersion: mode.requiresBoard ? ghostVersion ?? 'ghost-v1' : null,
      boardOpensAtMs: mode.requiresBoard
          ? boardOpensAtMs ?? issuedAtMs - 1
          : null,
      boardClosesAtMs: mode.requiresBoard
          ? boardClosesAtMs ?? issuedAtMs + 1
          : null,
      levelId: 'field',
      playerCharacterId: 'eloise',
      loadoutSnapshot: _defaultLoadoutSnapshot(),
      loadoutDigest:
          loadoutDigest ??
          ReplayDigest.canonicalSha256ForMap(_defaultLoadoutSnapshot()),
      issuedAtMs: issuedAtMs,
      expiresAtMs:
          expiresAtMs ?? issuedAtMs + const Duration(hours: 24).inMilliseconds,
      singleUseNonce: 'nonce',
    ),
    uploadedReplay: UploadedReplayRef(
      objectPath:
          'replay-submissions/pending/uid_1/$runSessionId/replay.bin.gz',
      canonicalSha256: digest,
      contentLengthBytes: contentLengthBytes,
      finalizedAtMs: finalizedAtMs,
      contentType: 'application/octet-stream',
      storageGeneration: storageGeneration,
    ),
    validationAttempt: validationAttempt,
    validationLease: const ValidationLease(
      token: 'lease-token-1',
      expiresAtMs: 1000000,
    ),
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
  _FakeRunSessionRepository({
    required this.leaseResult,
    this.acceptedHandoffError,
  });

  final RunSessionLeaseAcquireResult leaseResult;
  final Object? acceptedHandoffError;
  final List<ValidatedRun> acceptedSettlementHandoffs = <ValidatedRun>[];
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
  Future<void> handoffAcceptedRunForSettlement({
    required ValidatedRun validatedRun,
    required String validationLeaseToken,
  }) async {
    expect(validationLeaseToken, 'lease-token-1');
    if (acceptedHandoffError != null) {
      throw acceptedHandoffError!;
    }
    acceptedSettlementHandoffs.add(validatedRun);
  }

  @override
  Future<void> handoffRejectedRun({
    required ValidatedRun validatedRun,
    required String validationLeaseToken,
    required String publicMessage,
  }) async {
    expect(validationLeaseToken, 'lease-token-1');
    persistedValidatedRuns.add(validatedRun);
    terminalWrites.add(
      _TerminalWrite(
        runSessionId: validatedRun.runSessionId,
        terminalState: RunSessionTerminalState.rejected,
        message: publicMessage,
      ),
    );
  }

  @override
  Future<void> handoffInternalError({
    required String runSessionId,
    required String validationLeaseToken,
    required String publicMessage,
  }) async {
    expect(validationLeaseToken, 'lease-token-1');
    terminalWrites.add(
      _TerminalWrite(
        runSessionId: runSessionId,
        terminalState: RunSessionTerminalState.internalError,
        message: publicMessage,
      ),
    );
  }

  @override
  Future<void> markPendingValidationRetry({
    required String runSessionId,
    required String validationLeaseToken,
    required int nextAttemptAtMs,
    required String message,
    int? internalErrorFirstAtMs,
  }) async {
    expect(validationLeaseToken, 'lease-token-1');
    pendingRetryWrites.add(
      _PendingRetryWrite(
        runSessionId: runSessionId,
        nextAttemptAtMs: nextAttemptAtMs,
        message: message,
        internalErrorFirstAtMs: internalErrorFirstAtMs,
      ),
    );
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
    required String storageGeneration,
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
      storageGeneration: storageGeneration,
      bytes: bytes,
    );
  }
}

class _FakeValidatedReplayArchiver implements ValidatedReplayArchiver {
  final List<String> runSessionIds = <String>[];

  @override
  Future<ArchivedValidatedReplay> archive({
    required String runSessionId,
    required String sourceObjectPath,
    required String sourceStorageGeneration,
  }) async {
    runSessionIds.add(runSessionId);
    return ArchivedValidatedReplay(
      objectPath: 'replay-submissions/validated/$runSessionId.bin.gz',
      storageGeneration: '456',
    );
  }
}

class _FakeBoardRepository implements BoardRepository {
  const _FakeBoardRepository();

  @override
  Future<Map<String, Object?>?> loadBoard({required String boardId}) async {
    return null;
  }
}

class _FakeSettlementDispatcher implements SettlementDispatcher {
  _FakeSettlementDispatcher({this.error});

  final Object? error;
  final List<String> runSessionIds = <String>[];

  @override
  Future<SettlementDispatchOutcome> dispatch({
    required String runSessionId,
  }) async {
    runSessionIds.add(runSessionId);
    if (error != null) {
      throw error!;
    }
    return SettlementDispatchOutcome.settled;
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
    int? durationMs,
    String? errorClass,
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
