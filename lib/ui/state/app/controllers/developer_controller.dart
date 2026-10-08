part of 'package:rpg_runner/ui/state/app/app_state.dart';

/// Owns only local developer selections. No account cache or outbox is read.
final class _AppStateDeveloperController extends _AppStateController {
  _AppStateDeveloperController(super.app, this._store);

  final DeveloperProfileStore _store;
  Future<void> _pendingSave = Future<void>.value();
  Object? _saveError;
  static const _validator = LoadoutValidator(
    abilityCatalog: AbilityCatalog(),
    weaponCatalog: WeaponCatalog(),
    projectileCatalog: ProjectileCatalog(),
    spellBookCatalog: SpellBookCatalog(),
  );

  Future<void> bootstrap() async {
    if (_bootstrapped) {
      await flush();
      return;
    }
    final selection = await _store.loadSelection();
    if (_app._disposed) return;
    _selection = _normalize(selection);
    _meta = _unlockedMeta(_selection);
    _profile = const UserProfile(
      displayName: 'Developer',
      displayNameLastChangedAtMs: 0,
      namePromptCompleted: true,
    );
    _profileId = 'developer_practice';
    _bootstrapped = true;
    _notifyListeners();
  }

  MetaState _unlockedMeta(SelectionState selection) {
    // MetaService.normalize enforces starter inventory ceilings. Build this
    // isolated profile from the catalogs without changing normal unlock policy.
    return MetaState(
      schemaVersion: MetaState.latestSchemaVersion,
      inventory: InventoryState(
        unlockedWeaponIds: WeaponId.values.toSet(),
        unlockedSpellBookIds: SpellBookId.values.toSet(),
        unlockedAccessoryIds: AccessoryId.values.toSet(),
      ),
      abilityOwnershipByCharacter: {
        for (final id in PlayerCharacterId.values)
          id: AbilityOwnershipState(
            learnedProjectileSpellIds: {
              for (final projectile in playerEquippableProjectileIds)
                if (const ProjectileCatalog().tryGet(projectile)?.weaponType ==
                    WeaponType.spell)
                  projectile,
            },
            learnedAbilityIdsBySlot: {
              for (final slot in AbilitySlot.values)
                slot: {
                  for (final entry in AbilityCatalog.abilities.entries)
                    if (entry.value.allowedSlots.contains(slot) &&
                        (entry.key.startsWith(
                              '${characterAbilityNamespace(id)}.',
                            ) ||
                            (entry.key.startsWith('common.') &&
                                !entry.key.startsWith('common.enemy_'))))
                      entry.key,
                },
            },
          ),
      },
      equippedByCharacter: {
        for (final id in PlayerCharacterId.values)
          id: _validGear(
            selection.loadoutFor(id),
            SelectionState.defaults.loadoutFor(id),
          ),
      },
    );
  }

  EquippedGear _validGear(
    EquippedLoadoutDef loadout,
    EquippedLoadoutDef fallback,
  ) {
    const weapons = WeaponCatalog();
    return EquippedGear(
      mainWeaponId:
          weapons.tryGet(loadout.mainWeaponId)?.category ==
              WeaponCategory.primary
          ? loadout.mainWeaponId
          : fallback.mainWeaponId,
      offhandWeaponId:
          weapons.tryGet(loadout.offhandWeaponId)?.category ==
              WeaponCategory.offHand
          ? loadout.offhandWeaponId
          : fallback.offhandWeaponId,
      spellBookId: const SpellBookCatalog().tryGet(loadout.spellBookId) != null
          ? loadout.spellBookId
          : fallback.spellBookId,
      accessoryId: loadout.accessoryId,
    );
  }

  SelectionState _normalize(SelectionState selection) {
    final meta = _unlockedMeta(selection);
    final helper = _app._selectionOwnershipController;
    final loadouts = <PlayerCharacterId, EquippedLoadoutDef>{};
    for (final id in PlayerCharacterId.values) {
      final defaults = SelectionState.defaults.loadoutFor(id);
      final gear = meta.equippedFor(id);
      final ownership = meta.abilityOwnershipFor(id);
      var loadout = helper._copyLoadout(
        selection.loadoutFor(id),
        mask: PlayerCharacterRegistry.resolve(id).catalog.loadoutSlotMask,
        mainWeaponId: gear.mainWeaponId,
        offhandWeaponId: gear.offhandWeaponId,
        spellBookId: gear.spellBookId,
        accessoryId: gear.accessoryId,
      );
      final abilities = <AbilitySlot, AbilityKey>{
        AbilitySlot.primary: loadout.abilityPrimaryId,
        AbilitySlot.secondary: loadout.abilitySecondaryId,
        AbilitySlot.projectile: loadout.abilityProjectileId,
        AbilitySlot.spell: loadout.abilitySpellId,
        AbilitySlot.mobility: loadout.abilityMobilityId,
        AbilitySlot.jump: loadout.abilityJumpId,
      };
      final defaultAbilities = <AbilitySlot, AbilityKey>{
        AbilitySlot.primary: defaults.abilityPrimaryId,
        AbilitySlot.secondary: defaults.abilitySecondaryId,
        AbilitySlot.projectile: defaults.abilityProjectileId,
        AbilitySlot.spell: defaults.abilitySpellId,
        AbilitySlot.mobility: defaults.abilityMobilityId,
        AbilitySlot.jump: defaults.abilityJumpId,
      };
      for (final slot in AbilitySlot.values) {
        if (!ownership
            .learnedAbilityIdsForSlot(slot)
            .contains(abilities[slot])) {
          loadout = helper._withAbilityInLoadout(
            loadout: loadout,
            slot: slot,
            abilityId: defaultAbilities[slot]!,
          );
        }
      }
      if (!ownership.learnedProjectileSpellIds.contains(
        loadout.projectileSlotSpellId,
      )) {
        loadout = helper._copyLoadout(
          loadout,
          projectileSlotSpellId: defaults.projectileSlotSpellId,
        );
      }
      loadouts[id] = loadout;
    }
    return selection.copyWith(
      selectedRunMode: RunMode.practice,
      selectedLevelId: LevelRegistry.isAvailable(selection.selectedLevelId)
          ? selection.selectedLevelId
          : LevelRegistry.defaultLevelId,
      loadoutsByCharacter: loadouts,
    );
  }

  Future<void> setSelection(SelectionState selection) {
    if (_app._disposed) throw StateError('AppState has been disposed.');
    if (selection.selectedRunMode != RunMode.practice) {
      throw const RunStartRemoteException(
        code: 'failed-precondition',
        message: 'Only Practice is available in Developer mode.',
      );
    }
    _selection = _normalize(selection);
    _meta = _unlockedMeta(_selection);
    _notifyListeners();
    return _save(_selection);
  }

  Future<void> setLoadout(PlayerCharacterId id, EquippedLoadoutDef loadout) =>
      setSelection(_selection.withLoadoutFor(id, loadout));

  Future<void> _save(SelectionState selection) {
    final pending = _pendingSave.then((_) => _store.saveSelection(selection));
    // Keep writes ordered even after failure; the next successful save repairs it.
    _pendingSave = pending.then(
      (_) {
        _saveError = null;
      },
      onError: (Object error) {
        _saveError = error;
      },
    );
    return pending;
  }

  Future<void> flush() async {
    await _pendingSave;
    if (_saveError != null) await _save(_selection);
  }

  Future<RunStartDescriptor> prepareRun({
    RunMode? expectedMode,
    LevelId? expectedLevelId,
    String? ghostEntryId,
  }) async {
    await bootstrap();
    if (_app._disposed) throw StateError('AppState has been disposed.');
    if ((expectedMode != null && expectedMode != RunMode.practice) ||
        (expectedLevelId != null &&
            expectedLevelId != _selection.selectedLevelId) ||
        ghostEntryId != null) {
      throw const RunStartRemoteException(
        code: 'failed-precondition',
        message:
            'Developer mode supports local Practice only. Return to the hub.',
      );
    }
    final loadout = _selection.loadoutFor(_selection.selectedCharacterId);
    final validation = _validator.validate(loadout);
    if (!validation.isValid) {
      throw const RunStartRemoteException(
        code: 'invalid-loadout',
        message: 'This loadout is incompatible. Adjust your equipment and abilities.',
      );
    }
    final runId = _random.nextInt(0x7ffffffe) + 1;
    return RunStartDescriptor(
      runSessionId: 'developer_${DateTime.now().microsecondsSinceEpoch}_$runId',
      runId: runId,
      seed: _random.nextInt(0x7ffffffe) + 1,
      // Match the normal game's fixed simulation frequency, in ticks/second.
      tickHz: 60,
      levelId: _selection.selectedLevelId,
      playerCharacterId: _selection.selectedCharacterId,
      runMode: RunMode.practice,
      equippedLoadout: loadout,
      isDeveloperPractice: true,
    );
  }
}
