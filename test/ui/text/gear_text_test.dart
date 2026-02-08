import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/accessories/accessory_id.dart';
import 'package:rpg_runner/core/meta/gear_slot.dart';
import 'package:rpg_runner/core/projectiles/projectile_item_id.dart';
import 'package:rpg_runner/core/spells/spell_book_id.dart';
import 'package:rpg_runner/core/weapons/weapon_id.dart';
import 'package:rpg_runner/ui/text/gear_text.dart';

void main() {
  group('gear text', () {
    test('slot display names are resolved from UI mappings', () {
      expect(
        gearDisplayNameForSlot(GearSlot.mainWeapon, WeaponId.basicSword),
        equals('Basic Sword'),
      );
      expect(
        gearDisplayNameForSlot(
          GearSlot.throwingWeapon,
          ProjectileItemId.throwingKnife,
        ),
        equals('Throwing Knife'),
      );
      expect(
        gearDisplayNameForSlot(GearSlot.spellBook, SpellBookId.epicSpellBook),
        equals('Epic Spellbook'),
      );
      expect(
        gearDisplayNameForSlot(GearSlot.accessory, AccessoryId.goldenRing),
        equals('Golden Ring'),
      );
    });

    test('slot descriptions are resolved from UI mappings', () {
      expect(
        gearDescriptionForSlot(GearSlot.mainWeapon, WeaponId.solidSword),
        equals('Heavier one-handed sword with higher power.'),
      );
      expect(
        gearDescriptionForSlot(
          GearSlot.throwingWeapon,
          ProjectileItemId.fireBolt,
        ),
        equals('Spell projectile that burns on hit.'),
      );
      expect(
        gearDescriptionForSlot(GearSlot.spellBook, SpellBookId.basicSpellBook),
        equals('Starter spell focus with lower output.'),
      );
      expect(
        gearDescriptionForSlot(GearSlot.accessory, AccessoryId.speedBoots),
        equals('Improves move speed.'),
      );
    });

    test('projectile source names use the shared projectile mapping', () {
      expect(projectileItemDisplayName(ProjectileItemId.iceBolt), 'Ice Bolt');
      expect(
        projectileItemDisplayName(ProjectileItemId.throwingAxe),
        'Throwing Axe',
      );
    });
  });
}
