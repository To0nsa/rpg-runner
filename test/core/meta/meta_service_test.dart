import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/accessories/accessory_id.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/meta/gear_slot.dart';
import 'package:runner_core/meta/ability_ownership_state.dart';
import 'package:runner_core/meta/equipped_gear.dart';
import 'package:runner_core/meta/inventory_state.dart';
import 'package:runner_core/meta/meta_defaults.dart';
import 'package:runner_core/meta/meta_service.dart';
import 'package:runner_core/meta/meta_state.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/players/character_equipment_policy.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/spellBook/spell_book_id.dart';
import 'package:runner_core/weapons/weapon_id.dart';

const Set<ProjectileId> _eloiseStarterProjectileSpells = <ProjectileId>{
  ProjectileId.acidBolt,
  ProjectileId.holyBolt,
};

const Map<AbilitySlot, Set<String>> _eloiseStarterAbilitiesBySlot =
    <AbilitySlot, Set<String>>{
      AbilitySlot.primary: <String>{'eloise.seeker_slash'},
      AbilitySlot.secondary: <String>{'eloise.shield_block'},
      AbilitySlot.projectile: <String>{'eloise.snap_shot'},
      AbilitySlot.mobility: <String>{'eloise.dash'},
      AbilitySlot.spell: <String>{'eloise.arcane_haste', 'eloise.focus'},
      AbilitySlot.jump: <String>{'eloise.jump'},
    };

const _hunterStarterProjectiles = {
  ProjectileId.hunterPistol,
  ProjectileId.hunterCrossbow,
  ProjectileId.hunterShotgun,
};
const _hunterStarterAbilities = {
  AbilitySlot.primary: {'bounty_hunter.quick_cut'},
  AbilitySlot.secondary: {'bounty_hunter.blast_bomb'},
  AbilitySlot.projectile: {'bounty_hunter.snap_shot'},
  AbilitySlot.mobility: {'bounty_hunter.dash'},
  AbilitySlot.spell: {
    'bounty_hunter.hunters_focus',
    'bounty_hunter.prepare_charges',
  },
  AbilitySlot.jump: {'bounty_hunter.jump'},
};

void main() {
  test(
    'ownership discards environmental IDs, including malformed fallbacks',
    () {
      const fallback = AbilityOwnershipState(
        learnedProjectileSpellIds: {
          ProjectileId.poisonDart,
          ProjectileId.unknown,
          ProjectileId.thunderBolt,
        },
        learnedAbilityIdsBySlot: {},
      );
      for (final raw in [
        null,
        ['unknown', 'poisonDart'],
        ['thunderBolt', 'poisonDart'],
      ]) {
        final ownership = AbilityOwnershipState.fromJson({
          'projectileSpells': raw,
        }, fallback: fallback);
        expect(ownership.learnedProjectileSpellIds, {ProjectileId.thunderBolt});
      }
      expect(fallback.toJson()['projectileSpells'], ['thunderBolt']);
    },
  );
  test('MetaService.createNew equips defaults for every character', () {
    const service = MetaService();
    final meta = service.createNew();

    for (final id in PlayerCharacterId.values) {
      final gear = meta.equippedFor(id);
      final defaults = CharacterEquipmentPolicy.defaults(id);
      expect(gear.mainWeaponId, defaults.mainWeaponId);
      expect(gear.offhandWeaponId, defaults.offhandWeaponId);
      expect(gear.spellBookId, defaults.spellBookId);
      expect(gear.accessoryId, MetaDefaults.accessoryId);
    }
  });

  test('MetaService.equip enforces slot categories and starter ownership', () {
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

    final locked = service.equip(
      meta,
      characterId: PlayerCharacterId.eloise,
      slot: GearSlot.spellBook,
      itemId: SpellBookId.bastionCodex,
    );
    expect(
      locked.equippedFor(PlayerCharacterId.eloise).spellBookId,
      MetaDefaults.spellBookId,
    );
  });

  test('MetaService.createNew seeds starter-only unlocked gear', () {
    const service = MetaService();
    final meta = service.createNew();
    final inventory = meta.inventory;

    expect(inventory.unlockedWeaponIds, <WeaponId>{
      WeaponId.plainsteel,
      WeaponId.roadguard,
      WeaponId.hunterBlade,
      WeaponId.hunterBombKit,
    });
    expect(inventory.unlockedSpellBookIds, <SpellBookId>{
      SpellBookId.apprenticePrimer,
      SpellBookId.hunterFieldKit,
    });
    expect(inventory.unlockedAccessoryIds, <AccessoryId>{
      AccessoryId.strengthBelt,
    });
  });

  test('MetaService.normalize trims unlocked gear to starter set', () {
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

    expect(inventory.unlockedWeaponIds, <WeaponId>{
      WeaponId.plainsteel,
      WeaponId.roadguard,
      WeaponId.hunterBlade,
      WeaponId.hunterBombKit,
    });
    expect(inventory.unlockedSpellBookIds, <SpellBookId>{
      SpellBookId.apprenticePrimer,
      SpellBookId.hunterFieldKit,
    });
    expect(inventory.unlockedAccessoryIds, <AccessoryId>{
      AccessoryId.strengthBelt,
    });
  });

  test('MetaService.normalize removes legacy extra unlocks', () {
    const service = MetaService();
    final legacy = MetaState(
      schemaVersion: 1,
      inventory: InventoryState(
        unlockedWeaponIds: <WeaponId>{
          WeaponId.plainsteel,
          WeaponId.roadguard,
          WeaponId.thornbark,
        },
        unlockedSpellBookIds: <SpellBookId>{
          SpellBookId.apprenticePrimer,
          SpellBookId.bastionCodex,
        },
        unlockedAccessoryIds: <AccessoryId>{
          AccessoryId.strengthBelt,
          AccessoryId.speedBoots,
        },
      ),
      equippedByCharacter: <PlayerCharacterId, EquippedGear>{
        for (final id in PlayerCharacterId.values)
          id: MetaDefaults.equippedGear,
      },
      abilityOwnershipByCharacter: <PlayerCharacterId, AbilityOwnershipState>{
        for (final id in PlayerCharacterId.values)
          id: AbilityOwnershipState.empty,
      },
    );

    final normalized = service.normalize(legacy);

    expect(normalized.inventory.unlockedWeaponIds, <WeaponId>{
      WeaponId.plainsteel,
      WeaponId.roadguard,
      WeaponId.hunterBlade,
      WeaponId.hunterBombKit,
    });
    expect(normalized.inventory.unlockedSpellBookIds, <SpellBookId>{
      SpellBookId.apprenticePrimer,
      SpellBookId.hunterFieldKit,
    });
    expect(normalized.inventory.unlockedAccessoryIds, <AccessoryId>{
      AccessoryId.strengthBelt,
    });
  });

  test('MetaService.candidatesForSlot includes sword and shield entries', () {
    const service = MetaService();
    final meta = service.createNew();

    final mainCandidates = service.candidatesForSlot(meta, GearSlot.mainWeapon);
    final stormneedle = mainCandidates.firstWhere(
      (candidate) => candidate.id == WeaponId.stormneedle,
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

    expect(stormneedle.isUnlocked, isFalse);
    expect(plainsteel.isUnlocked, isTrue);
    expect(rosterShield.isUnlocked, isFalse);
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

  test('MetaService.createNew seeds ability ownership per character', () {
    const service = MetaService();
    final meta = service.createNew();

    for (final id in PlayerCharacterId.values) {
      final abilityOwnership = meta.abilityOwnershipFor(id);
      expect(
        abilityOwnership.learnedProjectileSpellIds,
        id == PlayerCharacterId.bountyHunter
            ? _hunterStarterProjectiles
            : _eloiseStarterProjectileSpells,
      );
      for (final slot in AbilitySlot.values) {
        expect(
          abilityOwnership.learnedAbilityIdsForSlot(slot),
          (id == PlayerCharacterId.bountyHunter
              ? _hunterStarterAbilities
              : _eloiseStarterAbilitiesBySlot)[slot],
        );
      }
    }
  });

  test('MetaService.normalize seeds default ability ownership for older schema saves', () {
    const service = MetaService();
    final legacy = MetaState(
      schemaVersion: 1,
      inventory: InventoryState(
        unlockedWeaponIds: service.seedAllUnlockedInventory().unlockedWeaponIds,
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
      abilityOwnershipByCharacter: <PlayerCharacterId, AbilityOwnershipState>{
        for (final id in PlayerCharacterId.values)
          id: AbilityOwnershipState.empty,
      },
    );

    final normalized = service.normalize(legacy);

    for (final id in PlayerCharacterId.values) {
      final abilityOwnership = normalized.abilityOwnershipFor(id);
      expect(
        abilityOwnership.learnedProjectileSpellIds,
        id == PlayerCharacterId.bountyHunter
            ? _hunterStarterProjectiles
            : _eloiseStarterProjectileSpells,
      );
      for (final slot in AbilitySlot.values) {
        expect(
          abilityOwnership.learnedAbilityIdsForSlot(slot),
          (id == PlayerCharacterId.bountyHunter
              ? _hunterStarterAbilities
              : _eloiseStarterAbilitiesBySlot)[slot],
        );
      }
    }
  });

  test(
    'MetaState load with legacy accessory id normalizes to starter accessory',
    () {
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
        'abilityOwnershipByCharacter': <String, Object?>{
          for (final id in PlayerCharacterId.values)
            id.name: AbilityOwnershipState.empty.toJson(),
        },
      };

      final loaded = MetaState.fromJson(raw, fallback: fallback);
      final normalized = service.normalize(loaded);

      expect(
        normalized.equippedFor(PlayerCharacterId.eloise).accessoryId,
        AccessoryId.strengthBelt,
      );
      expect(
        normalized.equippedFor(PlayerCharacterId.eloiseWip).accessoryId,
        AccessoryId.strengthBelt,
      );
    },
  );
}
