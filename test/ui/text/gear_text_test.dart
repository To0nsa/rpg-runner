import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/accessories/accessory_id.dart';
import 'package:rpg_runner/core/meta/gear_slot.dart';
import 'package:rpg_runner/core/projectiles/projectile_id.dart';
import 'package:rpg_runner/core/spellBook/spell_book_id.dart';
import 'package:rpg_runner/core/weapons/weapon_id.dart';
import 'package:rpg_runner/ui/text/gear_text.dart';

void main() {
  group('gear text', () {
    test('slot display names are resolved from UI mappings', () {
      expect(
        gearDisplayNameForSlot(GearSlot.mainWeapon, WeaponId.plainsteel),
        equals('Plainsteel'),
      );
      expect(
        gearDisplayNameForSlot(
          GearSlot.throwingWeapon,
          ProjectileId.throwingKnife,
        ),
        equals('Throwing Knife'),
      );
      expect(
        gearDisplayNameForSlot(GearSlot.spellBook, SpellBookId.crownOfFocus),
        equals('Crown of Focus'),
      );
      expect(
        gearDisplayNameForSlot(GearSlot.accessory, AccessoryId.goldenRing),
        equals('Golden Ring'),
      );
    });

    test('slot descriptions are resolved from UI mappings', () {
      expect(
        gearDescriptionForSlot(GearSlot.mainWeapon, WeaponId.graveglass),
        equals(
          'High-risk amplifier with extra global power and lower defense.',
        ),
      );
      expect(
        gearDescriptionForSlot(GearSlot.throwingWeapon, ProjectileId.fireBolt),
        equals('Spell projectile that burns on hit.'),
      );
      expect(
        gearDescriptionForSlot(
          GearSlot.spellBook,
          SpellBookId.apprenticePrimer,
        ),
        equals('Baseline spellbook with small power and mana gains.'),
      );
      expect(
        gearDescriptionForSlot(GearSlot.accessory, AccessoryId.speedBoots),
        equals('Improves move speed.'),
      );
    });

    test('projectile source names use the shared projectile mapping', () {
      expect(projectileDisplayName(ProjectileId.iceBolt), 'Ice Bolt');
      expect(projectileDisplayName(ProjectileId.throwingAxe), 'Throwing Axe');
    });
  });
}
