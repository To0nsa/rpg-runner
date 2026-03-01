import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/accessories/accessory_id.dart';
import 'package:rpg_runner/core/meta/gear_slot.dart';
import 'package:rpg_runner/core/meta/equipped_gear.dart';
import 'package:rpg_runner/core/meta/inventory_state.dart';
import 'package:rpg_runner/core/meta/meta_defaults.dart';
import 'package:rpg_runner/core/meta/meta_service.dart';
import 'package:rpg_runner/core/meta/meta_state.dart';
import 'package:rpg_runner/core/meta/spell_list.dart';
import 'package:rpg_runner/core/players/player_character_definition.dart';
import 'package:rpg_runner/core/projectiles/projectile_id.dart';
import 'package:rpg_runner/core/spellBook/spell_book_id.dart';
import 'package:rpg_runner/core/weapons/weapon_id.dart';

const Set<ProjectileId> _eloiseStarterProjectileSpells = <ProjectileId>{
  ProjectileId.iceBolt,
  ProjectileId.fireBolt,
  ProjectileId.acidBolt,
  ProjectileId.darkBolt,
  ProjectileId.earthBolt,
  ProjectileId.holyBolt,
  ProjectileId.waterBolt,
  ProjectileId.thunderBolt,
};

const Set<String> _eloiseStarterSpellAbilities = <String>{
  'eloise.arcane_haste',
  'eloise.focus',
  'eloise.arcane_ward',
  'eloise.cleanse',
  'eloise.vital_surge',
  'eloise.mana_infusion',
  'eloise.second_wind',
};

void main() {
  test('MetaService.createNew equips defaults for every character', () {
    const service = MetaService();
    final meta = service.createNew();

    for (final id in PlayerCharacterId.values) {
      final gear = meta.equippedFor(id);
      expect(gear.mainWeaponId, MetaDefaults.mainWeaponId);
      expect(gear.offhandWeaponId, MetaDefaults.offhandWeaponId);
      expect(gear.throwingWeaponId, MetaDefaults.throwingWeaponId);
      expect(gear.spellBookId, MetaDefaults.spellBookId);
      expect(gear.accessoryId, MetaDefaults.accessoryId);
    }
  });

  test('MetaService.equip enforces slot categories', () {
    const service = MetaService();
    final meta = service.createNew();

    final bad = service.equip(
      meta,
      characterId: PlayerCharacterId.eloise,
      slot: GearSlot.mainWeapon,
      itemId: WeaponId.woodenShield,
    );
    expect(
      bad.equippedFor(PlayerCharacterId.eloise).mainWeaponId,
      MetaDefaults.mainWeaponId,
    );

    final good = service.equip(
      meta,
      characterId: PlayerCharacterId.eloise,
      slot: GearSlot.throwingWeapon,
      itemId: ProjectileId.throwingAxe,
    );
    expect(
      good.equippedFor(PlayerCharacterId.eloise).throwingWeaponId,
      ProjectileId.throwingAxe,
    );
  });

  test('MetaService.createNew unlocks all swords for loadout selection', () {
    const service = MetaService();
    final meta = service.createNew();
    final inventory = meta.inventory;

    expect(inventory.unlockedWeaponIds.contains(WeaponId.plainsteel), isTrue);
    expect(inventory.unlockedWeaponIds.contains(WeaponId.graveglass), isTrue);
    expect(inventory.unlockedWeaponIds.contains(WeaponId.duelistsOath), isTrue);
    expect(inventory.unlockedWeaponIds.contains(WeaponId.solidShield), isFalse);
    expect(
      inventory.unlockedSpellBookIds.contains(SpellBookId.epicSpellBook),
      isFalse,
    );
    expect(
      inventory.unlockedAccessoryIds.contains(AccessoryId.teethNecklace),
      isFalse,
    );
  });

  test(
    'MetaService.normalize re-locks third-tier gear from persisted state',
    () {
      const service = MetaService();
      final loaded = MetaState.seedAllUnlocked(
        inventory: InventoryState(
          unlockedWeaponIds: WeaponId.values.toSet(),
          unlockedThrowingWeaponIds: ProjectileId.values.toSet(),
          unlockedSpellBookIds: SpellBookId.values.toSet(),
          unlockedAccessoryIds: AccessoryId.values.toSet(),
        ),
      );

      final normalized = service.normalize(loaded);
      final inventory = normalized.inventory;

      expect(inventory.unlockedWeaponIds.contains(WeaponId.plainsteel), isTrue);
      expect(inventory.unlockedWeaponIds.contains(WeaponId.graveglass), isTrue);
      expect(
        inventory.unlockedWeaponIds.contains(WeaponId.solidShield),
        isFalse,
      );
      expect(
        inventory.unlockedThrowingWeaponIds.contains(ProjectileId.thunderBolt),
        isFalse,
      );
      expect(
        inventory.unlockedSpellBookIds.contains(SpellBookId.epicSpellBook),
        isFalse,
      );
      expect(
        inventory.unlockedAccessoryIds.contains(AccessoryId.teethNecklace),
        isFalse,
      );
    },
  );

  test(
    'MetaService.normalize grants all primary swords for existing inventories',
    () {
      const service = MetaService();
      final legacy = MetaState(
        schemaVersion: 1,
        inventory: InventoryState(
          unlockedWeaponIds: <WeaponId>{
            WeaponId.plainsteel,
            WeaponId.woodenShield,
            WeaponId.basicShield,
          },
          unlockedThrowingWeaponIds: service
              .seedAllUnlockedInventory()
              .unlockedThrowingWeaponIds,
          unlockedSpellBookIds: service
              .seedAllUnlockedInventory()
              .unlockedSpellBookIds,
          unlockedAccessoryIds: service
              .seedAllUnlockedInventory()
              .unlockedAccessoryIds,
        ),
        equippedByCharacter: <PlayerCharacterId, EquippedGear>{
          for (final id in PlayerCharacterId.values)
            id: MetaDefaults.equippedGear,
        },
        spellListByCharacter: <PlayerCharacterId, SpellList>{
          for (final id in PlayerCharacterId.values) id: SpellList.empty,
        },
      );

      final normalized = service.normalize(legacy);
      final unlocked = normalized.inventory.unlockedWeaponIds;

      expect(unlocked.contains(WeaponId.plainsteel), isTrue);
      expect(unlocked.contains(WeaponId.waspfang), isTrue);
      expect(unlocked.contains(WeaponId.cinderedge), isTrue);
      expect(unlocked.contains(WeaponId.basiliskKiss), isTrue);
      expect(unlocked.contains(WeaponId.frostbrand), isTrue);
      expect(unlocked.contains(WeaponId.stormneedle), isTrue);
      expect(unlocked.contains(WeaponId.nullblade), isTrue);
      expect(unlocked.contains(WeaponId.sunlitVow), isTrue);
      expect(unlocked.contains(WeaponId.graveglass), isTrue);
      expect(unlocked.contains(WeaponId.duelistsOath), isTrue);
    },
  );

  test('MetaService.candidatesForSlot includes sword and shield entries', () {
    const service = MetaService();
    final meta = service.createNew();

    final mainCandidates = service.candidatesForSlot(meta, GearSlot.mainWeapon);
    final graveglass = mainCandidates.firstWhere(
      (candidate) => candidate.id == WeaponId.graveglass,
    );
    final plainsteel = mainCandidates.firstWhere(
      (candidate) => candidate.id == WeaponId.plainsteel,
    );
    final offhandCandidates = service.candidatesForSlot(
      meta,
      GearSlot.offhandWeapon,
    );
    final solidShield = offhandCandidates.firstWhere(
      (candidate) => candidate.id == WeaponId.solidShield,
    );

    expect(graveglass.isUnlocked, isTrue);
    expect(plainsteel.isUnlocked, isTrue);
    expect(solidShield.isUnlocked, isFalse);
  });

  test('MetaService.candidatesForSlot returns throwing weapons only', () {
    const service = MetaService();
    final meta = service.createNew();

    final throwingCandidates = service.candidatesForSlot(
      meta,
      GearSlot.throwingWeapon,
    );
    final ids = throwingCandidates.map((candidate) => candidate.id).toList();

    expect(ids, contains(ProjectileId.throwingKnife));
    expect(ids, contains(ProjectileId.throwingAxe));
    expect(ids, isNot(contains(ProjectileId.thunderBolt)));
  });

  test('MetaService.createNew seeds spell list per character', () {
    const service = MetaService();
    final meta = service.createNew();

    for (final id in PlayerCharacterId.values) {
      final spellList = meta.spellListFor(id);
      expect(
        spellList.learnedProjectileSpellIds,
        _eloiseStarterProjectileSpells,
      );
      expect(spellList.learnedSpellAbilityIds, _eloiseStarterSpellAbilities);
    }
  });

  test(
    'MetaService.normalize seeds default spell list for older schema saves',
    () {
      const service = MetaService();
      final legacy = MetaState(
        schemaVersion: 1,
        inventory: InventoryState(
          unlockedWeaponIds: service
              .seedAllUnlockedInventory()
              .unlockedWeaponIds,
          unlockedThrowingWeaponIds: service
              .seedAllUnlockedInventory()
              .unlockedThrowingWeaponIds,
          unlockedSpellBookIds: <SpellBookId>{
            SpellBookId.basicSpellBook,
            SpellBookId.solidSpellBook,
          },
          unlockedAccessoryIds: service
              .seedAllUnlockedInventory()
              .unlockedAccessoryIds,
        ),
        equippedByCharacter: <PlayerCharacterId, EquippedGear>{
          for (final id in PlayerCharacterId.values)
            id: MetaDefaults.equippedGear,
        },
        spellListByCharacter: <PlayerCharacterId, SpellList>{
          for (final id in PlayerCharacterId.values) id: SpellList.empty,
        },
      );

      final normalized = service.normalize(legacy);

      for (final id in PlayerCharacterId.values) {
        final spellList = normalized.spellListFor(id);
        expect(
          spellList.learnedProjectileSpellIds,
          _eloiseStarterProjectileSpells,
        );
        expect(spellList.learnedSpellAbilityIds, _eloiseStarterSpellAbilities);
      }
    },
  );
}
