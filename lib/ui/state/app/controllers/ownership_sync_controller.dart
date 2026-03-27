part of 'package:rpg_runner/ui/state/app/app_state.dart';

final class _AppStateOwnershipSyncController extends _AppStateController {
  _AppStateOwnershipSyncController(super._app);
  Future<void> flushOwnershipEdits({
    required OwnershipFlushTrigger trigger,
  }) async {
    final active = _activeOwnershipFlush;
    if (active != null) {
      await active;
      return;
    }
    final pending = _flushOwnershipEditsInternal(trigger: trigger);
    _activeOwnershipFlush = pending;
    try {
      await pending;
    } finally {
      if (identical(_activeOwnershipFlush, pending)) {
        _activeOwnershipFlush = null;
      }
    }
  }

  @override
  Future<void> ensureOwnershipSyncedBeforeRunStart() {
    return _ensureOwnershipSyncedBeforeRunStartInternal();
  }

  Future<void> ensureSelectionSyncedBeforeLeavingLevelSetup() {
    return flushOwnershipEdits(trigger: OwnershipFlushTrigger.leaveLevelSetup);
  }

  Future<void> _ensureOwnershipSyncedBeforeRunStartInternal() async {
    if (_canFastReturnOwnershipSyncedBeforeRunStart()) {
      return;
    }
    await flushOwnershipEdits(trigger: OwnershipFlushTrigger.runStart);
    await _refreshOwnershipSyncStatusFromOutbox();
    if (_ownershipSyncStatus.pendingCount > 0) {
      throw const RunStartRemoteException(
        code: 'failed-precondition',
        message:
            'Pending ownership changes are still syncing. Check your connection and try again.',
      );
    }
  }

  bool _canFastReturnOwnershipSyncedBeforeRunStart() {
    if (_activeOwnershipFlush != null || _ownershipSyncStatus.isFlushing) {
      return false;
    }
    if (_ownershipSyncStatus.pendingCount != 0) {
      return false;
    }
    final updatedAtMs = _ownershipSyncStatusUpdatedAtMs;
    if (updatedAtMs == null) {
      return false;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs < updatedAtMs) {
      return false;
    }
    return nowMs - updatedAtMs <= _ownershipSyncStatusFreshnessMaxAgeMs;
  }

  @override
  Future<void> _enqueueOwnershipCommand(OwnershipPendingCommand command) async {
    await _ownershipOutboxStore.upsertCoalesced(command: command);
    await _refreshOwnershipSyncStatusFromOutbox();
    _scheduleOwnershipFlush(policyTier: command.policyTier);
    _notifyListeners();
  }

  void _scheduleOwnershipFlush({required OwnershipSyncTier policyTier}) {
    final debounceMs = _ownershipSyncPolicy.debounceMsFor(policyTier);
    _ownershipFlushTimer?.cancel();
    if (debounceMs <= 0) {
      unawaited(flushOwnershipEdits(trigger: OwnershipFlushTrigger.manual));
      return;
    }
    _ownershipFlushTimer = Timer(Duration(milliseconds: debounceMs), () {
      unawaited(flushOwnershipEdits(trigger: OwnershipFlushTrigger.manual));
    });
  }

  Future<void> _flushOwnershipEditsInternal({
    required OwnershipFlushTrigger trigger,
  }) async {
    _ownershipFlushTimer?.cancel();
    _ownershipFlushTimer = null;
    _ownershipSyncStatus = _ownershipSyncStatus.copyWith(
      isFlushing: true,
      clearLastSyncError: true,
    );
    _notifyListeners();
    try {
      AuthSession? session;
      while (true) {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final pending = await _ownershipOutboxStore.loadAll();
        OwnershipPendingCommand? ready;
        OwnershipPendingCommand? fallbackReady;
        int? earliestNextAttemptAtMs;
        for (final candidate in pending) {
          final attempt = candidate.deliveryAttempt;
          final ageMs = nowMs - candidate.createdAtMs;
          final exceededMaxStaleness =
              ageMs >= _ownershipSyncPolicy.maxStalenessMs;
          if (attempt == null ||
              attempt.nextAttemptAtMs <= nowMs ||
              exceededMaxStaleness) {
            fallbackReady ??= candidate;
            if (candidate.policyTier == OwnershipSyncTier.selectionFastSync) {
              ready = candidate;
              break;
            }
            continue;
          }
          final candidateNextAttemptAtMs = attempt.nextAttemptAtMs;
          if (earliestNextAttemptAtMs == null ||
              candidateNextAttemptAtMs < earliestNextAttemptAtMs) {
            earliestNextAttemptAtMs = candidateNextAttemptAtMs;
          }
        }
        ready ??= fallbackReady;
        if (ready == null) {
          if (earliestNextAttemptAtMs != null) {
            final delayMs = earliestNextAttemptAtMs - nowMs;
            _ownershipFlushTimer?.cancel();
            _ownershipFlushTimer = Timer(
              Duration(milliseconds: delayMs <= 0 ? 1 : delayMs),
              () {
                unawaited(
                  flushOwnershipEdits(trigger: OwnershipFlushTrigger.manual),
                );
              },
            );
          }
          break;
        }
        session ??= await _ensureAuthSession();
        await _deliverPendingOwnershipCommand(session: session, command: ready);
      }
      await _refreshOwnershipSyncStatusFromOutbox();
    } catch (error) {
      _ownershipSyncStatus = _ownershipSyncStatus.copyWith(
        lastSyncError: 'flush:${trigger.name}:$error',
      );
    } finally {
      _ownershipSyncStatus = _ownershipSyncStatus.copyWith(isFlushing: false);
      _notifyListeners();
    }
  }

  Future<void> _deliverPendingOwnershipCommand({
    required AuthSession session,
    required OwnershipPendingCommand command,
  }) async {
    final alreadySuperseded = await _isPendingCommandSuperseded(
      command: command,
    );
    if (alreadySuperseded) {
      return;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final payloadHash = crypto.sha256
        .convert(utf8.encode(jsonEncode(command.payloadJson)))
        .toString();
    final attempt =
        command.deliveryAttempt ??
        OwnershipDeliveryAttempt(
          commandId: _newCommandId(),
          expectedRevision: _ownershipRevision,
          attemptCount: 0,
          nextAttemptAtMs: nowMs,
          sentPayloadHash: payloadHash,
        );
    try {
      final result = await _sendPendingOwnershipCommand(
        session: session,
        command: command,
        attempt: attempt,
      );
      final superseded = await _isPendingCommandSuperseded(
        command: command,
        sentPayloadHash: payloadHash,
      );
      if (superseded) {
        return;
      }
      if (result.rejectedReason == OwnershipRejectedReason.staleRevision) {
        final canonical = await _ownershipApi.loadCanonicalState(
          userId: session.userId,
          sessionId: session.sessionId,
        );
        await _ownershipOutboxStore.upsertCoalesced(
          command: command.copyWith(
            updatedAtMs: nowMs,
            clearDeliveryAttempt: true,
          ),
        );
        _applyCanonicalState(canonical);
        await _reconcileSelectionProjectionFromOutbox();
        _ownershipSyncStatus = _ownershipSyncStatus.copyWith(
          conflictCount: _ownershipSyncStatus.conflictCount + 1,
        );
        _notifyListeners();
        return;
      }

      _applyOwnershipResult(result);
      await _ownershipOutboxStore.removeByCoalesceKey(
        coalesceKey: command.coalesceKey,
      );
      await _reconcileSelectionProjectionFromOutbox();
      _notifyListeners();
    } catch (_) {
      final superseded = await _isPendingCommandSuperseded(
        command: command,
        sentPayloadHash: payloadHash,
      );
      if (superseded) {
        return;
      }
      final nextAttemptCount = attempt.attemptCount + 1;
      final delayMs = _ownershipSyncPolicy.retryDelayMsForAttempt(
        nextAttemptCount,
        random: _random,
      );
      final nextAttempt = attempt.copyWith(
        attemptCount: nextAttemptCount,
        nextAttemptAtMs: nowMs + delayMs,
        sentPayloadHash: payloadHash,
      );
      await _ownershipOutboxStore.upsertCoalesced(
        command: command.copyWith(
          updatedAtMs: nowMs,
          deliveryAttempt: nextAttempt,
        ),
      );
      _ownershipSyncStatus = _ownershipSyncStatus.copyWith(
        retryCount: _ownershipSyncStatus.retryCount + 1,
      );
    }
  }

  Future<bool> _isPendingCommandSuperseded({
    required OwnershipPendingCommand command,
    String? sentPayloadHash,
  }) async {
    final latest = await _ownershipOutboxStore.loadByCoalesceKey(
      coalesceKey: command.coalesceKey,
    );
    if (latest == null) {
      return false;
    }
    if (latest.updatedAtMs > command.updatedAtMs) {
      return true;
    }
    final latestPayloadHash = crypto.sha256
        .convert(utf8.encode(jsonEncode(latest.payloadJson)))
        .toString();
    final referencePayloadHash =
        sentPayloadHash ??
        crypto.sha256
            .convert(utf8.encode(jsonEncode(command.payloadJson)))
            .toString();
    return latestPayloadHash != referencePayloadHash;
  }

  Future<OwnershipCommandResult> _sendPendingOwnershipCommand({
    required AuthSession session,
    required OwnershipPendingCommand command,
    required OwnershipDeliveryAttempt attempt,
  }) async {
    switch (command.commandType) {
      case OwnershipPendingCommandType.setSelection:
        final selectionRaw = command.payloadJson['selection'];
        if (selectionRaw is! Map) {
          throw FormatException('setSelection payload is invalid.');
        }
        final selection = SelectionState.fromJson(
          Map<String, dynamic>.from(selectionRaw),
        );
        return _ownershipApi.setSelection(
          SetSelectionCommand(
            userId: session.userId,
            sessionId: session.sessionId,
            expectedRevision: attempt.expectedRevision,
            commandId: attempt.commandId,
            selection: selection,
          ),
        );
      case OwnershipPendingCommandType.setAbilitySlot:
        final characterId = _enumByName(
          PlayerCharacterId.values,
          '${command.payloadJson['characterId']}',
          fieldName: 'setAbilitySlot.characterId',
        );
        final slot = _enumByName(
          AbilitySlot.values,
          '${command.payloadJson['slot']}',
          fieldName: 'setAbilitySlot.slot',
        );
        final abilityId = '${command.payloadJson['abilityId']}';
        return _ownershipApi.setAbilitySlot(
          SetAbilitySlotCommand(
            userId: session.userId,
            sessionId: session.sessionId,
            expectedRevision: attempt.expectedRevision,
            commandId: attempt.commandId,
            characterId: characterId,
            slot: slot,
            abilityId: abilityId,
          ),
        );
      case OwnershipPendingCommandType.setProjectileSpell:
        final characterId = _enumByName(
          PlayerCharacterId.values,
          '${command.payloadJson['characterId']}',
          fieldName: 'setProjectileSpell.characterId',
        );
        final spellId = _enumByName(
          ProjectileId.values,
          '${command.payloadJson['spellId']}',
          fieldName: 'setProjectileSpell.spellId',
        );
        return _ownershipApi.setProjectileSpell(
          SetProjectileSpellCommand(
            userId: session.userId,
            sessionId: session.sessionId,
            expectedRevision: attempt.expectedRevision,
            commandId: attempt.commandId,
            characterId: characterId,
            spellId: spellId,
          ),
        );
      case OwnershipPendingCommandType.equipGear:
        final characterId = _enumByName(
          PlayerCharacterId.values,
          '${command.payloadJson['characterId']}',
          fieldName: 'equipGear.characterId',
        );
        final slot = _enumByName(
          GearSlot.values,
          '${command.payloadJson['slot']}',
          fieldName: 'equipGear.slot',
        );
        final itemIdName = '${command.payloadJson['itemId']}';
        final itemId = _gearItemFromName(slot: slot, itemIdName: itemIdName);
        return _ownershipApi.equipGear(
          EquipGearCommand(
            userId: session.userId,
            sessionId: session.sessionId,
            expectedRevision: attempt.expectedRevision,
            commandId: attempt.commandId,
            characterId: characterId,
            slot: slot,
            itemId: itemId,
          ),
        );
      case OwnershipPendingCommandType.setLoadout:
        throw UnsupportedError(
          'setLoadout outbox delivery is not enabled yet.',
        );
    }
  }

  @override
  Future<void> _refreshOwnershipSyncStatusFromOutbox() async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final pending = await _ownershipOutboxStore.loadAll();
    final pendingSelectionCount = pending
        .where(
          (entry) => entry.policyTier == OwnershipSyncTier.selectionFastSync,
        )
        .length;
    int oldestPendingAgeMs = 0;
    if (pending.isNotEmpty) {
      final oldestCreatedAtMs = pending
          .map((entry) => entry.createdAtMs)
          .reduce((a, b) => a < b ? a : b);
      oldestPendingAgeMs = nowMs - oldestCreatedAtMs;
      if (oldestPendingAgeMs < 0) {
        oldestPendingAgeMs = 0;
      }
    }
    _ownershipSyncStatus = _ownershipSyncStatus.copyWith(
      pendingCount: pending.length,
      pendingSelectionCount: pendingSelectionCount,
      oldestPendingAgeMs: oldestPendingAgeMs,
    );
    _ownershipSyncStatusUpdatedAtMs = nowMs;
  }
}
