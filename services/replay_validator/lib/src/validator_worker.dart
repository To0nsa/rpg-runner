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
import 'package:run_protocol/validated_run.dart';

import 'board_repository.dart';
import 'ghost_publisher.dart';
import 'leaderboard_projector.dart';
import 'metrics.dart';
import 'replay_loader.dart';
import 'reward_settlement_writer.dart';
import 'run_session_repository.dart';

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
    required this.leaderboardProjector,
    required this.rewardGrantWriter,
    required this.ghostPublisher,
    required this.metrics,
    this.enableRewardSettlementWrites = true,
    this.maxRetryAttempts = 8,
    this.internalErrorGraceWindow = const Duration(hours: 1),
    this.incidentModeAutoRevokePaused = false,
    this.incidentModeRetryDelay = const Duration(minutes: 15),
    List<Duration>? retryBackoffSchedule,
    int Function()? clockMs,
  }) : _retryBackoffSchedule =
           retryBackoffSchedule ?? _defaultRetryBackoffSchedule,
       _clockMs = clockMs ?? _defaultClockMs;

  final ReplayLoader replayLoader;
  final BoardRepository boardRepository;
  final RunSessionRepository runSessionRepository;
  final LeaderboardProjector leaderboardProjector;
  final RewardGrantWriter rewardGrantWriter;
  final GhostPublisher ghostPublisher;
  final ValidatorMetrics metrics;
  final bool enableRewardSettlementWrites;
  final int maxRetryAttempts;
  final Duration internalErrorGraceWindow;
  final bool incidentModeAutoRevokePaused;
  final Duration incidentModeRetryDelay;
  final List<Duration> _retryBackoffSchedule;
  final int Function() _clockMs;

  static const List<Duration> _defaultRetryBackoffSchedule = <Duration>[
    Duration(seconds: 30),
    Duration(minutes: 2),
    Duration(minutes: 5),
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(hours: 1),
    Duration(hours: 2),
    Duration(hours: 4),
  ];

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
    if (lease.status != RunSessionLeaseStatus.acquired || lease.session == null) {
      final message =
          lease.message ??
          _leaseStatusMessage(lease.status, normalizedRunSessionId);
      await metrics.recordDispatch(
        runSessionId: normalizedRunSessionId,
        status: ValidationDispatchStatus.accepted.name,
        phase: 'lease',
        message: message,
      );
      return ValidationDispatchResult.accepted(message: message);
    }

    final session = lease.session!;
    final mode = session.runTicket.mode.name;
    final attempt = session.validationAttempt;
    try {
      final board = await _loadBoardIfNeeded(session);
      final replayBlob = await _loadAndDecodeReplayBlob(session);
      _validateReplayAgainstSession(
        replayBlob: replayBlob,
        session: session,
        board: board,
      );

      final acceptedRun = _replayDeterministically(
        replayBlob: replayBlob,
        session: session,
      );
      await runSessionRepository.persistValidatedRun(validatedRun: acceptedRun);
      if (enableRewardSettlementWrites) {
        await rewardGrantWriter.settleValidatedRewardGrant(
          runSessionId: normalizedRunSessionId,
        );
      }
      if (session.runTicket.mode.requiresBoard) {
        await leaderboardProjector.projectValidatedRun(
          runSessionId: normalizedRunSessionId,
        );
        await ghostPublisher.updateGhostArtifacts(
          runSessionId: normalizedRunSessionId,
        );
      }
      await runSessionRepository.markTerminal(
        runSessionId: normalizedRunSessionId,
        terminalState: RunSessionTerminalState.validated,
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
      await runSessionRepository.persistValidatedRun(validatedRun: rejectedRun);
      if (enableRewardSettlementWrites) {
        await rewardGrantWriter.settleRevokedRewardGrant(
          runSessionId: normalizedRunSessionId,
          settlementReason: rejection.reason,
        );
      }
      await runSessionRepository.markTerminal(
        runSessionId: normalizedRunSessionId,
        terminalState: RunSessionTerminalState.rejected,
        message: rejection.message,
      );
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
          await runSessionRepository.markPendingValidationRetry(
            runSessionId: normalizedRunSessionId,
            nextAttemptAtMs: nextAttemptAtMs,
            message:
                '$message; incident mode active, reward revocation paused.',
            internalErrorFirstAtMs: graceStartMs,
          );
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
          await runSessionRepository.markPendingValidationRetry(
            runSessionId: normalizedRunSessionId,
            nextAttemptAtMs: graceDeadlineMs,
            message:
                '$message; grace window active until $graceDeadlineMs before '
                'auto-revoke.',
            internalErrorFirstAtMs: graceStartMs,
          );
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

        if (enableRewardSettlementWrites) {
          await rewardGrantWriter.settleRevokedRewardGrant(
            runSessionId: normalizedRunSessionId,
            settlementReason: RunSessionTerminalState.internalError.wireValue,
          );
        }
        await runSessionRepository.markTerminal(
          runSessionId: normalizedRunSessionId,
          terminalState: RunSessionTerminalState.internalError,
          message: message,
        );
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

      final delay = retryDelayForAttempt(attempt);
      final nextAttemptAtMs = _clockMs() + delay.inMilliseconds;
      await runSessionRepository.markPendingValidationRetry(
        runSessionId: normalizedRunSessionId,
        nextAttemptAtMs: nextAttemptAtMs,
        message: message,
        internalErrorFirstAtMs: null,
      );
      await metrics.recordDispatch(
        runSessionId: normalizedRunSessionId,
        status: ValidationDispatchStatus.retryScheduled.name,
        phase: 'retry',
        mode: mode,
        attempt: attempt,
        message:
            '$message; nextAttemptAtMs=$nextAttemptAtMs; retryDelay=${delay.inSeconds}s',
      );
      return ValidationDispatchResult.retryScheduled(message: message);
    }
  }

  Duration retryDelayForAttempt(int attempt) {
    if (_retryBackoffSchedule.isEmpty) {
      return Duration.zero;
    }
    final index = attempt <= 0 ? 0 : attempt - 1;
    if (index >= _retryBackoffSchedule.length) {
      return _retryBackoffSchedule.last;
    }
    return _retryBackoffSchedule[index];
  }

  Future<Map<String, Object?>?> _loadBoardIfNeeded(
    ValidatorRunSession session,
  ) async {
    if (!session.runTicket.mode.requiresBoard) {
      return null;
    }
    final board = await boardRepository.loadBoardForRunSession(
      runSessionId: session.runSessionId,
    );
    if (board == null) {
      throw const _ValidationRejectedException(
        reason: 'board_not_found',
        message: 'No active board metadata found for ranked run session.',
      );
    }
    return board;
  }

  Future<ReplayBlobV1> _loadAndDecodeReplayBlob(
    ValidatorRunSession session,
  ) async {
    final loaded = await replayLoader.loadReplay(
      runSessionId: session.runSessionId,
      objectPath: session.uploadedReplay.objectPath,
    );
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
    final decodedBytes = _maybeDecompressGzip(loaded.bytes);
    final decodedJson = _decodeJsonObject(decodedBytes);
    try {
      return ReplayBlobV1.fromJson(decodedJson, verifyDigest: true);
    } on FormatException catch (error) {
      throw _ValidationRejectedException(
        reason: 'protocol_invalid',
        message: 'Replay blob decode failed: ${error.message}',
      );
    }
  }

  List<int> _maybeDecompressGzip(List<int> bytes) {
    final isGzip =
        bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b;
    if (!isGzip) {
      return bytes;
    }
    try {
      return gzip.decode(bytes);
    } catch (error) {
      throw _ValidationRejectedException(
        reason: 'gzip_decode_failed',
        message: 'Replay gzip decode failed: $error',
      );
    }
  }

  Map<String, Object?> _decodeJsonObject(List<int> bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
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

  void _validateReplayAgainstSession({
    required ReplayBlobV1 replayBlob,
    required ValidatorRunSession session,
    required Map<String, Object?>? board,
  }) {
    final ticket = session.runTicket;
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
    if (ticket.mode.requiresBoard && board == null) {
      throw const _ValidationRejectedException(
        reason: 'board_not_found',
        message: 'Ranked replay requires board metadata.',
      );
    }
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
    final replayBoardKeyJson = canonicalJsonEncode(replayBlob.boardKey!.toJson());
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
      durationSeconds: (runEnded.tick / core.tickHz).round(),
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
      createdAtMs: _clockMs(),
    );
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
    final digest = ReplayDigest.isValidSha256Hex(
      session.uploadedReplay.canonicalSha256,
    )
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
    required this.leaderboardProjector,
    required this.rewardGrantWriter,
    required this.ghostPublisher,
    required this.metrics,
  });

  final ReplayLoader replayLoader;
  final BoardRepository boardRepository;
  final RunSessionRepository runSessionRepository;
  final LeaderboardProjector leaderboardProjector;
  final RewardGrantWriter rewardGrantWriter;
  final GhostPublisher ghostPublisher;
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

int distanceUnitsToMeters(
  double distanceUnits, {
  int unitsPerMeter = kWorldUnitsPerMeter,
}) {
  if (unitsPerMeter <= 0 || distanceUnits <= 0) {
    return 0;
  }
  return (distanceUnits / unitsPerMeter).floor();
}
