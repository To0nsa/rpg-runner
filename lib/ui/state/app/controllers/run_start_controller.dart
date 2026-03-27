part of 'package:rpg_runner/ui/state/app/app_state.dart';

final class _AppStateRunStartController extends _AppStateController {
  _AppStateRunStartController(super._app);
  @override
  Future<void> startRunTicketPrefetchForCurrentSelection() {
    return startRunTicketPrefetchFor(
      mode: _selection.selectedRunMode,
      levelId: _selection.selectedLevelId,
    );
  }

  @override
  Future<void> startRunTicketPrefetchFor({
    required RunMode mode,
    required LevelId levelId,
  }) async {
    if (_runSessionApi is NoopRunSessionApi) {
      return;
    }
    final session = await _tryEnsureAuthSessionForRunTicketPrefetch();
    if (session == null) {
      return;
    }
    final effectiveLevelId = _effectiveLevelForMode(
      mode: mode,
      selectedLevelId: levelId,
    );
    final key = _runTicketPrefetchKeyFor(
      userId: session.userId,
      mode: mode,
      levelId: effectiveLevelId,
    );
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (!_shouldIssueRunTicketPrefetchRequest(key: key, nowMs: nowMs)) {
      return;
    }
    final existing = _runTicketPrefetchInFlight[key];
    if (existing != null) {
      await existing;
      return;
    }
    final completion = Completer<void>();
    _runTicketPrefetchInFlight[key] = completion.future;
    _runTicketPrefetchLastRequestedAtMsByKey[key] = nowMs;
    try {
      await _runTicketPrefetchForKey(key: key, session: session);
      completion.complete();
    } catch (error, stackTrace) {
      completion.completeError(error, stackTrace);
    } finally {
      if (identical(_runTicketPrefetchInFlight[key], completion.future)) {
        _runTicketPrefetchInFlight.remove(key);
      }
    }
  }

  Future<RunStartDescriptor> prepareRunStartDescriptor({
    RunMode? expectedMode,
    LevelId? expectedLevelId,
    String? ghostEntryId,
  }) async {
    await ensureOwnershipSyncedBeforeRunStart();
    final session = await _ensureAuthSession();
    // Restart flows pass expectedMode/expectedLevelId and still require a
    // live canonical read so stale restarts fail fast.
    if (expectedMode != null || expectedLevelId != null) {
      final canonical = await _ownershipApi.loadCanonicalState(
        userId: session.userId,
        sessionId: session.sessionId,
      );
      _applyCanonicalState(canonical);
    }
    if (_selection.selectedRunMode == RunMode.weekly &&
        _selection.selectedLevelId != _defaultWeeklyFeaturedLevelId) {
      await _setSelection(
        _selection.copyWith(selectedLevelId: _defaultWeeklyFeaturedLevelId),
      );
    }
    final canonicalMode = _selection.selectedRunMode;
    final canonicalLevelId = _selection.selectedLevelId;
    if (expectedMode != null && expectedMode != canonicalMode) {
      throw const RunStartRemoteException(
        code: 'failed-precondition',
        message:
            'Run mode changed in canonical state. Return to hub before restart.',
      );
    }
    if (expectedLevelId != null && expectedLevelId != canonicalLevelId) {
      throw const RunStartRemoteException(
        code: 'failed-precondition',
        message:
            'Selected level changed in canonical state. Return to hub before restart.',
      );
    }
    final mode = expectedMode ?? canonicalMode;
    final levelId = expectedLevelId ?? canonicalLevelId;
    final runTicket = expectedMode != null || expectedLevelId != null
        ? null
        : _takeValidPrefetchedRunTicket(
            userId: session.userId,
            mode: mode,
            levelId: levelId,
          );
    final resolvedTicket =
        runTicket ??
        await _runSessionApi.createRunSession(
          userId: session.userId,
          sessionId: session.sessionId,
          mode: mode,
          levelId: levelId,
          gameCompatVersion: _defaultGameCompatVersion,
        );
    final descriptor = _runStartDescriptorFromTicket(resolvedTicket);
    if (!mode.requiresBoard || descriptor.boardId == null) {
      return descriptor;
    }
    final resolvedGhostEntryId = ghostEntryId?.trim();
    if (resolvedGhostEntryId == null || resolvedGhostEntryId.isEmpty) {
      return descriptor;
    }
    final ghostReplayBootstrap = await loadGhostReplayBootstrap(
      boardId: descriptor.boardId!,
      entryId: resolvedGhostEntryId,
    );
    return descriptor.copyWith(ghostReplayBootstrap: ghostReplayBootstrap);
  }

  RunTicket? _takeValidPrefetchedRunTicket({
    required String userId,
    required RunMode mode,
    required LevelId levelId,
  }) {
    final key = _runTicketPrefetchKeyFor(
      userId: userId,
      mode: mode,
      levelId: levelId,
    );
    final cached = _runTicketPrefetchCache.remove(key);
    _runTicketPrefetchLruClockByKey.remove(key);
    if (cached == null) {
      return null;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (!_isRunTicketEligibleForPrefetchCache(
      runTicket: cached,
      nowMs: nowMs,
    )) {
      return null;
    }
    if (!_matchesRunTicketPrefetchKey(ticket: cached, key: key)) {
      return null;
    }
    return cached;
  }

  bool _matchesRunTicketPrefetchKey({
    required RunTicket ticket,
    required _RunTicketPrefetchKey key,
  }) {
    if (ticket.uid != key.userId) {
      return false;
    }
    if (ticket.mode != key.mode) {
      return false;
    }
    if (ticket.gameCompatVersion != key.gameCompatVersion) {
      return false;
    }
    if (ticket.levelId != key.levelId.name) {
      return false;
    }
    if (ticket.playerCharacterId != key.playerCharacterId.name) {
      return false;
    }
    if (ticket.loadoutDigest != key.loadoutDigest) {
      return false;
    }
    return true;
  }

  RunStartDescriptor _runStartDescriptorFromTicket(RunTicket ticket) {
    final parsedLevelId = _levelIdFromWire(ticket.levelId);
    final parsedCharacterId = _characterIdFromWire(ticket.playerCharacterId);
    final fallbackLoadout = _selection.loadoutFor(parsedCharacterId);
    final equippedLoadout = _equippedLoadoutFromSnapshot(
      ticket.loadoutSnapshot,
      fallback: fallbackLoadout,
    );
    return RunStartDescriptor(
      runSessionId: ticket.runSessionId,
      runId: _runIdFromRunSessionId(ticket.runSessionId),
      seed: ticket.seed,
      levelId: parsedLevelId,
      playerCharacterId: parsedCharacterId,
      runMode: ticket.mode,
      equippedLoadout: equippedLoadout,
      boardId: ticket.boardId,
      boardKey: ticket.boardKey,
    );
  }

  int _runIdFromRunSessionId(String runSessionId) {
    final digestBytes = crypto.sha256.convert(utf8.encode(runSessionId)).bytes;
    final digestWord = ByteData.sublistView(
      Uint8List.fromList(digestBytes),
      0,
      4,
    ).getUint32(0, Endian.big);
    final positive = digestWord & 0x7fffffff;
    return positive == 0 ? 1 : positive;
  }

  LevelId _levelIdFromWire(String levelId) {
    return _enumByName(LevelId.values, levelId, fieldName: 'runTicket.levelId');
  }

  PlayerCharacterId _characterIdFromWire(String characterId) {
    return _enumByName(
      PlayerCharacterId.values,
      characterId,
      fieldName: 'runTicket.playerCharacterId',
    );
  }

  EquippedLoadoutDef _equippedLoadoutFromSnapshot(
    Map<String, Object?> snapshot, {
    required EquippedLoadoutDef fallback,
  }) {
    return EquippedLoadoutDef(
      mask: _intOrFallback(snapshot['mask'], fallback.mask),
      mainWeaponId: _enumFromStringOrFallback(
        WeaponId.values,
        snapshot['mainWeaponId'],
        fallback.mainWeaponId,
      ),
      offhandWeaponId: _enumFromStringOrFallback(
        WeaponId.values,
        snapshot['offhandWeaponId'],
        fallback.offhandWeaponId,
      ),
      spellBookId: _enumFromStringOrFallback(
        SpellBookId.values,
        snapshot['spellBookId'],
        fallback.spellBookId,
      ),
      projectileSlotSpellId: _enumFromStringOrFallback(
        ProjectileId.values,
        snapshot['projectileSlotSpellId'],
        fallback.projectileSlotSpellId,
      ),
      accessoryId: _enumFromStringOrFallback(
        AccessoryId.values,
        snapshot['accessoryId'],
        fallback.accessoryId,
      ),
      abilityPrimaryId:
          _stringOrNull(snapshot['abilityPrimaryId']) ??
          fallback.abilityPrimaryId,
      abilitySecondaryId:
          _stringOrNull(snapshot['abilitySecondaryId']) ??
          fallback.abilitySecondaryId,
      abilityProjectileId:
          _stringOrNull(snapshot['abilityProjectileId']) ??
          fallback.abilityProjectileId,
      abilitySpellId:
          _stringOrNull(snapshot['abilitySpellId']) ?? fallback.abilitySpellId,
      abilityMobilityId:
          _stringOrNull(snapshot['abilityMobilityId']) ??
          fallback.abilityMobilityId,
      abilityJumpId:
          _stringOrNull(snapshot['abilityJumpId']) ?? fallback.abilityJumpId,
    );
  }

  _RunTicketPrefetchKey _runTicketPrefetchKeyFor({
    required String userId,
    required RunMode mode,
    required LevelId levelId,
  }) {
    final characterId = _selection.selectedCharacterId;
    final loadout = _selection.loadoutFor(characterId);
    return _RunTicketPrefetchKey(
      userId: userId,
      ownershipRevision: _ownershipRevision,
      gameCompatVersion: _defaultGameCompatVersion,
      mode: mode,
      levelId: levelId,
      playerCharacterId: characterId,
      loadoutDigest: _loadoutDigest(loadout),
    );
  }

  bool _shouldIssueRunTicketPrefetchRequest({
    required _RunTicketPrefetchKey key,
    required int nowMs,
  }) {
    final lastRequestedAtMs = _runTicketPrefetchLastRequestedAtMsByKey[key];
    if (lastRequestedAtMs == null) {
      return true;
    }
    return nowMs - lastRequestedAtMs >= _runTicketPrefetchMinIntervalMs;
  }

  Future<void> _runTicketPrefetchForKey({
    required _RunTicketPrefetchKey key,
    required AuthSession session,
  }) async {
    try {
      final runTicket = await _runSessionApi.createRunSession(
        userId: session.userId,
        sessionId: session.sessionId,
        mode: key.mode,
        levelId: key.levelId,
        gameCompatVersion: key.gameCompatVersion,
      );
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (!_isRunTicketEligibleForPrefetchCache(
        runTicket: runTicket,
        nowMs: nowMs,
      )) {
        return;
      }
      if (!_isRunTicketPrefetchKeyCurrent(key)) {
        return;
      }
      _storeRunTicketPrefetch(key: key, runTicket: runTicket);
    } catch (_) {
      return;
    }
  }

  bool _isRunTicketEligibleForPrefetchCache({
    required RunTicket runTicket,
    required int nowMs,
  }) {
    return nowMs + _runTicketPrefetchExpirySafetySkewMs < runTicket.expiresAtMs;
  }

  bool _isRunTicketPrefetchKeyCurrent(_RunTicketPrefetchKey key) {
    if (_authSession.userId != key.userId) {
      return false;
    }
    final effectiveLevelId = _effectiveLevelForMode(
      mode: key.mode,
      selectedLevelId: key.levelId,
    );
    final current = _runTicketPrefetchKeyFor(
      userId: key.userId,
      mode: key.mode,
      levelId: effectiveLevelId,
    );
    return current == key;
  }

  void _storeRunTicketPrefetch({
    required _RunTicketPrefetchKey key,
    required RunTicket runTicket,
  }) {
    _runTicketPrefetchCache[key] = runTicket;
    _runTicketPrefetchLruClock += 1;
    _runTicketPrefetchLruClockByKey[key] = _runTicketPrefetchLruClock;
    _evictRunTicketPrefetchLruIfNeeded();
  }

  void _evictRunTicketPrefetchLruIfNeeded() {
    while (_runTicketPrefetchCache.length > _runTicketPrefetchCacheMaxEntries) {
      _RunTicketPrefetchKey? oldestKey;
      int? oldestClock;
      for (final entry in _runTicketPrefetchLruClockByKey.entries) {
        final key = entry.key;
        if (!_runTicketPrefetchCache.containsKey(key)) {
          continue;
        }
        if (oldestClock == null || entry.value < oldestClock) {
          oldestClock = entry.value;
          oldestKey = key;
        }
      }
      if (oldestKey == null) {
        break;
      }
      _runTicketPrefetchCache.remove(oldestKey);
      _runTicketPrefetchLruClockByKey.remove(oldestKey);
      _runTicketPrefetchLastRequestedAtMsByKey.remove(oldestKey);
    }
  }

  String _loadoutDigest(EquippedLoadoutDef loadout) {
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
}
