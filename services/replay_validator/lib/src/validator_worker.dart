import 'dart:convert';
import 'dart:io';

import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/accessories/accessory_id.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/scoring/run_score_breakdown.dart';
import 'package:runner_core/spellBook/spell_book_id.dart';
import 'package:runner_core/tuning/score_tuning.dart';
import 'package:runner_core/weapons/weapon_id.dart';
import 'package:run_protocol/codecs/canonical_json_codec.dart';
import 'package:run_protocol/replay_blob.dart';
import 'package:run_protocol/replay_digest.dart';
import 'package:run_protocol/run_duration.dart';
import 'package:run_protocol/validated_run.dart';

import 'board_repository.dart';
import 'metrics.dart';
import 'replay_loader.dart';
import 'replay_validation_limits.dart';
import 'run_session_repository.dart';
import 'settlement_dispatcher.dart';

enum ValidationDispatchStatus {
  accepted,
  rejected,
  badRequest,
  retryScheduled,
  notImplemented,
}

class ValidationDispatchResult {
  const ValidationDispatchResult(this.status, {this.message});

  const ValidationDispatchResult.accepted({this.message})
    : status = ValidationDispatchStatus.accepted;

  const ValidationDispatchResult.rejected({this.message})
    : status = ValidationDispatchStatus.rejected;

  const ValidationDispatchResult.badRequest({this.message})
    : status = ValidationDispatchStatus.badRequest;

  const ValidationDispatchResult.retryScheduled({this.message})
    : status = ValidationDispatchStatus.retryScheduled;

  const ValidationDispatchResult.notImplemented({this.message})
    : status = ValidationDispatchStatus.notImplemented;

  final ValidationDispatchStatus status;
  final String? message;
}

abstract class ValidatorWorker {
  Future<ValidationDispatchResult> validateRunSession({
    required String runSessionId,
  });
}

class DeterministicValidatorWorker implements ValidatorWorker {
  DeterministicValidatorWorker({
    required this.replayLoader,
    required this.boardRepository,
    required this.runSessionRepository,
    required this.metrics,
    SettlementDispatcher? settlementDispatcher,
    this.maxRetryAttempts = 8,
    this.internalErrorGraceWindow = const Duration(hours: 1),
    this.incidentModeAutoRevokePaused = false,
    this.incidentModeRetryDelay = const Duration(minutes: 15),
    this.orphanedTaskRepairDelay = const Duration(minutes: 15),
    this.limits = const ReplayValidationLimits(),
    int Function()? clockMs,
    int Function()? monotonicClockMicros,
  }) : settlementDispatcher =
           settlementDispatcher ?? const NoopSettlementDispatcher(),
       _clockMs = clockMs ?? _defaultClockMs,
       _monotonicClockMicros =
           monotonicClockMicros ?? _defaultMonotonicClockMicros {
    limits.validate();
    if (orphanedTaskRepairDelay <= Duration.zero) {
      throw ArgumentError.value(
        orphanedTaskRepairDelay,
        'orphanedTaskRepairDelay',
        'must be positive',
      );
    }
  }

  final ReplayLoader replayLoader;
  final BoardRepository boardRepository;
  final RunSessionRepository runSessionRepository;
  final ValidatorMetrics metrics;
  final SettlementDispatcher settlementDispatcher;
  final int maxRetryAttempts;
  final Duration internalErrorGraceWindow;
  final bool incidentModeAutoRevokePaused;
  final Duration incidentModeRetryDelay;
  final Duration orphanedTaskRepairDelay;
  final ReplayValidationLimits limits;
  final int Function() _clockMs;
  final int Function() _monotonicClockMicros;

  static const Duration _ticketValidity = Duration(hours: 24);
  static const Duration _allowedAuthorityClockSkew = Duration(minutes: 5);
  static const Set<String> _supportedGameCompatVersions = <String>{'2026.03.0'};
  static const Set<String> _supportedRulesetVersions = <String>{'rules-v1'};
  static const Set<String> _supportedScoreVersions = <String>{'score-v1'};
  static const Set<String> _supportedGhostVersions = <String>{'ghost-v1'};

  @override
  Future<ValidationDispatchResult> validateRunSession({
    required String runSessionId,
  }) async {
    final normalizedRunSessionId = runSessionId.trim();
    if (normalizedRunSessionId.isEmpty) {
      await metrics.recordDispatch(
        runSessionId: runSessionId,
        status: ValidationDispatchStatus.badRequest.name,
        phase: 'input',
        message: 'runSessionId must be non-empty.',
      );
      return const ValidationDispatchResult.badRequest(
        message: 'runSessionId must be non-empty.',
      );
    }

    final lease = await runSessionRepository.acquireValidationLease(
      runSessionId: normalizedRunSessionId,
    );
    if (lease.status != RunSessionLeaseStatus.acquired ||
        lease.session == null) {
      final message =
          lease.message ??
          _leaseStatusMessage(lease.status, normalizedRunSessionId);
      final retryableLease =
          lease.status == RunSessionLeaseStatus.alreadyValidating;
      await metrics.recordDispatch(
        runSessionId: normalizedRunSessionId,
        status: retryableLease
            ? ValidationDispatchStatus.retryScheduled.name
            : ValidationDispatchStatus.accepted.name,
        phase: 'lease',
        message: message,
      );
      return retryableLease
          ? ValidationDispatchResult.retryScheduled(message: message)
          : ValidationDispatchResult.accepted(message: message);
    }

    final session = lease.session!;
    final validationLease = session.validationLease;
    if (validationLease == null) {
      const message = 'Acquired validation session is missing lease fencing.';
      await metrics.recordDispatch(
        runSessionId: normalizedRunSessionId,
        status: ValidationDispatchStatus.retryScheduled.name,
        phase: 'lease',
        message: message,
      );
      return const ValidationDispatchResult.retryScheduled(message: message);
    }
    final validationLeaseToken = validationLease.token;
    final mode = session.runTicket.mode.name;
    final attempt = session.validationAttempt;
    try {
      final validationNowMs = _clockMs();
      _validateTicketTimeAuthority(
        session: session,
        validationNowMs: validationNowMs,
      );
      _validateTicketIdentityAndCompatibility(session);
      _validateTicketBoardWindow(session: session);
      final replayBlob = await _loadAndDecodeReplayBlob(session);
      _validateReplayAgainstSession(replayBlob: replayBlob, session: session);

      final acceptedRun = _replayDeterministically(
        replayBlob: replayBlob,
        session: session,
      );
      try {
        await runSessionRepository.handoffAcceptedRunForSettlement(
          validatedRun: acceptedRun,
          validationLeaseToken: validationLeaseToken,
        );
      } on StaleValidationLeaseException {
        return _recordStaleLeaseRetry(
          runSessionId: normalizedRunSessionId,
          mode: mode,
          attempt: attempt,
          operation: 'accepted handoff',
        );
      }
      await metrics.recordDispatch(
        runSessionId: normalizedRunSessionId,
        status: ValidationDispatchStatus.accepted.name,
        phase: 'settlement_handoff',
        mode: mode,
        attempt: attempt,
        durationMs: _clockMs() - session.uploadedReplay.finalizedAtMs,
      );
      await _requestImmediateSettlement(
        runSessionId: normalizedRunSessionId,
        mode: mode,
        attempt: attempt,
      );
      await metrics.recordDispatch(
        runSessionId: normalizedRunSessionId,
        status: ValidationDispatchStatus.accepted.name,
        phase: 'terminal',
        mode: mode,
        attempt: attempt,
      );
      return const ValidationDispatchResult.accepted();
    } on _ValidationRejectedException catch (rejection) {
      final rejectedRun = _buildRejectedRun(
        session: session,
        rejectionReason: rejection.reason,
        rejectionMessage: rejection.message,
      );
      try {
        await runSessionRepository.handoffRejectedRun(
          validatedRun: rejectedRun,
          validationLeaseToken: validationLeaseToken,
          publicMessage: rejection.message,
        );
      } on StaleValidationLeaseException {
        return _recordStaleLeaseRetry(
          runSessionId: normalizedRunSessionId,
          mode: mode,
          attempt: attempt,
          operation: 'rejected handoff',
        );
      }
      await metrics.recordDispatch(
        runSessionId: normalizedRunSessionId,
        status: ValidationDispatchStatus.rejected.name,
        phase: 'terminal',
        mode: mode,
        attempt: attempt,
        rejectionReason: rejection.reason,
        message: rejection.message,
      );
      return ValidationDispatchResult.rejected(message: rejection.message);
    } catch (error) {
      final exhausted = attempt >= maxRetryAttempts;
      final message = 'validator failure on attempt $attempt: $error';
      if (exhausted) {
        final nowMs = _clockMs();
        final graceStartMs = session.internalErrorFirstAtMs ?? nowMs;
        final graceWindowMs = internalErrorGraceWindow.inMilliseconds;
        final graceDeadlineMs = graceStartMs + graceWindowMs;

        if (incidentModeAutoRevokePaused) {
          final nextAttemptAtMs = nowMs + incidentModeRetryDelay.inMilliseconds;
          try {
            await runSessionRepository.markPendingValidationRetry(
              runSessionId: normalizedRunSessionId,
              validationLeaseToken: validationLeaseToken,
              nextAttemptAtMs: nextAttemptAtMs,
              message:
                  'Replay verification is delayed during an active incident.',
              internalErrorFirstAtMs: graceStartMs,
            );
          } on StaleValidationLeaseException {
            return _recordStaleLeaseRetry(
              runSessionId: normalizedRunSessionId,
              mode: mode,
              attempt: attempt,
              operation: 'incident retry release',
            );
          }
          await metrics.recordDispatch(
            runSessionId: normalizedRunSessionId,
            status: ValidationDispatchStatus.retryScheduled.name,
            phase: 'incident_mode_pause',
            mode: mode,
            attempt: attempt,
            rejectionReason: RunSessionTerminalState.internalError.wireValue,
            message:
                '$message; incidentMode=true; graceStartAtMs=$graceStartMs; '
                'nextAttemptAtMs=$nextAttemptAtMs',
          );
          return ValidationDispatchResult.retryScheduled(message: message);
        }

        if (graceWindowMs > 0 && nowMs < graceDeadlineMs) {
          try {
            await runSessionRepository.markPendingValidationRetry(
              runSessionId: normalizedRunSessionId,
              validationLeaseToken: validationLeaseToken,
              nextAttemptAtMs: graceDeadlineMs,
              message: 'Replay verification is temporarily delayed.',
              internalErrorFirstAtMs: graceStartMs,
            );
          } on StaleValidationLeaseException {
            return _recordStaleLeaseRetry(
              runSessionId: normalizedRunSessionId,
              mode: mode,
              attempt: attempt,
              operation: 'grace retry release',
            );
          }
          await metrics.recordDispatch(
            runSessionId: normalizedRunSessionId,
            status: ValidationDispatchStatus.retryScheduled.name,
            phase: 'internal_error_grace',
            mode: mode,
            attempt: attempt,
            rejectionReason: RunSessionTerminalState.internalError.wireValue,
            message:
                '$message; graceStartAtMs=$graceStartMs; '
                'graceDeadlineAtMs=$graceDeadlineMs',
          );
          return ValidationDispatchResult.retryScheduled(message: message);
        }

        try {
          await runSessionRepository.handoffInternalError(
            runSessionId: normalizedRunSessionId,
            validationLeaseToken: validationLeaseToken,
            publicMessage: 'Replay verification could not be completed.',
          );
        } on StaleValidationLeaseException {
          return _recordStaleLeaseRetry(
            runSessionId: normalizedRunSessionId,
            mode: mode,
            attempt: attempt,
            operation: 'internal-error handoff',
          );
        }
        await metrics.recordDispatch(
          runSessionId: normalizedRunSessionId,
          status: ValidationDispatchStatus.rejected.name,
          phase: 'terminal',
          mode: mode,
          attempt: attempt,
          rejectionReason: RunSessionTerminalState.internalError.wireValue,
          message: message,
        );
        return ValidationDispatchResult.rejected(message: message);
      }

      final nextAttemptAtMs =
          _clockMs() + orphanedTaskRepairDelay.inMilliseconds;
      try {
        await runSessionRepository.markPendingValidationRetry(
          runSessionId: normalizedRunSessionId,
          validationLeaseToken: validationLeaseToken,
          nextAttemptAtMs: nextAttemptAtMs,
          message: 'Replay verification is temporarily delayed.',
          internalErrorFirstAtMs: null,
        );
      } on StaleValidationLeaseException {
        return _recordStaleLeaseRetry(
          runSessionId: normalizedRunSessionId,
          mode: mode,
          attempt: attempt,
          operation: 'retry release',
        );
      }
      await metrics.recordDispatch(
        runSessionId: normalizedRunSessionId,
        status: ValidationDispatchStatus.retryScheduled.name,
        phase: 'retry',
        mode: mode,
        attempt: attempt,
        message:
            '$message; repairEligibleAtMs=$nextAttemptAtMs; '
            'ordinary retries are owned by Cloud Tasks',
      );
      return ValidationDispatchResult.retryScheduled(message: message);
    }
  }

  Future<ValidationDispatchResult> _recordStaleLeaseRetry({
    required String runSessionId,
    required String mode,
    required int attempt,
    required String operation,
  }) async {
    final message =
        'Validation lease changed during $operation; task retry is required.';
    await metrics.recordDispatch(
      runSessionId: runSessionId,
      status: ValidationDispatchStatus.retryScheduled.name,
      phase: 'lease_conflict',
      mode: mode,
      attempt: attempt,
      message: message,
    );
    return ValidationDispatchResult.retryScheduled(message: message);
  }

  Future<void> _requestImmediateSettlement({
    required String runSessionId,
    required String mode,
    required int attempt,
  }) async {
    final startedAtMs = _clockMs();
    await metrics.recordDispatch(
      runSessionId: runSessionId,
      status: ValidationDispatchStatus.accepted.name,
      phase: 'settlement_dispatch_start',
      mode: mode,
      attempt: attempt,
    );
    try {
      final outcome = await settlementDispatcher.dispatch(
        runSessionId: runSessionId,
      );
      await metrics.recordDispatch(
        runSessionId: runSessionId,
        status: ValidationDispatchStatus.accepted.name,
        phase: switch (outcome) {
          SettlementDispatchOutcome.disabled => 'settlement_dispatch_disabled',
          _ => 'settlement_dispatch_outcome',
        },
        mode: mode,
        attempt: attempt,
        durationMs: _clockMs() - startedAtMs,
        message: 'outcome=${outcome.name}',
      );
    } catch (error) {
      // The handoff is already durable. Eventarc and repair own retrying payout.
      await metrics.recordDispatch(
        runSessionId: runSessionId,
        status: ValidationDispatchStatus.accepted.name,
        phase: 'settlement_dispatch_fallback',
        mode: mode,
        attempt: attempt,
        durationMs: _clockMs() - startedAtMs,
        errorClass: error.runtimeType.toString(),
      );
    }
  }

  void _validateTicketTimeAuthority({
    required ValidatorRunSession session,
    required int validationNowMs,
  }) {
    final ticket = session.runTicket;
    if (ticket.issuedAtMs <= 0 || ticket.expiresAtMs <= ticket.issuedAtMs) {
      throw const _ValidationRejectedException(
        reason: 'ticket_time_range_invalid',
        message:
            'Run ticket issue and expiry timestamps do not form a valid range.',
      );
    }
    if (ticket.expiresAtMs - ticket.issuedAtMs !=
        _ticketValidity.inMilliseconds) {
      throw const _ValidationRejectedException(
        reason: 'ticket_expiry_duration_invalid',
        message: 'Run ticket expiry duration does not match protocol policy.',
      );
    }

    final latestAllowedAuthorityTimeMs =
        validationNowMs + _allowedAuthorityClockSkew.inMilliseconds;
    if (ticket.issuedAtMs > latestAllowedAuthorityTimeMs) {
      throw const _ValidationRejectedException(
        reason: 'ticket_issued_in_future',
        message:
            'Run ticket was issued beyond the allowed authority clock skew.',
      );
    }

    final finalizedAtMs = session.uploadedReplay.finalizedAtMs;
    if (finalizedAtMs < ticket.issuedAtMs) {
      throw const _ValidationRejectedException(
        reason: 'ticket_finalized_before_issue',
        message: 'Replay finalization predates run ticket issuance.',
      );
    }
    if (finalizedAtMs >= ticket.expiresAtMs) {
      throw const _ValidationRejectedException(
        reason: 'ticket_expired',
        message: 'Replay was finalized after the run ticket expired.',
      );
    }
    if (finalizedAtMs > latestAllowedAuthorityTimeMs) {
      throw const _ValidationRejectedException(
        reason: 'ticket_finalized_in_future',
        message:
            'Replay finalization is beyond the allowed authority clock skew.',
      );
    }
  }

  void _validateTicketIdentityAndCompatibility(ValidatorRunSession session) {
    final ticket = session.runTicket;
    if (ticket.runSessionId != session.runSessionId ||
        ticket.uid != session.uid) {
      throw const _ValidationRejectedException(
        reason: 'ticket_identity_mismatch',
        message: 'Run ticket identity does not match its stored session.',
      );
    }
    if (!_supportedGameCompatVersions.contains(ticket.gameCompatVersion)) {
      throw const _ValidationRejectedException(
        reason: 'game_compat_version_unsupported',
        message: 'Run ticket game compatibility version is not supported.',
      );
    }
    final computedLoadoutDigest = ReplayDigest.canonicalSha256ForMap(
      ticket.loadoutSnapshot,
    );
    if (ticket.loadoutDigest != computedLoadoutDigest) {
      throw const _ValidationRejectedException(
        reason: 'loadout_digest_mismatch',
        message: 'Run ticket loadout digest does not match its snapshot.',
      );
    }
    if (!ticket.mode.requiresBoard) {
      return;
    }
    final boardKey = ticket.boardKey;
    if (boardKey == null ||
        ticket.rulesetVersion != boardKey.rulesetVersion ||
        ticket.scoreVersion != boardKey.scoreVersion) {
      throw const _ValidationRejectedException(
        reason: 'ticket_board_version_mismatch',
        message: 'Run ticket board versions are internally inconsistent.',
      );
    }
    if (!_supportedRulesetVersions.contains(ticket.rulesetVersion) ||
        !_supportedScoreVersions.contains(ticket.scoreVersion) ||
        !_supportedGhostVersions.contains(ticket.ghostVersion)) {
      throw const _ValidationRejectedException(
        reason: 'board_compat_version_unsupported',
        message: 'Run ticket board compatibility version is not supported.',
      );
    }
  }

  void _validateTicketBoardWindow({required ValidatorRunSession session}) {
    final ticket = session.runTicket;
    if (!ticket.mode.requiresBoard) {
      return;
    }
    final opensAtMs = ticket.boardOpensAtMs;
    final closesAtMs = ticket.boardClosesAtMs;
    if (opensAtMs == null || closesAtMs == null || opensAtMs >= closesAtMs) {
      throw const _ValidationRejectedException(
        reason: 'board_window_invalid',
        message: 'Run ticket has invalid immutable board-window metadata.',
      );
    }
    if (ticket.issuedAtMs < opensAtMs || ticket.issuedAtMs >= closesAtMs) {
      throw const _ValidationRejectedException(
        reason: 'ticket_board_window_mismatch',
        message: 'Run ticket issuance is outside its bound board window.',
      );
    }
  }

  Future<ReplayBlobV1> _loadAndDecodeReplayBlob(
    ValidatorRunSession session,
  ) async {
    if (session.uploadedReplay.contentLengthBytes > limits.maxCompressedBytes) {
      throw const _ValidationRejectedException(
        reason: 'replay_compressed_size_limit_exceeded',
        message: 'Replay blob exceeds the compressed-size limit.',
      );
    }
    final storageGeneration = session.uploadedReplay.storageGeneration;
    if (storageGeneration == null ||
        !RegExp(r'^[1-9][0-9]*$').hasMatch(storageGeneration)) {
      throw const _ValidationRejectedException(
        reason: 'replay_generation_missing',
        message: 'Replay immutable storage generation is unavailable.',
      );
    }
    final LoadedReplay loaded;
    try {
      loaded = await replayLoader.loadReplay(
        runSessionId: session.runSessionId,
        objectPath: session.uploadedReplay.objectPath,
        storageGeneration: storageGeneration,
      );
    } on ReplayPayloadTooLargeException {
      throw const _ValidationRejectedException(
        reason: 'replay_compressed_size_limit_exceeded',
        message: 'Replay blob exceeds the compressed-size limit.',
      );
    } on ReplayGenerationUnavailableException {
      throw const _ValidationRejectedException(
        reason: 'replay_generation_unavailable',
        message: 'Finalized replay evidence is no longer available.',
      );
    }
    if (loaded.storageGeneration != storageGeneration) {
      throw const _ValidationRejectedException(
        reason: 'replay_generation_mismatch',
        message: 'Loaded replay generation does not match finalized evidence.',
      );
    }
    if (loaded.bytes.isEmpty) {
      throw const _ValidationRejectedException(
        reason: 'empty_replay_blob',
        message: 'Replay blob is empty.',
      );
    }
    if (loaded.bytes.length != session.uploadedReplay.contentLengthBytes) {
      throw _ValidationRejectedException(
        reason: 'content_length_mismatch',
        message:
            'Replay byte length ${loaded.bytes.length} does not match '
            'uploaded metadata ${session.uploadedReplay.contentLengthBytes}.',
      );
    }
    if (loaded.bytes.length > limits.maxCompressedBytes) {
      throw const _ValidationRejectedException(
        reason: 'replay_compressed_size_limit_exceeded',
        message: 'Replay blob exceeds the compressed-size limit.',
      );
    }
    final decodedBytes = await _maybeDecompressGzip(loaded.bytes);
    final decodedJson = _decodeJsonObject(decodedBytes);
    try {
      return ReplayBlobV1.fromJson(decodedJson, verifyDigest: true);
    } on FormatException catch (error) {
      throw _ValidationRejectedException(
        reason: 'protocol_invalid',
        message: 'Replay blob decode failed: ${error.message}',
      );
    } on ArgumentError {
      throw const _ValidationRejectedException(
        reason: 'protocol_invalid',
        message: 'Replay blob failed protocol validation.',
      );
    }
  }

  Future<List<int>> _maybeDecompressGzip(List<int> bytes) async {
    final isGzip = bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b;
    if (!isGzip) {
      if (bytes.length > limits.maxExpandedBytes) {
        throw const _ValidationRejectedException(
          reason: 'replay_expanded_size_limit_exceeded',
          message: 'Replay blob exceeds the expanded-size limit.',
        );
      }
      return bytes;
    }
    try {
      return await collectReplayBytes(
        gzip.decoder.bind(Stream<List<int>>.value(bytes)),
        maxBytes: limits.maxExpandedBytes,
      );
    } on ReplayPayloadTooLargeException {
      throw const _ValidationRejectedException(
        reason: 'replay_expanded_size_limit_exceeded',
        message: 'Replay blob exceeds the expanded-size limit.',
      );
    } catch (_) {
      throw const _ValidationRejectedException(
        reason: 'gzip_decode_failed',
        message: 'Replay gzip decode failed.',
      );
    }
  }

  Map<String, Object?> _decodeJsonObject(List<int> bytes) {
    try {
      final source = utf8.decode(bytes);
      _validateJsonNesting(source);
      final decoded = jsonDecode(source);
      if (decoded is! Map) {
        throw const _ValidationRejectedException(
          reason: 'protocol_invalid',
          message: 'Replay blob root must be a JSON object.',
        );
      }
      return Map<String, Object?>.from(decoded);
    } on _ValidationRejectedException {
      rethrow;
    } on FormatException catch (error) {
      throw _ValidationRejectedException(
        reason: 'json_decode_failed',
        message: 'Replay JSON decode failed: ${error.message}',
      );
    }
  }

  void _validateJsonNesting(String source) {
    var depth = 0;
    var inString = false;
    var escaped = false;
    for (final codeUnit in source.codeUnits) {
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (codeUnit == 0x5c) {
          escaped = true;
        } else if (codeUnit == 0x22) {
          inString = false;
        }
        continue;
      }
      if (codeUnit == 0x22) {
        inString = true;
        continue;
      }
      if (codeUnit == 0x7b || codeUnit == 0x5b) {
        depth += 1;
        if (depth > limits.maxJsonNestingDepth) {
          throw const _ValidationRejectedException(
            reason: 'replay_json_nesting_limit_exceeded',
            message: 'Replay JSON exceeds the nesting-depth limit.',
          );
        }
      } else if (codeUnit == 0x7d || codeUnit == 0x5d) {
        depth -= 1;
      }
    }
  }

  void _validateReplayAgainstSession({
    required ReplayBlobV1 replayBlob,
    required ValidatorRunSession session,
  }) {
    final ticket = session.runTicket;
    if (ticket.tickHz <= 0) {
      throw const _ValidationRejectedException(
        reason: 'invalid_tick_rate',
        message: 'Replay ticket tick rate must be positive.',
      );
    }
    if (replayBlob.commandStream.length > limits.maxCommandFrames) {
      throw const _ValidationRejectedException(
        reason: 'replay_frame_limit_exceeded',
        message: 'Replay command stream exceeds the frame-count limit.',
      );
    }
    final maxTotalTicks = ticket.tickHz * limits.maxRunDuration.inSeconds;
    if (replayBlob.totalTicks > maxTotalTicks) {
      throw const _ValidationRejectedException(
        reason: 'replay_duration_limit_exceeded',
        message: 'Replay duration exceeds the validation limit.',
      );
    }
    if (replayBlob.runSessionId != session.runSessionId) {
      throw _ValidationRejectedException(
        reason: 'run_session_mismatch',
        message:
            'Replay runSessionId "${replayBlob.runSessionId}" does not match '
            'session "${session.runSessionId}".',
      );
    }
    if (replayBlob.canonicalSha256 != session.uploadedReplay.canonicalSha256) {
      throw _ValidationRejectedException(
        reason: 'digest_mismatch',
        message:
            'Replay digest does not match uploaded metadata digest '
            '${session.uploadedReplay.canonicalSha256}.',
      );
    }
    if (replayBlob.tickHz != ticket.tickHz) {
      throw _ValidationRejectedException(
        reason: 'tick_hz_mismatch',
        message: 'Replay tickHz does not match ticket tickHz.',
      );
    }
    if (replayBlob.seed != ticket.seed) {
      throw _ValidationRejectedException(
        reason: 'seed_mismatch',
        message: 'Replay seed does not match ticket seed.',
      );
    }
    if (replayBlob.levelId != ticket.levelId) {
      throw _ValidationRejectedException(
        reason: 'level_mismatch',
        message: 'Replay levelId does not match ticket levelId.',
      );
    }
    if (replayBlob.playerCharacterId != ticket.playerCharacterId) {
      throw _ValidationRejectedException(
        reason: 'character_mismatch',
        message: 'Replay playerCharacterId does not match ticket.',
      );
    }
    final replayLoadout = canonicalJsonEncode(replayBlob.loadoutSnapshot);
    final ticketLoadout = canonicalJsonEncode(ticket.loadoutSnapshot);
    if (replayLoadout != ticketLoadout) {
      throw const _ValidationRejectedException(
        reason: 'loadout_mismatch',
        message: 'Replay loadoutSnapshot does not match ticket snapshot.',
      );
    }
    _validateModeAndBoardBinding(replayBlob: replayBlob, session: session);
    _validateCommandStream(replayBlob);
  }

  void _validateModeAndBoardBinding({
    required ReplayBlobV1 replayBlob,
    required ValidatorRunSession session,
  }) {
    final ticket = session.runTicket;
    if (!ticket.mode.requiresBoard) {
      if (replayBlob.boardId != null || replayBlob.boardKey != null) {
        throw const _ValidationRejectedException(
          reason: 'practice_board_binding_present',
          message: 'Practice replay must omit board binding fields.',
        );
      }
      return;
    }
    if (replayBlob.boardId == null || replayBlob.boardKey == null) {
      throw const _ValidationRejectedException(
        reason: 'ranked_board_binding_missing',
        message: 'Ranked replay must include board binding fields.',
      );
    }
    if (replayBlob.boardId != ticket.boardId) {
      throw const _ValidationRejectedException(
        reason: 'board_id_mismatch',
        message: 'Replay boardId does not match ticket boardId.',
      );
    }
    final replayBoardKeyJson = canonicalJsonEncode(
      replayBlob.boardKey!.toJson(),
    );
    final ticketBoardKeyJson = canonicalJsonEncode(ticket.boardKey!.toJson());
    if (replayBoardKeyJson != ticketBoardKeyJson) {
      throw const _ValidationRejectedException(
        reason: 'board_key_mismatch',
        message: 'Replay boardKey does not match ticket boardKey.',
      );
    }
  }

  void _validateCommandStream(ReplayBlobV1 replayBlob) {
    var previousTick = 0;
    var maxTick = 0;
    for (final frame in replayBlob.commandStream) {
      if (frame.tick <= previousTick) {
        throw _ValidationRejectedException(
          reason: 'non_monotonic_ticks',
          message:
              'Replay command ticks must be strictly increasing. Found '
              '${frame.tick} after $previousTick.',
        );
      }
      previousTick = frame.tick;
      if (frame.tick > maxTick) {
        maxTick = frame.tick;
      }
      final moveAxis = frame.moveAxis;
      if (moveAxis != null && (moveAxis < -1.0 || moveAxis > 1.0)) {
        throw _ValidationRejectedException(
          reason: 'move_axis_out_of_range',
          message: 'Replay moveAxis $moveAxis is outside [-1, 1].',
        );
      }
      final aimDirX = frame.aimDirX;
      final aimDirY = frame.aimDirY;
      if (aimDirX != null && (aimDirX < -1.0 || aimDirX > 1.0)) {
        throw _ValidationRejectedException(
          reason: 'aim_dir_x_out_of_range',
          message: 'Replay aimDirX $aimDirX is outside [-1, 1].',
        );
      }
      if (aimDirY != null && (aimDirY < -1.0 || aimDirY > 1.0)) {
        throw _ValidationRejectedException(
          reason: 'aim_dir_y_out_of_range',
          message: 'Replay aimDirY $aimDirY is outside [-1, 1].',
        );
      }
      final invalidHoldMask =
          frame.abilitySlotHeldValueMask & ~frame.abilitySlotHeldChangedMask;
      if (invalidHoldMask != 0) {
        throw const _ValidationRejectedException(
          reason: 'invalid_hold_mask',
          message:
              'abilitySlotHeldValueMask cannot set bits outside changed mask.',
        );
      }
    }
    if (replayBlob.totalTicks < maxTick) {
      throw _ValidationRejectedException(
        reason: 'total_ticks_too_small',
        message:
            'Replay totalTicks ${replayBlob.totalTicks} is less than command '
            'max tick $maxTick.',
      );
    }
  }

  ValidatedRun _replayDeterministically({
    required ReplayBlobV1 replayBlob,
    required ValidatorRunSession session,
  }) {
    final simulationStartedAtMicros = _monotonicClockMicros();
    final ticket = session.runTicket;
    final levelId = _enumByName(
      LevelId.values,
      ticket.levelId,
      fieldName: 'runTicket.levelId',
    );
    final characterId = _enumByName(
      PlayerCharacterId.values,
      ticket.playerCharacterId,
      fieldName: 'runTicket.playerCharacterId',
    );
    final loadout = _loadoutFromSnapshot(ticket.loadoutSnapshot);
    final core = GameCore(
      seed: ticket.seed,
      runId: 1,
      tickHz: ticket.tickHz,
      levelDefinition: LevelRegistry.byId(levelId),
      playerCharacter: PlayerCharacterRegistry.resolve(characterId),
      equippedLoadoutOverride: loadout,
    );

    final frameByTick = <int, ReplayCommandFrameV1>{
      for (final frame in replayBlob.commandStream) frame.tick: frame,
    };
    RunEndedEvent? runEnded;
    for (var tick = 1; tick <= replayBlob.totalTicks; tick += 1) {
      if (tick == 1 || tick % 256 == 0) {
        _throwIfSimulationDeadlineExceeded(simulationStartedAtMicros);
      }
      final frame = frameByTick[tick];
      final commands = frame == null
          ? const <Command>[]
          : _commandsFromReplayFrame(frame);
      core.applyCommands(commands);
      core.stepOneTick();
      runEnded = _extractRunEnded(core.drainEvents()) ?? runEnded;
      if (runEnded != null && core.gameOver) {
        break;
      }
    }

    if (runEnded == null) {
      if (!core.gameOver) {
        core.giveUp();
      }
      runEnded = _extractRunEnded(core.drainEvents()) ?? runEnded;
    }
    if (runEnded == null) {
      throw const _ValidationRejectedException(
        reason: 'missing_run_end',
        message: 'Replay execution did not produce a RunEndedEvent.',
      );
    }

    final breakdown = buildRunScoreBreakdown(
      tick: runEnded.tick,
      distanceUnits: runEnded.distance,
      collectibles: runEnded.stats.collectibles,
      collectibleScore: runEnded.stats.collectibleScore,
      enemyKillCounts: runEnded.stats.enemyKillCounts,
      tuning: core.scoreTuning,
      tickHz: core.tickHz,
    );
    return ValidatedRun(
      runSessionId: session.runSessionId,
      uid: session.uid,
      boardId: ticket.boardId,
      boardKey: ticket.boardKey,
      mode: ticket.mode,
      accepted: true,
      score: breakdown.totalPoints,
      distanceMeters: distanceUnitsToMeters(runEnded.distance),
      durationSeconds: canonicalRunDurationSeconds(
        tick: runEnded.tick,
        tickHz: core.tickHz,
      ),
      tick: runEnded.tick,
      endedReason: runEnded.reason.name,
      goldEarned: runEnded.goldEarned,
      stats: <String, Object?>{
        'collectibles': runEnded.stats.collectibles,
        'collectibleScore': runEnded.stats.collectibleScore,
        'enemyKillCounts': runEnded.stats.enemyKillCounts,
      },
      replayDigest: replayBlob.canonicalSha256,
      replayStorageRef: session.uploadedReplay.objectPath,
      replayStorageGeneration: session.uploadedReplay.storageGeneration,
      createdAtMs: _clockMs(),
    );
  }

  void _throwIfSimulationDeadlineExceeded(int startedAtMicros) {
    final elapsedMicros = _monotonicClockMicros() - startedAtMicros;
    if (elapsedMicros > limits.maxSimulationWallTime.inMicroseconds) {
      throw const _ValidationRejectedException(
        reason: 'simulation_time_limit_exceeded',
        message: 'Replay simulation exceeded the validation time limit.',
      );
    }
  }

  RunEndedEvent? _extractRunEnded(List<GameEvent> events) {
    RunEndedEvent? result;
    for (final event in events) {
      if (event is RunEndedEvent) {
        result = event;
      }
    }
    return result;
  }

  List<Command> _commandsFromReplayFrame(ReplayCommandFrameV1 frame) {
    final out = <Command>[];
    final tick = frame.tick;
    final moveAxis = frame.moveAxis;
    if (moveAxis != null && moveAxis != 0) {
      out.add(MoveAxisCommand(tick: tick, axis: moveAxis));
    }
    final aimDirX = frame.aimDirX;
    final aimDirY = frame.aimDirY;
    if (aimDirX != null && aimDirY != null) {
      out.add(AimDirCommand(tick: tick, x: aimDirX, y: aimDirY));
    }
    if (frame.jumpPressed) {
      out.add(JumpPressedCommand(tick: tick));
    }
    if (frame.dashPressed) {
      out.add(DashPressedCommand(tick: tick));
    }
    if (frame.strikePressed) {
      out.add(StrikePressedCommand(tick: tick));
    }
    if (frame.projectilePressed) {
      out.add(ProjectilePressedCommand(tick: tick));
    }
    if (frame.secondaryPressed) {
      out.add(SecondaryPressedCommand(tick: tick));
    }
    if (frame.spellPressed) {
      out.add(SpellPressedCommand(tick: tick));
    }
    final changedMask = frame.abilitySlotHeldChangedMask;
    if (changedMask != 0) {
      for (final slot in AbilitySlot.values) {
        final bit = 1 << slot.index;
        if ((changedMask & bit) == 0) {
          continue;
        }
        final held = (frame.abilitySlotHeldValueMask & bit) != 0;
        out.add(AbilitySlotHeldCommand(tick: tick, slot: slot, held: held));
      }
    }
    return out;
  }

  EquippedLoadoutDef _loadoutFromSnapshot(Map<String, Object?> snapshot) {
    return EquippedLoadoutDef(
      mask: _requiredInt(snapshot, 'mask'),
      mainWeaponId: _enumByName(
        WeaponId.values,
        _requiredString(snapshot, 'mainWeaponId'),
        fieldName: 'loadoutSnapshot.mainWeaponId',
      ),
      offhandWeaponId: _enumByName(
        WeaponId.values,
        _requiredString(snapshot, 'offhandWeaponId'),
        fieldName: 'loadoutSnapshot.offhandWeaponId',
      ),
      spellBookId: _enumByName(
        SpellBookId.values,
        _requiredString(snapshot, 'spellBookId'),
        fieldName: 'loadoutSnapshot.spellBookId',
      ),
      projectileSlotSpellId: _enumByName(
        ProjectileId.values,
        _requiredString(snapshot, 'projectileSlotSpellId'),
        fieldName: 'loadoutSnapshot.projectileSlotSpellId',
      ),
      accessoryId: _enumByName(
        AccessoryId.values,
        _requiredString(snapshot, 'accessoryId'),
        fieldName: 'loadoutSnapshot.accessoryId',
      ),
      abilityPrimaryId: _requiredString(snapshot, 'abilityPrimaryId'),
      abilitySecondaryId: _requiredString(snapshot, 'abilitySecondaryId'),
      abilityProjectileId: _requiredString(snapshot, 'abilityProjectileId'),
      abilitySpellId: _requiredString(snapshot, 'abilitySpellId'),
      abilityMobilityId: _requiredString(snapshot, 'abilityMobilityId'),
      abilityJumpId: _requiredString(snapshot, 'abilityJumpId'),
    );
  }

  T _enumByName<T extends Enum>(
    List<T> values,
    String raw, {
    required String fieldName,
  }) {
    for (final value in values) {
      if (value.name == raw) {
        return value;
      }
    }
    throw _ValidationRejectedException(
      reason: 'unsupported_enum_value',
      message: '$fieldName has unsupported value "$raw".',
    );
  }

  int _requiredInt(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    throw _ValidationRejectedException(
      reason: 'snapshot_missing_field',
      message: 'loadoutSnapshot.$key must be an integer.',
    );
  }

  String _requiredString(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    throw _ValidationRejectedException(
      reason: 'snapshot_missing_field',
      message: 'loadoutSnapshot.$key must be a non-empty string.',
    );
  }

  ValidatedRun _buildRejectedRun({
    required ValidatorRunSession session,
    required String rejectionReason,
    required String rejectionMessage,
  }) {
    final digest =
        ReplayDigest.isValidSha256Hex(session.uploadedReplay.canonicalSha256)
        ? session.uploadedReplay.canonicalSha256
        : ('0' * 64);
    return ValidatedRun(
      runSessionId: session.runSessionId,
      uid: session.uid,
      boardId: session.runTicket.boardId,
      boardKey: session.runTicket.boardKey,
      mode: session.runTicket.mode,
      accepted: false,
      rejectionReason: rejectionReason,
      score: 0,
      distanceMeters: 0,
      durationSeconds: 0,
      tick: 0,
      endedReason: 'rejected',
      goldEarned: 0,
      stats: <String, Object?>{'message': rejectionMessage},
      replayDigest: digest,
      replayStorageRef: session.uploadedReplay.objectPath,
      replayStorageGeneration: session.uploadedReplay.storageGeneration,
      createdAtMs: _clockMs(),
    );
  }

  String _leaseStatusMessage(
    RunSessionLeaseStatus status,
    String runSessionId,
  ) {
    return switch (status) {
      RunSessionLeaseStatus.acquired =>
        'runSessionId "$runSessionId" validation lease acquired.',
      RunSessionLeaseStatus.notFound =>
        'runSessionId "$runSessionId" was not found.',
      RunSessionLeaseStatus.alreadyTerminal =>
        'runSessionId "$runSessionId" is already terminal.',
      RunSessionLeaseStatus.alreadyValidating =>
        'runSessionId "$runSessionId" is already validating.',
      RunSessionLeaseStatus.invalidState =>
        'runSessionId "$runSessionId" is in an invalid validation state.',
    };
  }
}

class StubValidatorWorker implements ValidatorWorker {
  StubValidatorWorker({
    required this.replayLoader,
    required this.boardRepository,
    required this.runSessionRepository,
    required this.metrics,
  });

  final ReplayLoader replayLoader;
  final BoardRepository boardRepository;
  final RunSessionRepository runSessionRepository;
  final ValidatorMetrics metrics;

  @override
  Future<ValidationDispatchResult> validateRunSession({
    required String runSessionId,
  }) async {
    await metrics.recordDispatch(
      runSessionId: runSessionId,
      status: ValidationDispatchStatus.notImplemented.name,
      phase: 'dispatch',
      message: 'Validator algorithm implementation lands in Phase 4.',
    );
    return const ValidationDispatchResult.notImplemented(
      message: 'Validator algorithm implementation lands in Phase 4.',
    );
  }
}

final class _ValidationRejectedException implements Exception {
  const _ValidationRejectedException({
    required this.reason,
    required this.message,
  });

  final String reason;
  final String message;

  @override
  String toString() => 'ValidationRejected(reason=$reason, message=$message)';
}

int _defaultClockMs() => DateTime.now().millisecondsSinceEpoch;

final Stopwatch _processMonotonicClock = Stopwatch()..start();

int _defaultMonotonicClockMicros() =>
    _processMonotonicClock.elapsedMicroseconds;

int distanceUnitsToMeters(
  double distanceUnits, {
  int unitsPerMeter = kWorldUnitsPerMeter,
}) {
  if (unitsPerMeter <= 0 || distanceUnits <= 0) {
    return 0;
  }
  return (distanceUnits / unitsPerMeter).floor();
}
