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
      expect(gear.spellBookId, MetaDefaults.spellBookId);
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
      itemId: WeaponId.roadguard,
    );
    expect(
      bad.equippedFor(PlayerCharacterId.eloise).mainWeaponId,
      MetaDefaults.mainWeaponId,
    );

    final good = service.equip(
      meta,
      characterId: PlayerCharacterId.eloise,
      slot: GearSlot.spellBook,
      itemId: SpellBookId.bastionCodex,
    );
    expect(
      good.equippedFor(PlayerCharacterId.eloise).spellBookId,
      SpellBookId.bastionCodex,
    );
  });

  test(
    'MetaService.createNew unlocks all swords, shields, and accessories',
    () {
      const service = MetaService();
      final meta = service.createNew();
      final inventory = meta.inventory;

      expect(inventory.unlockedWeaponIds.contains(WeaponId.plainsteel), isTrue);
      expect(inventory.unlockedWeaponIds.contains(WeaponId.graveglass), isTrue);
      expect(
        inventory.unlockedWeaponIds.contains(WeaponId.duelistsOath),
        isTrue,
      );
      expect(inventory.unlockedWeaponIds.contains(WeaponId.roadguard), isTrue);
      expect(
        inventory.unlockedWeaponIds.contains(WeaponId.oathwallRelic),
        isTrue,
      );
      expect(
        inventory.unlockedSpellBookIds.contains(SpellBookId.crownOfFocus),
        isTrue,
      );
      expect(inventory.unlockedAccessoryIds, AccessoryId.values.toSet());
    },
  );

  test('MetaService.normalize keeps full shield roster unlocked', () {
    const service = MetaService();
    final loaded = MetaState.seedAllUnlocked(
      inventory: InventoryState(
        unlockedWeaponIds: WeaponId.values.toSet(),
        unlockedSpellBookIds: SpellBookId.values.toSet(),
        unlockedAccessoryIds: AccessoryId.values.toSet(),
      ),
    );

    final normalized = service.normalize(loaded);
    final inventory = normalized.inventory;

    expect(inventory.unlockedWeaponIds.contains(WeaponId.plainsteel), isTrue);
    expect(inventory.unlockedWeaponIds.contains(WeaponId.graveglass), isTrue);
    expect(
      inventory.unlockedWeaponIds.contains(WeaponId.oathwallRelic),
      isTrue,
    );
    expect(
      inventory.unlockedSpellBookIds.contains(SpellBookId.crownOfFocus),
      isTrue,
    );
    expect(inventory.unlockedAccessoryIds, AccessoryId.values.toSet());
  });

  test(
    'MetaService.normalize grants all primary swords and shields for existing inventories',
    () {
      const service = MetaService();
      final legacy = MetaState(
        schemaVersion: 1,
        inventory: InventoryState(
          unlockedWeaponIds: <WeaponId>{
            WeaponId.plainsteel,
            WeaponId.roadguard,
            WeaponId.thornbark,
          },
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
      expect(unlocked.contains(WeaponId.roadguard), isTrue);
      expect(unlocked.contains(WeaponId.thornbark), isTrue);
      expect(unlocked.contains(WeaponId.cinderWard), isTrue);
      expect(unlocked.contains(WeaponId.tideguardShell), isTrue);
      expect(unlocked.contains(WeaponId.frostlockBuckler), isTrue);
      expect(unlocked.contains(WeaponId.ironBastion), isTrue);
      expect(unlocked.contains(WeaponId.stormAegis), isTrue);
      expect(unlocked.contains(WeaponId.nullPrism), isTrue);
      expect(unlocked.contains(WeaponId.warbannerGuard), isTrue);
      expect(unlocked.contains(WeaponId.oathwallRelic), isTrue);
      expect(
        normalized.inventory.unlockedAccessoryIds,
        AccessoryId.values.toSet(),
      );
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
    final rosterShield = offhandCandidates.firstWhere(
      (candidate) => candidate.id == WeaponId.oathwallRelic,
    );

    expect(graveglass.isUnlocked, isTrue);
    expect(plainsteel.isUnlocked, isTrue);
    expect(rosterShield.isUnlocked, isTrue);
  });

  test('MetaService.candidatesForSlot returns spellbook entries', () {
    const service = MetaService();
    final meta = service.createNew();

    final spellBookCandidates = service.candidatesForSlot(
      meta,
      GearSlot.spellBook,
    );
    final ids = spellBookCandidates.map((candidate) => candidate.id).toList();

    expect(ids, contains(SpellBookId.apprenticePrimer));
    expect(ids, contains(SpellBookId.crownOfFocus));
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
          unlockedSpellBookIds: <SpellBookId>{
            SpellBookId.apprenticePrimer,
            SpellBookId.bastionCodex,
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

  test('MetaState load migrates legacy accessory runtime id to ironBoots', () {
    const service = MetaService();
    final fallback = service.createNew();
    final raw = <String, dynamic>{
      'schemaVersion': 1,
      'inventory': <String, Object?>{
        'weapons': <String>[for (final id in WeaponId.values) id.name],
        'throwingWeapons': <String>[
          for (final id in ProjectileId.values) id.name,
        ],
        'spellBooks': <String>[for (final id in SpellBookId.values) id.name],
        'accessories': <String>['ironBracers'],
      },
      'equippedByCharacter': <String, Object?>{
        for (final id in PlayerCharacterId.values)
          id.name: <String, Object?>{
            'mainWeaponId': MetaDefaults.mainWeaponId.name,
            'offhandWeaponId': MetaDefaults.offhandWeaponId.name,
            'spellBookId': MetaDefaults.spellBookId.name,
            'accessoryId': 'ironBracers',
          },
      },
      'spellListByCharacter': <String, Object?>{
        for (final id in PlayerCharacterId.values)
          id.name: SpellList.empty.toJson(),
      },
    };

    final loaded = MetaState.fromJson(raw, fallback: fallback);
    final normalized = service.normalize(loaded);

    expect(
      normalized.equippedFor(PlayerCharacterId.eloise).accessoryId,
      AccessoryId.ironBoots,
    );
    expect(
      normalized.equippedFor(PlayerCharacterId.eloiseWip).accessoryId,
      AccessoryId.ironBoots,
    );
  });
}
