import '../accessories/accessory_catalog.dart';
import '../accessories/accessory_id.dart';
import '../abilities/ability_def.dart' show WeaponType;
import '../projectiles/projectile_item_catalog.dart';
import '../projectiles/projectile_item_id.dart';
import '../spells/spell_book_catalog.dart';
import '../spells/spell_book_id.dart';
import '../weapons/weapon_catalog.dart';
import '../weapons/weapon_category.dart';
import '../weapons/weapon_id.dart';
import 'equipped_gear.dart';
import 'gear_slot.dart';
import 'inventory_state.dart';
import 'meta_defaults.dart';
import 'meta_state.dart';
import '../players/player_character_definition.dart';

class GearSlotCandidate {
  const GearSlotCandidate({required this.id, required this.isUnlocked});

  final Object id;
  final bool isUnlocked;
}

class MetaService {
  static const int _startingUnlockedPerCatalog = 2;

  const MetaService({
    this.weapons = const WeaponCatalog(),
    this.projectileItems = const ProjectileItemCatalog(),
    this.spellBooks = const SpellBookCatalog(),
    this.accessories = const AccessoryCatalog(),
  });

  final WeaponCatalog weapons;
  final ProjectileItemCatalog projectileItems;
  final SpellBookCatalog spellBooks;
  final AccessoryCatalog accessories;

  InventoryState seedAllUnlockedInventory() {
    return InventoryState(
      unlockedWeaponIds: _startingUnlockedWeaponIds(),
      unlockedThrowingWeaponIds: _startingUnlockedThrowingWeaponIds(),
      unlockedSpellBookIds: _startingUnlockedSpellBookIds(),
      unlockedAccessoryIds: _startingUnlockedAccessoryIds(),
    );
  }

  Set<WeaponId> _startingUnlockedWeaponIds() {
    final unlockedPrimaryWeapons = <WeaponId>[];
    final unlockedOffhandWeapons = <WeaponId>[];
    for (final id in WeaponId.values) {
      final def = weapons.tryGet(id);
      if (def == null) continue;
      switch (def.category) {
        case WeaponCategory.primary:
          unlockedPrimaryWeapons.add(id);
          break;
        case WeaponCategory.offHand:
          unlockedOffhandWeapons.add(id);
          break;
        case WeaponCategory.projectile:
          break;
      }
    }

    return <WeaponId>{
      ...unlockedPrimaryWeapons.take(_startingUnlockedPerCatalog),
      ...unlockedOffhandWeapons.take(_startingUnlockedPerCatalog),
    };
  }

  Set<ProjectileItemId> _startingUnlockedThrowingWeaponIds() {
    final unlockedThrowingCandidates = <ProjectileItemId>[];
    for (final id in ProjectileItemId.values) {
      final def = projectileItems.tryGet(id);
      if (def != null && def.weaponType == WeaponType.throwingWeapon) {
        unlockedThrowingCandidates.add(id);
      }
    }

    return unlockedThrowingCandidates.take(_startingUnlockedPerCatalog).toSet();
  }

  Set<SpellBookId> _startingUnlockedSpellBookIds() {
    return SpellBookId.values.take(_startingUnlockedPerCatalog).toSet();
  }

  Set<AccessoryId> _startingUnlockedAccessoryIds() {
    return AccessoryId.values.take(_startingUnlockedPerCatalog).toSet();
  }

  MetaState createNew() {
    return normalize(
      MetaState.seedAllUnlocked(inventory: seedAllUnlockedInventory()),
    );
  }

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
      GearSlot.throwingWeapon => _throwingWeaponCandidates(state),
      GearSlot.spellBook => _spellBookCandidates(state),
      GearSlot.accessory => _accessoryCandidates(state),
    };
  }

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

  List<GearSlotCandidate> _throwingWeaponCandidates(MetaState state) {
    final unlocked = state.inventory.unlockedThrowingWeaponIds;
    final result = <GearSlotCandidate>[];
    for (final id in ProjectileItemId.values) {
      final def = projectileItems.tryGet(id);
      if (def == null || def.weaponType != WeaponType.throwingWeapon) {
        continue;
      }
      result.add(GearSlotCandidate(id: id, isUnlocked: unlocked.contains(id)));
    }
    return result;
  }

  List<GearSlotCandidate> _spellBookCandidates(MetaState state) {
    final unlocked = state.inventory.unlockedSpellBookIds;
    return [
      for (final id in SpellBookId.values)
        GearSlotCandidate(id: id, isUnlocked: unlocked.contains(id)),
    ];
  }

  List<GearSlotCandidate> _accessoryCandidates(MetaState state) {
    final unlocked = state.inventory.unlockedAccessoryIds;
    return [
      for (final id in AccessoryId.values)
        GearSlotCandidate(id: id, isUnlocked: unlocked.contains(id)),
    ];
  }

  MetaState normalize(MetaState state) {
    var inventory = state.inventory;
    final allowedWeapons = _startingUnlockedWeaponIds();
    final allowedThrowingWeapons = _startingUnlockedThrowingWeaponIds();
    final allowedSpellBooks = _startingUnlockedSpellBookIds();
    final allowedAccessories = _startingUnlockedAccessoryIds();

    final unlockedWeapons = Set<WeaponId>.from(inventory.unlockedWeaponIds)
      ..removeWhere((id) => !allowedWeapons.contains(id))
      ..add(MetaDefaults.mainWeaponId)
      ..add(MetaDefaults.offhandWeaponId);
    final unlockedThrowing =
        Set<ProjectileItemId>.from(inventory.unlockedThrowingWeaponIds)
          ..removeWhere((id) => !allowedThrowingWeapons.contains(id))
          ..add(MetaDefaults.throwingWeaponId);
    final unlockedSpellBooks = Set<SpellBookId>.from(
      inventory.unlockedSpellBookIds,
    );
    unlockedSpellBooks
      ..removeWhere((id) => !allowedSpellBooks.contains(id))
      ..add(MetaDefaults.spellBookId);
    final unlockedAccessories =
        Set<AccessoryId>.from(inventory.unlockedAccessoryIds)
          ..removeWhere((id) => !allowedAccessories.contains(id))
          ..add(MetaDefaults.accessoryId);

    inventory = inventory.copyWith(
      unlockedWeaponIds: unlockedWeapons,
      unlockedThrowingWeaponIds: unlockedThrowing,
      unlockedSpellBookIds: unlockedSpellBooks,
      unlockedAccessoryIds: unlockedAccessories,
    );

    final equippedByCharacter = <PlayerCharacterId, EquippedGear>{};
    for (final id in PlayerCharacterId.values) {
      final gear = state.equippedFor(id);
      equippedByCharacter[id] = _normalizeEquipped(gear, inventory);
    }

    return state.copyWith(
      schemaVersion: MetaState.latestSchemaVersion,
      inventory: inventory,
      equippedByCharacter: equippedByCharacter,
    );
  }

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

    var throwingWeaponId = gear.throwingWeaponId;
    final throwingDef = projectileItems.tryGet(throwingWeaponId);
    if (throwingDef == null ||
        throwingDef.weaponType != WeaponType.throwingWeapon ||
        !inventory.unlockedThrowingWeaponIds.contains(throwingWeaponId)) {
      throwingWeaponId = MetaDefaults.throwingWeaponId;
    }

    var spellBookId = gear.spellBookId;
    if (spellBooks.tryGet(spellBookId) == null ||
        !inventory.unlockedSpellBookIds.contains(spellBookId)) {
      spellBookId = MetaDefaults.spellBookId;
    }

    var accessoryId = gear.accessoryId;
    if (accessories.tryGet(accessoryId) == null ||
        !inventory.unlockedAccessoryIds.contains(accessoryId)) {
      accessoryId = MetaDefaults.accessoryId;
    }

    return EquippedGear(
      mainWeaponId: mainWeaponId,
      offhandWeaponId: offhandWeaponId,
      throwingWeaponId: throwingWeaponId,
      spellBookId: spellBookId,
      accessoryId: accessoryId,
    );
  }

  List<WeaponId> unlockedMainWeapons(MetaState state) {
    final result = <WeaponId>[];
    for (final id in state.inventory.unlockedWeaponIds) {
      final def = weapons.tryGet(id);
      if (def != null && def.category == WeaponCategory.primary) {
        result.add(id);
      }
    }
    result.sort((a, b) => a.index.compareTo(b.index));
    return result;
  }

  List<WeaponId> unlockedOffhands(MetaState state) {
    final result = <WeaponId>[];
    for (final id in state.inventory.unlockedWeaponIds) {
      final def = weapons.tryGet(id);
      if (def != null && def.category == WeaponCategory.offHand) {
        result.add(id);
      }
    }
    result.sort((a, b) => a.index.compareTo(b.index));
    return result;
  }

  List<ProjectileItemId> unlockedThrowingWeapons(MetaState state) {
    final result = state.inventory.unlockedThrowingWeaponIds.toList();
    result.sort((a, b) => a.index.compareTo(b.index));
    return result;
  }

  List<SpellBookId> unlockedSpellBooks(MetaState state) {
    final result = state.inventory.unlockedSpellBookIds.toList();
    result.sort((a, b) => a.index.compareTo(b.index));
    return result;
  }

  List<AccessoryId> unlockedAccessories(MetaState state) {
    final result = state.inventory.unlockedAccessoryIds.toList();
    result.sort((a, b) => a.index.compareTo(b.index));
    return result;
  }

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
      case GearSlot.throwingWeapon:
        if (itemId is! ProjectileItemId) return normalized;
        final def = projectileItems.tryGet(itemId);
        if (def == null || def.weaponType != WeaponType.throwingWeapon) {
          return normalized;
        }
        if (!normalized.inventory.unlockedThrowingWeaponIds.contains(itemId)) {
          return normalized;
        }
        return normalized.setEquippedFor(
          characterId,
          current.copyWith(throwingWeaponId: itemId),
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
        if (accessories.tryGet(itemId) == null) return normalized;
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
