part of 'package:rpg_runner/ui/state/app/app_state.dart';

final class _AppStateSelectionOwnershipController extends _AppStateController {
  _AppStateSelectionOwnershipController(super._app);
  Future<void> setLevel(LevelId levelId) async {
    final resolvedLevelId = _effectiveLevelForMode(
      mode: _selection.selectedRunMode,
      selectedLevelId: levelId,
    );
    final nextSelection = _selection.copyWith(selectedLevelId: resolvedLevelId);
    await _updateSelectionOptimistically(nextSelection);
  }

  Future<void> setRunMode(RunMode runMode) async {
    final resolvedLevelId = _effectiveLevelForMode(
      mode: runMode,
      selectedLevelId: _selection.selectedLevelId,
    );
    final nextSelection = _selection.copyWith(
      selectedRunMode: runMode,
      selectedLevelId: resolvedLevelId,
    );
    await _updateSelectionOptimistically(nextSelection);
  }

  Future<void> setRunModeAndLevel({
    required RunMode runMode,
    required LevelId levelId,
  }) async {
    final resolvedLevelId = _effectiveLevelForMode(
      mode: runMode,
      selectedLevelId: levelId,
    );
    final nextSelection = _selection.copyWith(
      selectedRunMode: runMode,
      selectedLevelId: resolvedLevelId,
    );
    await _updateSelectionOptimistically(nextSelection);
  }

  Future<void> setCharacter(PlayerCharacterId id) async {
    final nextSelection = _selection.copyWith(selectedCharacterId: id);
    await _updateSelectionOptimistically(nextSelection);
  }

  Future<void> setLoadout(EquippedLoadoutDef loadout) async {
    final session = await _ensureAuthSession();
    final result = await _ownershipApi.setLoadout(
      SetLoadoutCommand(
        userId: session.userId,
        sessionId: session.sessionId,
        expectedRevision: _ownershipRevision,
        commandId: _newCommandId(),
        characterId: _selection.selectedCharacterId,
        loadout: loadout,
      ),
    );
    _applyOwnershipResult(result);
    _notifyListeners();
  }

  Future<void> setAbilitySlot({
    required PlayerCharacterId characterId,
    required AbilitySlot slot,
    required AbilityKey abilityId,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final currentLoadout = _selection.loadoutFor(characterId);
    final nextLoadout = _withAbilityInLoadout(
      loadout: currentLoadout,
      slot: slot,
      abilityId: abilityId,
    );
    _clearRunTicketPrefetchState();
    _selection = _selection.withLoadoutFor(characterId, nextLoadout);
    _notifyListeners();
    await _enqueueOwnershipCommand(
      OwnershipPendingCommand(
        coalesceKey: 'ability:${characterId.name}:${slot.name}',
        commandType: OwnershipPendingCommandType.setAbilitySlot,
        policyTier: OwnershipSyncTier.writeBehind,
        payloadJson: <String, Object?>{
          'characterId': characterId.name,
          'slot': slot.name,
          'abilityId': abilityId,
        },
        createdAtMs: nowMs,
        updatedAtMs: nowMs,
      ),
    );
  }

  Future<void> setProjectileSpell({
    required PlayerCharacterId characterId,
    required ProjectileId spellId,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final currentLoadout = _selection.loadoutFor(characterId);
    final nextLoadout = _copyLoadout(
      currentLoadout,
      projectileSlotSpellId: spellId,
    );
    _clearRunTicketPrefetchState();
    _selection = _selection.withLoadoutFor(characterId, nextLoadout);
    _notifyListeners();
    await _enqueueOwnershipCommand(
      OwnershipPendingCommand(
        coalesceKey: 'projectile:${characterId.name}',
        commandType: OwnershipPendingCommandType.setProjectileSpell,
        policyTier: OwnershipSyncTier.writeBehind,
        payloadJson: <String, Object?>{
          'characterId': characterId.name,
          'spellId': spellId.name,
        },
        createdAtMs: nowMs,
        updatedAtMs: nowMs,
      ),
    );
  }

  Future<void> learnProjectileSpell({
    required PlayerCharacterId characterId,
    required ProjectileId spellId,
  }) async {
    final session = await _ensureAuthSession();
    final result = await _ownershipApi.learnProjectileSpell(
      LearnProjectileSpellCommand(
        userId: session.userId,
        sessionId: session.sessionId,
        expectedRevision: _ownershipRevision,
        commandId: _newCommandId(),
        characterId: characterId,
        spellId: spellId,
      ),
    );
    _applyOwnershipResult(result);
    _notifyListeners();
  }

  Future<void> learnSpellAbility({
    required PlayerCharacterId characterId,
    required AbilityKey abilityId,
  }) async {
    final session = await _ensureAuthSession();
    final result = await _ownershipApi.learnSpellAbility(
      LearnSpellAbilityCommand(
        userId: session.userId,
        sessionId: session.sessionId,
        expectedRevision: _ownershipRevision,
        commandId: _newCommandId(),
        characterId: characterId,
        abilityId: abilityId,
      ),
    );
    _applyOwnershipResult(result);
    _notifyListeners();
  }

  Future<void> unlockGear({
    required GearSlot slot,
    required Object itemId,
  }) async {
    final session = await _ensureAuthSession();
    final result = await _ownershipApi.unlockGear(
      UnlockGearCommand(
        userId: session.userId,
        sessionId: session.sessionId,
        expectedRevision: _ownershipRevision,
        commandId: _newCommandId(),
        slot: slot,
        itemId: itemId,
      ),
    );
    _applyOwnershipResult(result);
    _notifyListeners();
  }

  Future<void> equipGear({
    required PlayerCharacterId characterId,
    required GearSlot slot,
    required Object itemId,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final currentLoadout = _selection.loadoutFor(characterId);
    final nextLoadout = _withGearInLoadout(
      loadout: currentLoadout,
      slot: slot,
      itemId: itemId,
    );
    _clearRunTicketPrefetchState();
    _selection = _selection.withLoadoutFor(characterId, nextLoadout);
    _meta = _meta.setEquippedFor(
      characterId,
      _withGearInMeta(
        equipped: _meta.equippedFor(characterId),
        slot: slot,
        itemId: itemId,
      ),
    );
    _notifyListeners();
    await _enqueueOwnershipCommand(
      OwnershipPendingCommand(
        coalesceKey: 'gear:${characterId.name}:${slot.name}',
        commandType: OwnershipPendingCommandType.equipGear,
        policyTier: OwnershipSyncTier.writeBehind,
        payloadJson: <String, Object?>{
          'characterId': characterId.name,
          'slot': slot.name,
          'itemId': _gearItemIdAsName(slot: slot, itemId: itemId),
        },
        createdAtMs: nowMs,
        updatedAtMs: nowMs,
      ),
    );
  }

  Future<void> setBuildName(String buildName) async {
    final normalized = SelectionState.normalizeBuildName(buildName);
    if (normalized == _selection.buildName) return;
    final nextSelection = _selection.copyWith(buildName: normalized);
    await _setSelection(nextSelection);
  }

  Future<void> awardRunGold({
    required int runId,
    required int goldEarned,
  }) async {
    if (goldEarned <= 0) {
      return;
    }
    final session = await _ensureAuthSession();
    var result = await _ownershipApi.awardRunGold(
      _newAwardRunGoldCommand(
        session: session,
        runId: runId,
        goldEarned: goldEarned,
      ),
    );
    if (result.rejectedReason == OwnershipRejectedReason.staleRevision) {
      final canonical = await _ownershipApi.loadCanonicalState(
        userId: session.userId,
        sessionId: session.sessionId,
      );
      _applyCanonicalState(canonical);
      result = await _ownershipApi.awardRunGold(
        _newAwardRunGoldCommand(
          session: session,
          runId: runId,
          goldEarned: goldEarned,
        ),
      );
    }
    _applyOwnershipResult(result);
    _notifyListeners();
  }

  Future<OwnershipCommandResult> purchaseStoreOffer({
    required String offerId,
  }) async {
    final session = await _ensureAuthSession();
    var result = await _ownershipApi.purchaseStoreOffer(
      PurchaseStoreOfferCommand(
        userId: session.userId,
        sessionId: session.sessionId,
        expectedRevision: _ownershipRevision,
        commandId: 'purchase_store_offer_${_newCommandId()}',
        offerId: offerId,
      ),
    );
    if (result.rejectedReason == OwnershipRejectedReason.staleRevision) {
      final canonical = await _ownershipApi.loadCanonicalState(
        userId: session.userId,
        sessionId: session.sessionId,
      );
      _applyCanonicalState(canonical);
      result = await _ownershipApi.purchaseStoreOffer(
        PurchaseStoreOfferCommand(
          userId: session.userId,
          sessionId: session.sessionId,
          expectedRevision: _ownershipRevision,
          commandId: 'purchase_store_offer_${_newCommandId()}',
          offerId: offerId,
        ),
      );
    }
    _applyOwnershipResult(result);
    _notifyListeners();
    return result;
  }

  Future<OwnershipCommandResult> refreshStore({
    required StoreRefreshMethod method,
    String? refreshGrantId,
  }) async {
    final session = await _ensureAuthSession();
    var result = await _ownershipApi.refreshStore(
      RefreshStoreCommand(
        userId: session.userId,
        sessionId: session.sessionId,
        expectedRevision: _ownershipRevision,
        commandId: 'refresh_store_${method.name}_${_newCommandId()}',
        method: method,
        refreshGrantId: refreshGrantId,
      ),
    );
    if (result.rejectedReason == OwnershipRejectedReason.staleRevision) {
      final canonical = await _ownershipApi.loadCanonicalState(
        userId: session.userId,
        sessionId: session.sessionId,
      );
      _applyCanonicalState(canonical);
      result = await _ownershipApi.refreshStore(
        RefreshStoreCommand(
          userId: session.userId,
          sessionId: session.sessionId,
          expectedRevision: _ownershipRevision,
          commandId: 'refresh_store_${method.name}_${_newCommandId()}',
          method: method,
          refreshGrantId: refreshGrantId,
        ),
      );
    }
    _applyOwnershipResult(result);
    _notifyListeners();
    return result;
  }

  @override
  Future<void> _setSelection(SelectionState nextSelection) async {
    final session = await _ensureAuthSession();
    final result = await _ownershipApi.setSelection(
      SetSelectionCommand(
        userId: session.userId,
        sessionId: session.sessionId,
        expectedRevision: _ownershipRevision,
        commandId: _newCommandId(),
        selection: nextSelection,
      ),
    );
    _applyOwnershipResult(result);
    _notifyListeners();
  }

  Future<void> _updateSelectionOptimistically(
    SelectionState nextSelection,
  ) async {
    if (_selection == nextSelection) {
      return;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    _clearRunTicketPrefetchState();
    _selection = nextSelection;
    _notifyListeners();
    await _enqueueOwnershipCommand(
      OwnershipPendingCommand(
        coalesceKey: 'selection',
        commandType: OwnershipPendingCommandType.setSelection,
        policyTier: OwnershipSyncTier.selectionFastSync,
        payloadJson: <String, Object?>{'selection': nextSelection.toJson()},
        createdAtMs: nowMs,
        updatedAtMs: nowMs,
      ),
    );
  }

  @override
  Future<void> _reconcileSelectionProjectionFromOutbox() async {
    final pending = await _ownershipOutboxStore.loadByCoalesceKey(
      coalesceKey: 'selection',
    );
    if (pending == null ||
        pending.commandType != OwnershipPendingCommandType.setSelection) {
      return;
    }
    final selectionRaw = pending.payloadJson['selection'];
    if (selectionRaw is! Map) {
      return;
    }
    final projectedSelection = SelectionState.fromJson(
      Map<String, dynamic>.from(selectionRaw),
    );
    _selection = projectedSelection;
  }

  AwardRunGoldCommand _newAwardRunGoldCommand({
    required AuthSession session,
    required int runId,
    required int goldEarned,
  }) {
    return AwardRunGoldCommand(
      userId: session.userId,
      sessionId: session.sessionId,
      expectedRevision: _ownershipRevision,
      commandId: 'award_run_gold_${runId}_${_newCommandId()}',
      runId: runId,
      goldEarned: goldEarned,
    );
  }

  EquippedLoadoutDef _withAbilityInLoadout({
    required EquippedLoadoutDef loadout,
    required AbilitySlot slot,
    required AbilityKey abilityId,
  }) {
    switch (slot) {
      case AbilitySlot.primary:
        return _copyLoadout(loadout, abilityPrimaryId: abilityId);
      case AbilitySlot.secondary:
        return _copyLoadout(loadout, abilitySecondaryId: abilityId);
      case AbilitySlot.projectile:
        return _copyLoadout(loadout, abilityProjectileId: abilityId);
      case AbilitySlot.spell:
        return _copyLoadout(loadout, abilitySpellId: abilityId);
      case AbilitySlot.mobility:
        return _copyLoadout(loadout, abilityMobilityId: abilityId);
      case AbilitySlot.jump:
        return _copyLoadout(loadout, abilityJumpId: abilityId);
    }
  }

  EquippedLoadoutDef _withGearInLoadout({
    required EquippedLoadoutDef loadout,
    required GearSlot slot,
    required Object itemId,
  }) {
    switch (slot) {
      case GearSlot.mainWeapon:
        return _copyLoadout(
          loadout,
          mainWeaponId: itemId is WeaponId ? itemId : loadout.mainWeaponId,
        );
      case GearSlot.offhandWeapon:
        return _copyLoadout(
          loadout,
          offhandWeaponId: itemId is WeaponId
              ? itemId
              : loadout.offhandWeaponId,
        );
      case GearSlot.spellBook:
        return _copyLoadout(
          loadout,
          spellBookId: itemId is SpellBookId ? itemId : loadout.spellBookId,
        );
      case GearSlot.accessory:
        return _copyLoadout(
          loadout,
          accessoryId: itemId is AccessoryId ? itemId : loadout.accessoryId,
        );
    }
  }

  EquippedLoadoutDef _copyLoadout(
    EquippedLoadoutDef loadout, {
    int? mask,
    WeaponId? mainWeaponId,
    WeaponId? offhandWeaponId,
    SpellBookId? spellBookId,
    ProjectileId? projectileSlotSpellId,
    AccessoryId? accessoryId,
    AbilityKey? abilityPrimaryId,
    AbilityKey? abilitySecondaryId,
    AbilityKey? abilityProjectileId,
    AbilityKey? abilitySpellId,
    AbilityKey? abilityMobilityId,
    AbilityKey? abilityJumpId,
  }) {
    return EquippedLoadoutDef(
      mask: mask ?? loadout.mask,
      mainWeaponId: mainWeaponId ?? loadout.mainWeaponId,
      offhandWeaponId: offhandWeaponId ?? loadout.offhandWeaponId,
      spellBookId: spellBookId ?? loadout.spellBookId,
      projectileSlotSpellId:
          projectileSlotSpellId ?? loadout.projectileSlotSpellId,
      accessoryId: accessoryId ?? loadout.accessoryId,
      abilityPrimaryId: abilityPrimaryId ?? loadout.abilityPrimaryId,
      abilitySecondaryId: abilitySecondaryId ?? loadout.abilitySecondaryId,
      abilityProjectileId: abilityProjectileId ?? loadout.abilityProjectileId,
      abilitySpellId: abilitySpellId ?? loadout.abilitySpellId,
      abilityMobilityId: abilityMobilityId ?? loadout.abilityMobilityId,
      abilityJumpId: abilityJumpId ?? loadout.abilityJumpId,
    );
  }

  EquippedGear _withGearInMeta({
    required EquippedGear equipped,
    required GearSlot slot,
    required Object itemId,
  }) {
    switch (slot) {
      case GearSlot.mainWeapon:
        return equipped.copyWith(
          mainWeaponId: itemId is WeaponId ? itemId : equipped.mainWeaponId,
        );
      case GearSlot.offhandWeapon:
        return equipped.copyWith(
          offhandWeaponId: itemId is WeaponId
              ? itemId
              : equipped.offhandWeaponId,
        );
      case GearSlot.spellBook:
        return equipped.copyWith(
          spellBookId: itemId is SpellBookId ? itemId : equipped.spellBookId,
        );
      case GearSlot.accessory:
        return equipped.copyWith(
          accessoryId: itemId is AccessoryId ? itemId : equipped.accessoryId,
        );
    }
  }

  String _gearItemIdAsName({required GearSlot slot, required Object itemId}) {
    switch (slot) {
      case GearSlot.mainWeapon:
      case GearSlot.offhandWeapon:
        return (itemId is WeaponId ? itemId : WeaponId.plainsteel).name;
      case GearSlot.spellBook:
        return (itemId is SpellBookId ? itemId : SpellBookId.apprenticePrimer)
            .name;
      case GearSlot.accessory:
        return (itemId is AccessoryId ? itemId : AccessoryId.strengthBelt).name;
    }
  }
}
