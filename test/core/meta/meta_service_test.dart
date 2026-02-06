import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/accessories/accessory_id.dart';
import 'package:rpg_runner/core/meta/gear_slot.dart';
import 'package:rpg_runner/core/meta/inventory_state.dart';
import 'package:rpg_runner/core/meta/meta_defaults.dart';
import 'package:rpg_runner/core/meta/meta_service.dart';
import 'package:rpg_runner/core/meta/meta_state.dart';
import 'package:rpg_runner/core/players/player_character_definition.dart';
import 'package:rpg_runner/core/projectiles/projectile_item_id.dart';
import 'package:rpg_runner/core/spells/spell_book_id.dart';
import 'package:rpg_runner/core/weapons/weapon_id.dart';

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
      itemId: ProjectileItemId.throwingAxe,
    );
    expect(
      good.equippedFor(PlayerCharacterId.eloise).throwingWeaponId,
      ProjectileItemId.throwingAxe,
    );
  });

  test('MetaService.createNew locks third-tier gear by default', () {
    const service = MetaService();
    final meta = service.createNew();
    final inventory = meta.inventory;

    expect(inventory.unlockedWeaponIds.contains(WeaponId.solidSword), isFalse);
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
          unlockedThrowingWeaponIds: ProjectileItemId.values.toSet(),
          unlockedSpellBookIds: SpellBookId.values.toSet(),
          unlockedAccessoryIds: AccessoryId.values.toSet(),
        ),
      );

      final normalized = service.normalize(loaded);
      final inventory = normalized.inventory;

      expect(
        inventory.unlockedWeaponIds.contains(WeaponId.solidSword),
        isFalse,
      );
      expect(
        inventory.unlockedWeaponIds.contains(WeaponId.solidShield),
        isFalse,
      );
      expect(
        inventory.unlockedThrowingWeaponIds.contains(
          ProjectileItemId.thunderBolt,
        ),
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

  test('MetaService.candidatesForSlot includes locked entries', () {
    const service = MetaService();
    final meta = service.createNew();

    final mainCandidates = service.candidatesForSlot(meta, GearSlot.mainWeapon);
    final solidSword = mainCandidates.firstWhere(
      (candidate) => candidate.id == WeaponId.solidSword,
    );
    final basicSword = mainCandidates.firstWhere(
      (candidate) => candidate.id == WeaponId.basicSword,
    );

    expect(solidSword.isUnlocked, isFalse);
    expect(basicSword.isUnlocked, isTrue);
  });

  test('MetaService.candidatesForSlot returns throwing weapons only', () {
    const service = MetaService();
    final meta = service.createNew();

    final throwingCandidates = service.candidatesForSlot(
      meta,
      GearSlot.throwingWeapon,
    );
    final ids = throwingCandidates.map((candidate) => candidate.id).toList();

    expect(ids, contains(ProjectileItemId.throwingKnife));
    expect(ids, contains(ProjectileItemId.throwingAxe));
    expect(ids, isNot(contains(ProjectileItemId.thunderBolt)));
  });
}
