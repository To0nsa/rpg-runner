import '../accessories/accessory_catalog.dart';
import '../accessories/accessory_id.dart';
import '../abilities/ability_catalog.dart';
import '../abilities/ability_def.dart' show AbilityKey, AbilitySlot, WeaponType;
import '../projectiles/projectile_catalog.dart';
import '../projectiles/projectile_id.dart';
import '../spellBook/spell_book_catalog.dart';
import '../spellBook/spell_book_id.dart';
import '../weapons/weapon_catalog.dart';
import '../weapons/weapon_category.dart';
import '../weapons/weapon_id.dart';
import 'ability_ownership_state.dart';
import 'equipped_gear.dart';
import 'gear_slot.dart';
import 'inventory_state.dart';
import 'meta_defaults.dart';
import 'meta_state.dart';
import '../players/player_character_definition.dart';
import '../players/player_catalog.dart';
import '../players/character_ability_namespace.dart';
import '../players/player_character_registry.dart';

/// Slot candidate DTO consumed by gear picker UI.
///
/// [id] type depends on the queried [GearSlot].
class GearSlotCandidate {
  const GearSlotCandidate({required this.id, required this.isUnlocked});

  /// Typed gear id for the requested slot domain.
  final Object id;

  /// Whether this candidate is currently unlocked for use/equip.
  final bool isUnlocked;
}

/// Domain service for meta inventory, unlock rules, and equip validation.
class MetaService {
  const MetaService({
    this.weapons = const WeaponCatalog(),
    this.projectiles = const ProjectileCatalog(),
    this.spellBooks = const SpellBookCatalog(),
    this.accessories = const AccessoryCatalog(),
  });

  /// Weapon catalog dependency.
  final WeaponCatalog weapons;

  /// Projectile item catalog dependency.
  final ProjectileCatalog projectiles;

  /// Spellbook catalog dependency.
  final SpellBookCatalog spellBooks;

  /// Accessory catalog dependency.
  final AccessoryCatalog accessories;

  static const AbilityCatalog _abilityCatalog = AbilityCatalog();

  /// Seeds initial inventory according to startup unlock policy.
  InventoryState seedAllUnlockedInventory() {
    return InventoryState(
      unlockedWeaponIds: _startingUnlockedWeaponIds(),
      unlockedSpellBookIds: _startingUnlockedSpellBookIds(),
      unlockedAccessoryIds: _startingUnlockedAccessoryIds(),
    );
  }

  /// Returns starter unlocked main/off-hand weapon IDs.
  Set<WeaponId> _startingUnlockedWeaponIds() {
    return <WeaponId>{MetaDefaults.mainWeaponId, MetaDefaults.offhandWeaponId};
  }

  /// Returns starter unlocked spellbook IDs.
  Set<SpellBookId> _startingUnlockedSpellBookIds() {
    return <SpellBookId>{MetaDefaults.spellBookId};
  }

  /// Returns starter unlocked accessory IDs.
  Set<AccessoryId> _startingUnlockedAccessoryIds() {
    return <AccessoryId>{MetaDefaults.accessoryId};
  }

  /// Creates a new normalized meta state for first-time users.
  MetaState createNew() {
    return normalize(
      MetaState.seedAllUnlocked(
        inventory: seedAllUnlockedInventory(),
        abilityOwnershipByCharacter: _startingAbilityOwnershipByCharacter(),
      ),
    );
  }

  /// Returns all candidates for [slot], including locked entries.
  List<GearSlotCandidate> candidatesForSlot(MetaState state, GearSlot slot) {
    return switch (slot) {
      GearSlot.mainWeapon => _weaponCandidatesForCategory(
        state,
        WeaponCategory.primary,
      ),
      GearSlot.offhandWeapon => _weaponCandidatesForCategory(
        state,
        WeaponCategory.offHand,
      ),
      GearSlot.spellBook => _spellBookCandidates(state),
      GearSlot.accessory => _accessoryCandidates(state),
    };
  }

  /// Builds weapon candidates for [category] with unlock markers.
  List<GearSlotCandidate> _weaponCandidatesForCategory(
    MetaState state,
    WeaponCategory category,
  ) {
    final unlocked = state.inventory.unlockedWeaponIds;
    final result = <GearSlotCandidate>[];
    for (final id in WeaponId.values) {
      final def = weapons.tryGet(id);
      if (def == null || def.category != category) continue;
      result.add(GearSlotCandidate(id: id, isUnlocked: unlocked.contains(id)));
    }
    return result;
  }

  /// Builds spellbook candidates with unlock markers.
  List<GearSlotCandidate> _spellBookCandidates(MetaState state) {
    final unlocked = state.inventory.unlockedSpellBookIds;
    return [
      for (final id in SpellBookId.values)
        GearSlotCandidate(id: id, isUnlocked: unlocked.contains(id)),
    ];
  }

  /// Builds accessory candidates with unlock markers.
  List<GearSlotCandidate> _accessoryCandidates(MetaState state) {
    final unlocked = state.inventory.unlockedAccessoryIds;
    return [
      for (final id in AccessoryId.values)
        GearSlotCandidate(id: id, isUnlocked: unlocked.contains(id)),
    ];
  }

  /// Normalizes persisted state to current rules and fallback guarantees.
  ///
  /// Enforces:
  /// - startup unlock ceilings per domain
  /// - default items always unlocked
  /// - equipped gear always valid and unlocked
  /// - ability ownership valid per character
  MetaState normalize(MetaState state) {
    var inventory = state.inventory;
    final allowedWeapons = _startingUnlockedWeaponIds();
    final guaranteedPrimaryWeapons = <WeaponId>{};
    final guaranteedOffhandWeapons = <WeaponId>{};
    for (final id in allowedWeapons) {
      final def = weapons.tryGet(id);
      if (def == null) continue;
      switch (def.category) {
        case WeaponCategory.primary:
          guaranteedPrimaryWeapons.add(id);
          break;
        case WeaponCategory.offHand:
          guaranteedOffhandWeapons.add(id);
          break;
        case WeaponCategory.projectile:
          break;
      }
    }
    final allowedSpellBooks = _startingUnlockedSpellBookIds();
    final allowedAccessories = _startingUnlockedAccessoryIds();

    final unlockedWeapons = Set<WeaponId>.from(inventory.unlockedWeaponIds)
      ..removeWhere((id) => !allowedWeapons.contains(id))
      ..addAll(guaranteedPrimaryWeapons)
      ..addAll(guaranteedOffhandWeapons)
      ..add(MetaDefaults.mainWeaponId)
      ..add(MetaDefaults.offhandWeaponId);
    final unlockedSpellBooks = Set<SpellBookId>.from(
      inventory.unlockedSpellBookIds,
    );
    unlockedSpellBooks
      ..removeWhere((id) => !allowedSpellBooks.contains(id))
      ..add(MetaDefaults.spellBookId);
    final unlockedAccessories =
        Set<AccessoryId>.from(inventory.unlockedAccessoryIds)
          ..removeWhere((id) => !allowedAccessories.contains(id))
          ..addAll(allowedAccessories)
          ..add(MetaDefaults.accessoryId);

    inventory = inventory.copyWith(
      unlockedWeaponIds: unlockedWeapons,
      unlockedSpellBookIds: unlockedSpellBooks,
      unlockedAccessoryIds: unlockedAccessories,
    );

    final equippedByCharacter = <PlayerCharacterId, EquippedGear>{};
    for (final id in PlayerCharacterId.values) {
      final gear = state.equippedFor(id);
      equippedByCharacter[id] = _normalizeEquipped(gear, inventory);
    }

    final abilityOwnershipByCharacter =
        <PlayerCharacterId, AbilityOwnershipState>{};
    for (final id in PlayerCharacterId.values) {
      abilityOwnershipByCharacter[id] = _normalizeAbilityOwnershipForCharacter(
        state.abilityOwnershipFor(id),
        characterId: id,
      );
    }

    return state.copyWith(
      schemaVersion: MetaState.latestSchemaVersion,
      inventory: inventory,
      equippedByCharacter: equippedByCharacter,
      abilityOwnershipByCharacter: abilityOwnershipByCharacter,
    );
  }

  Map<PlayerCharacterId, AbilityOwnershipState>
  _startingAbilityOwnershipByCharacter() {
    return <PlayerCharacterId, AbilityOwnershipState>{
      for (final id in PlayerCharacterId.values)
        id: _startingAbilityOwnershipForCharacter(id),
    };
  }

  AbilityOwnershipState _startingAbilityOwnershipForCharacter(
    PlayerCharacterId characterId,
  ) {
    final catalog = PlayerCharacterRegistry.resolve(characterId).catalog;
    final projectileSpells = <ProjectileId>{
      for (final id in catalog.startingProjectileSpellIds)
        if (_isSpellProjectile(id)) id,
    };
    final abilityIdsBySlot = _startingAbilityIdsBySlotForCharacter(characterId);

    if (projectileSpells.isEmpty) {
      final defaultProjectileSpellId = catalog.projectileSlotSpellId;
      if (_isSpellProjectile(defaultProjectileSpellId)) {
        projectileSpells.add(defaultProjectileSpellId);
      }
    }
    if (projectileSpells.isEmpty &&
        _isSpellProjectile(MetaDefaults.projectileSpellId)) {
      projectileSpells.add(MetaDefaults.projectileSpellId);
    }

    for (final slot in AbilitySlot.values) {
      if (abilityIdsBySlot[slot]!.isNotEmpty) continue;
      final fallbackId = _defaultStarterAbilityIdForSlot(catalog, slot: slot);
      if (fallbackId != null &&
          _isAbilityForSlotAndCharacter(
            fallbackId,
            slot: slot,
            characterId: characterId,
          )) {
        abilityIdsBySlot[slot]!.add(fallbackId);
      }
      if (slot == AbilitySlot.spell &&
          abilityIdsBySlot[slot]!.isEmpty &&
          _isAbilityForSlotAndCharacter(
            MetaDefaults.spellAbilityId,
            slot: slot,
            characterId: characterId,
          )) {
        abilityIdsBySlot[slot]!.add(MetaDefaults.spellAbilityId);
      }
    }

    return AbilityOwnershipState(
      learnedProjectileSpellIds: projectileSpells,
      learnedAbilityIdsBySlot: abilityIdsBySlot,
    );
  }

  Map<AbilitySlot, Set<AbilityKey>> _startingAbilityIdsBySlotForCharacter(
    PlayerCharacterId characterId,
  ) {
    final catalog = PlayerCharacterRegistry.resolve(characterId).catalog;
    final learnedBySlot = <AbilitySlot, Set<AbilityKey>>{
      for (final slot in AbilitySlot.values) slot: <AbilityKey>{},
    };

    void addStarter(AbilitySlot slot, AbilityKey id) {
      if (_isAbilityForSlotAndCharacter(
        id,
        slot: slot,
        characterId: characterId,
      )) {
        learnedBySlot[slot]!.add(id);
      }
    }

    addStarter(AbilitySlot.primary, catalog.abilityPrimaryId);
    addStarter(AbilitySlot.secondary, catalog.abilitySecondaryId);
    addStarter(AbilitySlot.projectile, catalog.abilityProjectileId);
    addStarter(AbilitySlot.mobility, catalog.abilityMobilityId);
    addStarter(AbilitySlot.jump, catalog.abilityJumpId);
    addStarter(AbilitySlot.spell, catalog.abilitySpellId);
    for (final id in catalog.startingSpellAbilityIds) {
      addStarter(AbilitySlot.spell, id);
    }

    return learnedBySlot;
  }

  AbilityKey? _defaultStarterAbilityIdForSlot(
    PlayerCatalog catalog, {
    required AbilitySlot slot,
  }) {
    return switch (slot) {
      AbilitySlot.primary => catalog.abilityPrimaryId,
      AbilitySlot.secondary => catalog.abilitySecondaryId,
      AbilitySlot.projectile => catalog.abilityProjectileId,
      AbilitySlot.mobility => catalog.abilityMobilityId,
      AbilitySlot.spell => catalog.abilitySpellId,
      AbilitySlot.jump => catalog.abilityJumpId,
    };
  }

  AbilityOwnershipState _normalizeAbilityOwnershipForCharacter(
    AbilityOwnershipState abilityOwnership, {
    required PlayerCharacterId characterId,
  }) {
    final learnedProjectileSpellIds = <ProjectileId>{
      for (final id in abilityOwnership.learnedProjectileSpellIds)
        if (_isSpellProjectile(id)) id,
    };
    final learnedAbilityIdsBySlot = <AbilitySlot, Set<AbilityKey>>{
      for (final slot in AbilitySlot.values)
        slot: <AbilityKey>{
          for (final id in abilityOwnership.learnedAbilityIdsForSlot(slot))
            if (_isAbilityForSlotAndCharacter(
              id,
              slot: slot,
              characterId: characterId,
            ))
              id,
        },
    };

    final defaults = _startingAbilityOwnershipForCharacter(characterId);
    if (learnedProjectileSpellIds.isEmpty) {
      learnedProjectileSpellIds.addAll(defaults.learnedProjectileSpellIds);
    }
    for (final slot in AbilitySlot.values) {
      final learned = learnedAbilityIdsBySlot[slot]!;
      if (learned.isEmpty) {
        learned.addAll(defaults.learnedAbilityIdsForSlot(slot));
      }
    }

    return AbilityOwnershipState(
      learnedProjectileSpellIds: learnedProjectileSpellIds,
      learnedAbilityIdsBySlot: learnedAbilityIdsBySlot,
    );
  }

  bool _isSpellProjectile(ProjectileId id) {
    return projectiles.tryGet(id)?.weaponType == WeaponType.spell;
  }

  bool _isAbilityForSlotAndCharacter(
    AbilityKey id, {
    required AbilitySlot slot,
    required PlayerCharacterId characterId,
  }) {
    final ability = _abilityCatalog.resolve(id);
    if (ability == null) return false;
    if (!ability.allowedSlots.contains(slot)) return false;
    final namespace = characterAbilityNamespace(characterId);
    if (id.startsWith('$namespace.')) return true;
    if (id.startsWith('common.') && !id.startsWith('common.enemy_')) {
      return true;
    }
    return false;
  }

  /// Validates and repairs a single character loadout against [inventory].
  EquippedGear _normalizeEquipped(EquippedGear gear, InventoryState inventory) {
    var mainWeaponId = gear.mainWeaponId;
    final mainDef = weapons.tryGet(mainWeaponId);
    if (mainDef == null ||
        mainDef.category != WeaponCategory.primary ||
        !inventory.unlockedWeaponIds.contains(mainWeaponId)) {
      mainWeaponId = MetaDefaults.mainWeaponId;
    }

    var offhandWeaponId = gear.offhandWeaponId;
    final offDef = weapons.tryGet(offhandWeaponId);
    if (offDef == null ||
        offDef.category != WeaponCategory.offHand ||
        !inventory.unlockedWeaponIds.contains(offhandWeaponId)) {
      offhandWeaponId = MetaDefaults.offhandWeaponId;
    }

    var spellBookId = gear.spellBookId;
    if (spellBooks.tryGet(spellBookId) == null ||
        !inventory.unlockedSpellBookIds.contains(spellBookId)) {
      spellBookId = MetaDefaults.spellBookId;
    }

    var accessoryId = gear.accessoryId;
    if (!inventory.unlockedAccessoryIds.contains(accessoryId)) {
      accessoryId = MetaDefaults.accessoryId;
    }

    return EquippedGear(
      mainWeaponId: mainWeaponId,
      offhandWeaponId: offhandWeaponId,
      spellBookId: spellBookId,
      accessoryId: accessoryId,
    );
  }

  /// Attempts to equip [itemId] into [slot] for [characterId].
  ///
  /// Invalid item types/categories or locked items are ignored and return
  /// unchanged normalized state.
  MetaState equip(
    MetaState state, {
    required PlayerCharacterId characterId,
    required GearSlot slot,
    required Object itemId,
  }) {
    final normalized = normalize(state);
    final current = normalized.equippedFor(characterId);

    switch (slot) {
      case GearSlot.mainWeapon:
        if (itemId is! WeaponId) return normalized;
        final def = weapons.tryGet(itemId);
        if (def == null || def.category != WeaponCategory.primary) {
          return normalized;
        }
        if (!normalized.inventory.unlockedWeaponIds.contains(itemId)) {
          return normalized;
        }
        return normalized.setEquippedFor(
          characterId,
          current.copyWith(mainWeaponId: itemId),
        );
      case GearSlot.offhandWeapon:
        if (itemId is! WeaponId) return normalized;
        final def = weapons.tryGet(itemId);
        if (def == null || def.category != WeaponCategory.offHand) {
          return normalized;
        }
        if (!normalized.inventory.unlockedWeaponIds.contains(itemId)) {
          return normalized;
        }
        return normalized.setEquippedFor(
          characterId,
          current.copyWith(offhandWeaponId: itemId),
        );
      case GearSlot.spellBook:
        if (itemId is! SpellBookId) return normalized;
        if (spellBooks.tryGet(itemId) == null) return normalized;
        if (!normalized.inventory.unlockedSpellBookIds.contains(itemId)) {
          return normalized;
        }
        return normalized.setEquippedFor(
          characterId,
          current.copyWith(spellBookId: itemId),
        );
      case GearSlot.accessory:
        if (itemId is! AccessoryId) return normalized;
        if (!normalized.inventory.unlockedAccessoryIds.contains(itemId)) {
          return normalized;
        }
        return normalized.setEquippedFor(
          characterId,
          current.copyWith(accessoryId: itemId),
        );
    }
  }
}
