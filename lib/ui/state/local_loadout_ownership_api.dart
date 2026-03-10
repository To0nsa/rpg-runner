import 'dart:collection';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/abilities/ability_catalog.dart';
import '../../core/abilities/ability_def.dart';
import '../../core/ecs/stores/combat/equipped_loadout_store.dart';
import '../../core/loadout/loadout_validator.dart';
import '../../core/accessories/accessory_id.dart';
import '../../core/meta/gear_slot.dart';
import '../../core/meta/inventory_state.dart';
import '../../core/meta/meta_defaults.dart';
import '../../core/meta/meta_service.dart';
import '../../core/meta/meta_state.dart';
import '../../core/players/character_ability_namespace.dart';
import '../../core/players/player_character_definition.dart';
import '../../core/players/player_character_registry.dart';
import '../../core/projectiles/projectile_catalog.dart';
import '../../core/projectiles/projectile_id.dart';
import '../../core/spellBook/spell_book_catalog.dart';
import '../../core/spellBook/spell_book_id.dart';
import '../../core/weapons/weapon_catalog.dart';
import '../../core/weapons/weapon_category.dart';
import '../../core/weapons/weapon_id.dart';
import 'auth_api.dart';
import 'local_auth_api.dart';
import 'loadout_ownership_api.dart';
import 'meta_store.dart';
import 'selection_state.dart';
import 'selection_store.dart';

/// Local cache-backed implementation of [LoadoutOwnershipApi].
///
/// This adapter enforces revision/idempotency semantics while keeping
/// normalization behavior aligned with current local rules.
class LocalLoadoutOwnershipApi implements LoadoutOwnershipApi {
  LocalLoadoutOwnershipApi({
    SelectionStore? selectionStore,
    MetaStore? metaStore,
    MetaService? metaService,
    AuthApi? authApi,
    OwnershipConflictSimulator? conflictSimulator,
    int maxIdempotencyEntries = 128,
  }) : _selectionStore = selectionStore ?? SelectionStore(),
       _metaStore = metaStore ?? MetaStore(),
       _metaService = metaService ?? const MetaService(),
       _authApi = authApi ?? LocalAuthApi(),
       _conflictSimulator =
           conflictSimulator ?? const NoopOwnershipConflictSimulator(),
       _maxIdempotencyEntries = maxIdempotencyEntries < 8
           ? 8
           : maxIdempotencyEntries;

  static const String _prefsKey = 'ui.loadout_ownership_state.v1';

  static const AbilityCatalog _abilityCatalog = AbilityCatalog();
  static const ProjectileCatalog _projectileCatalog = ProjectileCatalog();
  static const SpellBookCatalog _spellBookCatalog = SpellBookCatalog();
  static const LoadoutValidator _loadoutValidator = LoadoutValidator(
    abilityCatalog: _abilityCatalog,
    weaponCatalog: WeaponCatalog(),
    projectileCatalog: _projectileCatalog,
    spellBookCatalog: _spellBookCatalog,
  );

  final SelectionStore _selectionStore;
  final MetaStore _metaStore;
  final MetaService _metaService;
  final AuthApi _authApi;
  final OwnershipConflictSimulator _conflictSimulator;
  final int _maxIdempotencyEntries;

  @override
  Future<OwnershipCanonicalState> loadCanonicalState({
    required String profileId,
    required String userId,
    required String sessionId,
  }) async {
    final isAuthorized = await _isAuthorizedActor(
      userId: userId,
      sessionId: sessionId,
    );
    if (!isAuthorized) {
      return _unauthorizedCanonical(profileId);
    }
    final loaded = await _loadCanonicalWithEnvelope(
      profileId: profileId,
      userId: userId,
    );
    await _persistCanonical(loaded.canonicalState, envelope: loaded.envelope);
    return loaded.canonicalState;
  }

  @override
  Future<OwnershipCommandResult> setSelection(SetSelectionCommand command) {
    return _executeCommand(
      command,
      apply: (canonical) => canonical.copyWith(selection: command.selection),
    );
  }

  @override
  Future<OwnershipCommandResult> resetOwnership(ResetOwnershipCommand command) {
    return _executeCommand(
      command,
      apply: (canonical) => canonical.copyWith(
        selection: SelectionState.defaults,
        meta: _metaService.createNew(),
      ),
    );
  }

  @override
  Future<OwnershipCommandResult> equipGear(EquipGearCommand command) {
    return _executeCommand(
      command,
      apply: (canonical) {
        final nextMeta = _metaService.equip(
          canonical.meta,
          characterId: command.characterId,
          slot: command.slot,
          itemId: command.itemId,
        );
        final currentLoadout = canonical.selection.loadoutFor(
          command.characterId,
        );
        final synced = _normalizeLoadoutForCharacter(
          currentLoadout,
          characterId: command.characterId,
          meta: nextMeta,
        );
        final nextSelection = canonical.selection.withLoadoutFor(
          command.characterId,
          synced,
        );
        return canonical.copyWith(selection: nextSelection, meta: nextMeta);
      },
    );
  }

  @override
  Future<OwnershipCommandResult> setLoadout(SetLoadoutCommand command) {
    return _executeCommand(
      command,
      apply: (canonical) {
        final normalized = _normalizeLoadoutForCharacter(
          command.loadout,
          characterId: command.characterId,
          meta: canonical.meta,
        );
        final nextSelection = canonical.selection.withLoadoutFor(
          command.characterId,
          normalized,
        );
        return canonical.copyWith(selection: nextSelection);
      },
    );
  }

  @override
  Future<OwnershipCommandResult> setAbilitySlot(SetAbilitySlotCommand command) {
    return _executeCommand(
      command,
      apply: (canonical) {
        final current = canonical.selection.loadoutFor(command.characterId);
        final next = _withAbilityForSlot(
          current,
          slot: command.slot,
          abilityId: command.abilityId,
        );
        final normalized = _normalizeLoadoutForCharacter(
          next,
          characterId: command.characterId,
          meta: canonical.meta,
        );
        final nextSelection = canonical.selection.withLoadoutFor(
          command.characterId,
          normalized,
        );
        return canonical.copyWith(selection: nextSelection);
      },
    );
  }

  @override
  Future<OwnershipCommandResult> setProjectileSpell(
    SetProjectileSpellCommand command,
  ) {
    return _executeCommand(
      command,
      apply: (canonical) {
        final current = canonical.selection.loadoutFor(command.characterId);
        final next = _withProjectileSpellSelection(
          current,
          projectileSlotSpellId: command.spellId,
        );
        final normalized = _normalizeLoadoutForCharacter(
          next,
          characterId: command.characterId,
          meta: canonical.meta,
        );
        final nextSelection = canonical.selection.withLoadoutFor(
          command.characterId,
          normalized,
        );
        return canonical.copyWith(selection: nextSelection);
      },
    );
  }

  @override
  Future<OwnershipCommandResult> learnProjectileSpell(
    LearnProjectileSpellCommand command,
  ) {
    return _executeCommand(
      command,
      apply: (canonical) {
        final spell = _projectileCatalog.tryGet(command.spellId);
        if (spell == null || spell.weaponType != WeaponType.spell) {
          throw const _OwnershipCommandError(
            OwnershipRejectedReason.invalidCommand,
          );
        }

        final spellList = canonical.meta.spellListFor(command.characterId);
        final nextSpellList = spellList.copyWith(
          learnedProjectileSpellIds: <ProjectileId>{
            ...spellList.learnedProjectileSpellIds,
            command.spellId,
          },
        );
        final nextMeta = canonical.meta.setSpellListFor(
          command.characterId,
          nextSpellList,
        );
        final currentLoadout = canonical.selection.loadoutFor(
          command.characterId,
        );
        final normalized = _normalizeLoadoutForCharacter(
          currentLoadout,
          characterId: command.characterId,
          meta: nextMeta,
        );
        final nextSelection = canonical.selection.withLoadoutFor(
          command.characterId,
          normalized,
        );
        return canonical.copyWith(selection: nextSelection, meta: nextMeta);
      },
    );
  }

  @override
  Future<OwnershipCommandResult> learnSpellAbility(
    LearnSpellAbilityCommand command,
  ) {
    return _executeCommand(
      command,
      apply: (canonical) {
        if (!_isSpellAbilityForCharacter(
          command.abilityId,
          characterId: command.characterId,
        )) {
          throw const _OwnershipCommandError(
            OwnershipRejectedReason.invalidCommand,
          );
        }
        final spellList = canonical.meta.spellListFor(command.characterId);
        final nextSpellList = spellList.copyWith(
          learnedSpellAbilityIds: <AbilityKey>{
            ...spellList.learnedSpellAbilityIds,
            command.abilityId,
          },
        );
        final nextMeta = canonical.meta.setSpellListFor(
          command.characterId,
          nextSpellList,
        );
        final currentLoadout = canonical.selection.loadoutFor(
          command.characterId,
        );
        final normalized = _normalizeLoadoutForCharacter(
          currentLoadout,
          characterId: command.characterId,
          meta: nextMeta,
        );
        final nextSelection = canonical.selection.withLoadoutFor(
          command.characterId,
          normalized,
        );
        return canonical.copyWith(selection: nextSelection, meta: nextMeta);
      },
    );
  }

  @override
  Future<OwnershipCommandResult> unlockGear(UnlockGearCommand command) {
    return _executeCommand(
      command,
      apply: (canonical) {
        final inventory = canonical.meta.inventory;
        final nextInventory = switch (command.slot) {
          GearSlot.mainWeapon => _unlockPrimaryWeapon(
            inventory,
            command.itemId,
          ),
          GearSlot.offhandWeapon => _unlockOffhandWeapon(
            inventory,
            command.itemId,
          ),
          GearSlot.spellBook => _unlockSpellBook(inventory, command.itemId),
          GearSlot.accessory => _unlockAccessory(inventory, command.itemId),
        };
        final nextMeta = _metaService.normalize(
          canonical.meta.copyWith(inventory: nextInventory),
        );
        return canonical.copyWith(meta: nextMeta);
      },
    );
  }

  Future<OwnershipCommandResult> _executeCommand(
    OwnershipCommand command, {
    required OwnershipCanonicalState Function(OwnershipCanonicalState canonical)
    apply,
  }) async {
    final isAuthorized = await _isAuthorizedActor(
      userId: command.userId,
      sessionId: command.sessionId,
    );
    if (!isAuthorized) {
      return _rejected(
        _unauthorizedCanonical(command.profileId),
        reason: OwnershipRejectedReason.unauthorized,
      );
    }
    final loaded = await _loadCanonicalWithEnvelope(
      profileId: command.profileId,
      userId: command.userId,
    );
    var canonical = loaded.canonicalState;
    var envelope = loaded.envelope;
    final payloadJson = jsonEncode(command.toJson());
    final commandId = command.commandId.trim();

    if (commandId.isEmpty ||
        command.expectedRevision < 0 ||
        command.profileId.trim().isEmpty ||
        command.userId.trim().isEmpty ||
        command.sessionId.trim().isEmpty) {
      final rejected = _rejected(
        canonical,
        reason: OwnershipRejectedReason.invalidCommand,
      );
      envelope = _recordCommandResult(
        envelope,
        commandId: commandId.isEmpty ? '<invalid-empty-id>' : commandId,
        payloadJson: payloadJson,
        result: rejected,
      );
      await _persistCanonical(canonical, envelope: envelope);
      return rejected;
    }

    final priorEntry = envelope.idempotencyByCommandId[commandId];
    if (priorEntry != null) {
      if (priorEntry.payloadJson == payloadJson) {
        return OwnershipCommandResult.fromJson(
          priorEntry.resultJson,
          fallbackCanonicalState: canonical,
        ).copyWith(replayedFromIdempotency: true);
      }
      final rejected = _rejected(
        canonical,
        reason: OwnershipRejectedReason.idempotencyKeyReuseMismatch,
      );
      envelope = _recordCommandResult(
        envelope,
        commandId: commandId,
        payloadJson: payloadJson,
        result: rejected,
      );
      await _persistCanonical(canonical, envelope: envelope);
      return rejected;
    }

    if (_conflictSimulator.shouldForceConflictForNextCommand()) {
      canonical = canonical.copyWith(revision: canonical.revision + 1);
      envelope = envelope.copyWith(
        profileId: canonical.profileId,
        userId: command.userId,
        revision: canonical.revision,
      );
      await _persistCanonical(canonical, envelope: envelope);
    }

    if (command.expectedRevision != canonical.revision) {
      final rejected = _rejected(
        canonical,
        reason: OwnershipRejectedReason.staleRevision,
      );
      envelope = _recordCommandResult(
        envelope,
        commandId: commandId,
        payloadJson: payloadJson,
        result: rejected,
      );
      await _persistCanonical(canonical, envelope: envelope);
      return rejected;
    }

    OwnershipCanonicalState nextCanonical;
    try {
      nextCanonical = apply(canonical).copyWith(
        profileId: canonical.profileId,
        revision: canonical.revision + 1,
      );
    } on _OwnershipCommandError catch (error) {
      final rejected = _rejected(canonical, reason: error.reason);
      envelope = _recordCommandResult(
        envelope,
        commandId: commandId,
        payloadJson: payloadJson,
        result: rejected,
      );
      await _persistCanonical(canonical, envelope: envelope);
      return rejected;
    }

    nextCanonical = _normalizeCanonical(nextCanonical);

    final accepted = OwnershipCommandResult(
      canonicalState: nextCanonical,
      newRevision: nextCanonical.revision,
      replayedFromIdempotency: false,
    );
    envelope = _recordCommandResult(
      envelope.copyWith(
        profileId: nextCanonical.profileId,
        userId: command.userId,
        revision: nextCanonical.revision,
      ),
      commandId: commandId,
      payloadJson: payloadJson,
      result: accepted,
    );
    await _persistCanonical(nextCanonical, envelope: envelope);
    return accepted;
  }

  Future<_LoadedOwnershipState> _loadCanonicalWithEnvelope({
    required String profileId,
    required String userId,
  }) async {
    final rawEnvelope = await _loadEnvelope();
    SelectionState selection;
    MetaState meta;
    _OwnershipEnvelope envelope;

    if ((rawEnvelope.profileId.isNotEmpty &&
            rawEnvelope.profileId != profileId) ||
        (rawEnvelope.userId.isNotEmpty && rawEnvelope.userId != userId)) {
      selection = SelectionState.defaults;
      meta = _metaService.createNew();
      envelope = _OwnershipEnvelope.empty(profileId: profileId, userId: userId);
    } else {
      selection = await _selectionStore.load();
      meta = await _metaStore.load(_metaService);
      envelope = rawEnvelope.profileId.isEmpty || rawEnvelope.userId.isEmpty
          ? rawEnvelope.copyWith(profileId: profileId, userId: userId)
          : rawEnvelope;
    }

    var canonical = OwnershipCanonicalState(
      profileId: profileId,
      revision: envelope.revision,
      selection: selection,
      meta: meta,
    );
    canonical = _normalizeCanonical(canonical);
    envelope = envelope.copyWith(
      profileId: canonical.profileId,
      userId: userId,
      revision: canonical.revision,
    );
    return _LoadedOwnershipState(canonicalState: canonical, envelope: envelope);
  }

  OwnershipCanonicalState _normalizeCanonical(OwnershipCanonicalState state) {
    final normalizedMeta = _metaService.normalize(state.meta);
    var normalizedSelection = state.selection;
    for (final id in PlayerCharacterId.values) {
      final current = normalizedSelection.loadoutFor(id);
      final normalized = _normalizeLoadoutForCharacter(
        current,
        characterId: id,
        meta: normalizedMeta,
      );
      if (!_sameLoadout(current, normalized)) {
        normalizedSelection = normalizedSelection.withLoadoutFor(
          id,
          normalized,
        );
      }
    }
    return state.copyWith(selection: normalizedSelection, meta: normalizedMeta);
  }

  Future<void> _persistCanonical(
    OwnershipCanonicalState canonical, {
    required _OwnershipEnvelope envelope,
  }) async {
    await _selectionStore.save(canonical.selection);
    await _metaStore.save(canonical.meta);
    await _saveEnvelope(
      envelope.copyWith(
        profileId: canonical.profileId,
        userId: envelope.userId,
        revision: canonical.revision,
      ),
    );
  }

  Future<bool> _isAuthorizedActor({
    required String userId,
    required String sessionId,
  }) async {
    final normalizedUserId = userId.trim();
    final normalizedSessionId = sessionId.trim();
    if (normalizedUserId.isEmpty || normalizedSessionId.isEmpty) {
      return false;
    }
    final activeSession = await _authApi.loadSession();
    if (activeSession.userId.isEmpty || activeSession.sessionId.isEmpty) {
      return false;
    }
    return activeSession.userId == normalizedUserId &&
        activeSession.sessionId == normalizedSessionId;
  }

  OwnershipCanonicalState _unauthorizedCanonical(String profileId) {
    return _normalizeCanonical(
      OwnershipCanonicalState(
        profileId: profileId,
        revision: 0,
        selection: SelectionState.defaults,
        meta: _metaService.createNew(),
      ),
    );
  }

  OwnershipCommandResult _rejected(
    OwnershipCanonicalState canonical, {
    required OwnershipRejectedReason reason,
  }) {
    return OwnershipCommandResult(
      canonicalState: canonical,
      newRevision: canonical.revision,
      replayedFromIdempotency: false,
      rejectedReason: reason,
    );
  }

  _OwnershipEnvelope _recordCommandResult(
    _OwnershipEnvelope envelope, {
    required String commandId,
    required String payloadJson,
    required OwnershipCommandResult result,
  }) {
    final next = LinkedHashMap<String, _OwnershipIdempotencyEntry>.from(
      envelope.idempotencyByCommandId,
    );
    next.remove(commandId);
    next[commandId] = _OwnershipIdempotencyEntry(
      payloadJson: payloadJson,
      resultJson: Map<String, dynamic>.from(result.toJson()),
    );
    while (next.length > _maxIdempotencyEntries) {
      final oldestKey = next.keys.first;
      next.remove(oldestKey);
    }
    return envelope.copyWith(idempotencyByCommandId: next);
  }

  Future<_OwnershipEnvelope> _loadEnvelope() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      return _OwnershipEnvelope.empty();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return _OwnershipEnvelope.fromJson(decoded);
      }
      if (decoded is Map) {
        return _OwnershipEnvelope.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      // Fall through to empty.
    }
    return _OwnershipEnvelope.empty();
  }

  Future<void> _saveEnvelope(_OwnershipEnvelope envelope) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(envelope.toJson());
    await prefs.setString(_prefsKey, payload);
  }

  EquippedLoadoutDef _normalizeLoadoutForCharacter(
    EquippedLoadoutDef loadout, {
    required PlayerCharacterId characterId,
    required MetaState meta,
  }) {
    final gear = meta.equippedFor(characterId);
    final spellList = meta.spellListFor(characterId);
    final character = PlayerCharacterRegistry.resolve(characterId);
    final catalog = character.catalog;
    var normalized = EquippedLoadoutDef(
      mask: catalog.loadoutSlotMask,
      mainWeaponId: gear.mainWeaponId,
      offhandWeaponId: gear.offhandWeaponId,
      spellBookId: gear.spellBookId,
      projectileSlotSpellId: loadout.projectileSlotSpellId,
      accessoryId: gear.accessoryId,
      abilityPrimaryId: _normalizeAbilityForSlot(
        abilityId: loadout.abilityPrimaryId,
        slot: AbilitySlot.primary,
        fallback: catalog.abilityPrimaryId,
      ),
      abilitySecondaryId: _normalizeAbilityForSlot(
        abilityId: loadout.abilitySecondaryId,
        slot: AbilitySlot.secondary,
        fallback: catalog.abilitySecondaryId,
      ),
      abilityProjectileId: _normalizeAbilityForSlot(
        abilityId: loadout.abilityProjectileId,
        slot: AbilitySlot.projectile,
        fallback: catalog.abilityProjectileId,
      ),
      abilitySpellId: _normalizeAbilityForSlot(
        abilityId: loadout.abilitySpellId,
        slot: AbilitySlot.spell,
        fallback: catalog.abilitySpellId,
        enforceSingleOwnedSkill: false,
      ),
      abilityMobilityId: _normalizeAbilityForSlot(
        abilityId: loadout.abilityMobilityId,
        slot: AbilitySlot.mobility,
        fallback: catalog.abilityMobilityId,
      ),
      abilityJumpId: _normalizeAbilityForSlot(
        abilityId: loadout.abilityJumpId,
        slot: AbilitySlot.jump,
        fallback: catalog.abilityJumpId,
      ),
    );
    final normalizedProjectileSpellId =
        _normalizeProjectileSpellSelectionForLoadout(
          normalized,
          learnedProjectileSpellIds: spellList.learnedProjectileSpellIds,
        );
    if (normalizedProjectileSpellId != normalized.projectileSlotSpellId) {
      normalized = _withProjectileSpellSelection(
        normalized,
        projectileSlotSpellId: normalizedProjectileSpellId,
      );
    }
    final normalizedSpellAbilityId = _normalizeSpellAbilityForLoadout(
      normalized,
      characterId: characterId,
      learnedSpellAbilityIds: spellList.learnedSpellAbilityIds,
    );
    if (normalizedSpellAbilityId != normalized.abilitySpellId) {
      normalized = _withAbilityForSlot(
        normalized,
        slot: AbilitySlot.spell,
        abilityId: normalizedSpellAbilityId,
      );
    }
    return normalized;
  }

  AbilityKey _normalizeAbilityForSlot({
    required AbilityKey abilityId,
    required AbilitySlot slot,
    required AbilityKey fallback,
    bool enforceSingleOwnedSkill = true,
  }) {
    final candidate = enforceSingleOwnedSkill ? fallback : abilityId;
    final ability = _abilityCatalog.resolve(candidate);
    if (ability != null && ability.allowedSlots.contains(slot)) {
      return ability.id;
    }
    final fallbackAbility = _abilityCatalog.resolve(fallback);
    if (fallbackAbility != null &&
        fallbackAbility.allowedSlots.contains(slot)) {
      return fallbackAbility.id;
    }
    return fallback;
  }

  AbilityKey _normalizeSpellAbilityForLoadout(
    EquippedLoadoutDef loadout, {
    required PlayerCharacterId characterId,
    required Set<AbilityKey> learnedSpellAbilityIds,
  }) {
    final current = loadout.abilitySpellId;
    if (learnedSpellAbilityIds.contains(current) &&
        _isAbilityVisibleForCharacter(characterId, current) &&
        _isAbilityValidForSlot(
          loadout,
          slot: AbilitySlot.spell,
          abilityId: current,
        )) {
      return current;
    }

    final orderedLearned = learnedSpellAbilityIds.toList(growable: false)
      ..sort((a, b) => a.compareTo(b));
    for (final abilityId in orderedLearned) {
      if (!_isAbilityVisibleForCharacter(characterId, abilityId)) continue;
      if (_isAbilityValidForSlot(
        loadout,
        slot: AbilitySlot.spell,
        abilityId: abilityId,
      )) {
        return abilityId;
      }
    }

    return current;
  }

  ProjectileId _normalizeProjectileSpellSelectionForLoadout(
    EquippedLoadoutDef loadout, {
    required Set<ProjectileId> learnedProjectileSpellIds,
  }) {
    final current = loadout.projectileSlotSpellId;
    if (_isProjectileSpellLearned(current, learnedProjectileSpellIds)) {
      return current;
    }

    final orderedLearned = learnedProjectileSpellIds.toList(growable: false)
      ..sort((a, b) => a.index.compareTo(b.index));
    for (final spellId in orderedLearned) {
      if (_isProjectileSpellLearned(spellId, learnedProjectileSpellIds)) {
        return spellId;
      }
    }
    if (_isProjectileSpellLearned(
      MetaDefaults.projectileSpellId,
      learnedProjectileSpellIds,
    )) {
      return MetaDefaults.projectileSpellId;
    }
    return const EquippedLoadoutDef().projectileSlotSpellId;
  }

  bool _isProjectileSpellLearned(
    ProjectileId spellId,
    Set<ProjectileId> learnedProjectileSpellIds,
  ) {
    if (!learnedProjectileSpellIds.contains(spellId)) return false;
    final spellItem = _projectileCatalog.tryGet(spellId);
    if (spellItem == null) return false;
    return spellItem.weaponType == WeaponType.spell;
  }

  bool _isAbilityValidForSlot(
    EquippedLoadoutDef loadout, {
    required AbilitySlot slot,
    required AbilityKey abilityId,
  }) {
    final trial = _withAbilityForSlot(
      loadout,
      slot: slot,
      abilityId: abilityId,
    );
    final result = _loadoutValidator.validate(trial);
    for (final issue in result.issues) {
      if (issue.slot == slot) {
        return false;
      }
    }
    return true;
  }

  EquippedLoadoutDef _withAbilityForSlot(
    EquippedLoadoutDef loadout, {
    required AbilitySlot slot,
    required AbilityKey abilityId,
  }) {
    return EquippedLoadoutDef(
      mask: loadout.mask,
      mainWeaponId: loadout.mainWeaponId,
      offhandWeaponId: loadout.offhandWeaponId,
      spellBookId: loadout.spellBookId,
      projectileSlotSpellId: loadout.projectileSlotSpellId,
      accessoryId: loadout.accessoryId,
      abilityPrimaryId: slot == AbilitySlot.primary
          ? abilityId
          : loadout.abilityPrimaryId,
      abilitySecondaryId: slot == AbilitySlot.secondary
          ? abilityId
          : loadout.abilitySecondaryId,
      abilityProjectileId: slot == AbilitySlot.projectile
          ? abilityId
          : loadout.abilityProjectileId,
      abilitySpellId: slot == AbilitySlot.spell
          ? abilityId
          : loadout.abilitySpellId,
      abilityMobilityId: slot == AbilitySlot.mobility
          ? abilityId
          : loadout.abilityMobilityId,
      abilityJumpId: slot == AbilitySlot.jump
          ? abilityId
          : loadout.abilityJumpId,
    );
  }

  EquippedLoadoutDef _withProjectileSpellSelection(
    EquippedLoadoutDef loadout, {
    required ProjectileId projectileSlotSpellId,
  }) {
    return EquippedLoadoutDef(
      mask: loadout.mask,
      mainWeaponId: loadout.mainWeaponId,
      offhandWeaponId: loadout.offhandWeaponId,
      spellBookId: loadout.spellBookId,
      projectileSlotSpellId: projectileSlotSpellId,
      accessoryId: loadout.accessoryId,
      abilityPrimaryId: loadout.abilityPrimaryId,
      abilitySecondaryId: loadout.abilitySecondaryId,
      abilityProjectileId: loadout.abilityProjectileId,
      abilitySpellId: loadout.abilitySpellId,
      abilityMobilityId: loadout.abilityMobilityId,
      abilityJumpId: loadout.abilityJumpId,
    );
  }

  bool _isAbilityVisibleForCharacter(
    PlayerCharacterId characterId,
    AbilityKey id,
  ) {
    final namespace = characterAbilityNamespace(characterId);
    if (id.startsWith('$namespace.')) {
      return true;
    }
    if (id.startsWith('common.') && !id.startsWith('common.enemy_')) {
      return true;
    }
    return false;
  }

  bool _isSpellAbilityForCharacter(
    AbilityKey id, {
    required PlayerCharacterId characterId,
  }) {
    final ability = _abilityCatalog.resolve(id);
    if (ability == null) return false;
    if (!ability.allowedSlots.contains(AbilitySlot.spell)) return false;
    return _isAbilityVisibleForCharacter(characterId, id);
  }

  bool _sameLoadout(EquippedLoadoutDef a, EquippedLoadoutDef b) {
    return a.mask == b.mask &&
        a.mainWeaponId == b.mainWeaponId &&
        a.offhandWeaponId == b.offhandWeaponId &&
        a.spellBookId == b.spellBookId &&
        a.projectileSlotSpellId == b.projectileSlotSpellId &&
        a.accessoryId == b.accessoryId &&
        a.abilityPrimaryId == b.abilityPrimaryId &&
        a.abilitySecondaryId == b.abilitySecondaryId &&
        a.abilityProjectileId == b.abilityProjectileId &&
        a.abilitySpellId == b.abilitySpellId &&
        a.abilityMobilityId == b.abilityMobilityId &&
        a.abilityJumpId == b.abilityJumpId;
  }

  InventoryState _unlockPrimaryWeapon(InventoryState inventory, Object itemId) {
    if (itemId is! WeaponId) {
      throw const _OwnershipCommandError(
        OwnershipRejectedReason.invalidCommand,
      );
    }
    final def = WeaponCatalog().tryGet(itemId);
    if (def == null || def.category != WeaponCategory.primary) {
      throw const _OwnershipCommandError(
        OwnershipRejectedReason.invalidCommand,
      );
    }
    return inventory.copyWith(
      unlockedWeaponIds: <WeaponId>{...inventory.unlockedWeaponIds, itemId},
    );
  }

  InventoryState _unlockOffhandWeapon(InventoryState inventory, Object itemId) {
    if (itemId is! WeaponId) {
      throw const _OwnershipCommandError(
        OwnershipRejectedReason.invalidCommand,
      );
    }
    final def = WeaponCatalog().tryGet(itemId);
    if (def == null || def.category != WeaponCategory.offHand) {
      throw const _OwnershipCommandError(
        OwnershipRejectedReason.invalidCommand,
      );
    }
    return inventory.copyWith(
      unlockedWeaponIds: <WeaponId>{...inventory.unlockedWeaponIds, itemId},
    );
  }

  InventoryState _unlockSpellBook(InventoryState inventory, Object itemId) {
    if (itemId is! SpellBookId) {
      throw const _OwnershipCommandError(
        OwnershipRejectedReason.invalidCommand,
      );
    }
    if (SpellBookCatalog().tryGet(itemId) == null) {
      throw const _OwnershipCommandError(
        OwnershipRejectedReason.invalidCommand,
      );
    }
    return inventory.copyWith(
      unlockedSpellBookIds: <SpellBookId>{
        ...inventory.unlockedSpellBookIds,
        itemId,
      },
    );
  }

  InventoryState _unlockAccessory(InventoryState inventory, Object itemId) {
    if (itemId is! AccessoryId) {
      throw const _OwnershipCommandError(
        OwnershipRejectedReason.invalidCommand,
      );
    }
    return inventory.copyWith(
      unlockedAccessoryIds: <AccessoryId>{
        ...inventory.unlockedAccessoryIds,
        itemId,
      },
    );
  }
}

class _OwnershipCommandError implements Exception {
  const _OwnershipCommandError(this.reason);

  final OwnershipRejectedReason reason;
}

class _LoadedOwnershipState {
  const _LoadedOwnershipState({
    required this.canonicalState,
    required this.envelope,
  });

  final OwnershipCanonicalState canonicalState;
  final _OwnershipEnvelope envelope;
}

class _OwnershipEnvelope {
  const _OwnershipEnvelope({
    required this.profileId,
    required this.userId,
    required this.revision,
    required this.idempotencyByCommandId,
  });

  final String profileId;
  final String userId;
  final int revision;
  final Map<String, _OwnershipIdempotencyEntry> idempotencyByCommandId;

  factory _OwnershipEnvelope.empty({
    String profileId = '',
    String userId = '',
  }) {
    return _OwnershipEnvelope(
      profileId: profileId,
      userId: userId,
      revision: 0,
      idempotencyByCommandId: const <String, _OwnershipIdempotencyEntry>{},
    );
  }

  _OwnershipEnvelope copyWith({
    String? profileId,
    String? userId,
    int? revision,
    Map<String, _OwnershipIdempotencyEntry>? idempotencyByCommandId,
  }) {
    return _OwnershipEnvelope(
      profileId: profileId ?? this.profileId,
      userId: userId ?? this.userId,
      revision: revision ?? this.revision,
      idempotencyByCommandId:
          idempotencyByCommandId ?? this.idempotencyByCommandId,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'profileId': profileId,
      'userId': userId,
      'revision': revision,
      'idempotency': <String, Object?>{
        for (final entry in idempotencyByCommandId.entries)
          entry.key: entry.value.toJson(),
      },
    };
  }

  static _OwnershipEnvelope fromJson(Map<String, dynamic> json) {
    final profileIdRaw = json['profileId'];
    final userIdRaw = json['userId'];
    final revisionRaw = json['revision'];
    final idempotencyRaw = json['idempotency'];
    final idempotencyByCommandId = <String, _OwnershipIdempotencyEntry>{};
    if (idempotencyRaw is Map) {
      for (final entry in idempotencyRaw.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is! String) continue;
        if (value is Map<String, dynamic>) {
          idempotencyByCommandId[key] = _OwnershipIdempotencyEntry.fromJson(
            value,
          );
        } else if (value is Map) {
          idempotencyByCommandId[key] = _OwnershipIdempotencyEntry.fromJson(
            Map<String, dynamic>.from(value),
          );
        }
      }
    }
    return _OwnershipEnvelope(
      profileId: profileIdRaw is String ? profileIdRaw : '',
      userId: userIdRaw is String ? userIdRaw : '',
      revision: revisionRaw is int
          ? revisionRaw
          : (revisionRaw is num ? revisionRaw.toInt() : 0),
      idempotencyByCommandId: idempotencyByCommandId,
    );
  }
}

class _OwnershipIdempotencyEntry {
  const _OwnershipIdempotencyEntry({
    required this.payloadJson,
    required this.resultJson,
  });

  final String payloadJson;
  final Map<String, dynamic> resultJson;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'payloadJson': payloadJson,
      'resultJson': resultJson,
    };
  }

  static _OwnershipIdempotencyEntry fromJson(Map<String, dynamic> json) {
    final payloadRaw = json['payloadJson'];
    final resultRaw = json['resultJson'];
    return _OwnershipIdempotencyEntry(
      payloadJson: payloadRaw is String ? payloadRaw : '',
      resultJson: resultRaw is Map<String, dynamic>
          ? resultRaw
          : (resultRaw is Map
                ? Map<String, dynamic>.from(resultRaw)
                : const <String, dynamic>{}),
    );
  }
}
