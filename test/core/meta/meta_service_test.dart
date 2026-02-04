import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/meta/gear_slot.dart';
import 'package:rpg_runner/core/meta/meta_defaults.dart';
import 'package:rpg_runner/core/meta/meta_service.dart';
import 'package:rpg_runner/core/players/player_character_definition.dart';
import 'package:rpg_runner/core/projectiles/projectile_item_id.dart';
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
}
