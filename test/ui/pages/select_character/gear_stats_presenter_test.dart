import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/accessories/accessory_id.dart';
import 'package:rpg_runner/core/meta/gear_slot.dart';
import 'package:rpg_runner/core/spellBook/spell_book_id.dart';
import 'package:rpg_runner/core/weapons/weapon_id.dart';
import 'package:rpg_runner/ui/pages/selectCharacter/gear/gear_stats_presenter.dart';

void main() {
  group('gear stats presenter', () {
    test('main weapon shows proc hook and hides type line', () {
      final lines = gearStatsFor(GearSlot.mainWeapon, WeaponId.cinderedge);
      final typeLine = lines.where((line) => line.label == 'Type');
      final procHookLine = lines.where((line) => line.label == 'On Crit');
      expect(typeLine, isEmpty);
      expect(procHookLine.single.value, contains('Applies Stun'));
      expect(procHookLine.single.value, contains('20%'));
      expect(lines.last.label, equals('On Crit'));
    });

    test('hides ballistic line for spellbook', () {
      final lines = gearStatsFor(
        GearSlot.spellBook,
        SpellBookId.apprenticePrimer,
      );
      final hasBallistic = lines.any((line) => line.label == 'Ballistic');
      expect(hasBallistic, isFalse);
    });

    test('hides ballistic line for alternate spellbook', () {
      final lines = gearStatsFor(GearSlot.spellBook, SpellBookId.emberGrimoire);
      final hasBallistic = lines.any((line) => line.label == 'Ballistic');
      expect(hasBallistic, isFalse);
    });

    test('spellbook hides type line', () {
      final lines = gearStatsFor(
        GearSlot.spellBook,
        SpellBookId.apprenticePrimer,
      );
      final hasType = lines.any((line) => line.label == 'Type');
      expect(hasType, isFalse);
    });

    test('on kill line shows effect details', () {
      final lines = gearStatsFor(GearSlot.mainWeapon, WeaponId.sunlitVow);
      final onKillLine = lines.where((line) => line.label == 'On Kill');
      expect(onKillLine.single.value, contains('Haste'));
      expect(onKillLine.single.value, contains('5 seconds'));
    });

    test('offhand can show reactive proc hook labels', () {
      final onDamagedLines = gearStatsFor(
        GearSlot.offhandWeapon,
        WeaponId.thornbark,
      );
      final onLowHealthLines = gearStatsFor(
        GearSlot.offhandWeapon,
        WeaponId.oathwallRelic,
      );

      final onDamagedLine = onDamagedLines.where(
        (line) => line.label == 'On Damaged',
      );
      final onLowHealthLine = onLowHealthLines.where(
        (line) => line.label == 'On Low Health',
      );

      expect(onDamagedLine.single.value, contains('Bleed'));
      expect(onLowHealthLine.single.value, contains('Haste'));
    });

    test('bleed proc uses semantic status naming', () {
      final lines = gearStatsFor(GearSlot.mainWeapon, WeaponId.waspfang);
      final onHitLine = lines.firstWhere((line) => line.label == 'On Hit');

      expect(onHitLine.value, contains('Applies Bleed'));
      expect(onHitLine.value, isNot(contains('Physical damage-over-time')));
    });

    test('base stat tone is positive for positive values', () {
      final lines = gearStatsFor(GearSlot.mainWeapon, WeaponId.plainsteel);
      final powerLine = lines.firstWhere((line) => line.label == 'Power');

      expect(powerLine.value, equals('+15%'));
      expect(powerLine.tone, GearStatLineTone.positive);
    });

    test('base stat tone is negative for negative values', () {
      final lines = gearStatsFor(GearSlot.mainWeapon, WeaponId.plainsteel);
      final defenseLine = lines.firstWhere((line) => line.label == 'Defense');

      expect(defenseLine.value, equals('-5%'));
      expect(defenseLine.tone, GearStatLineTone.negative);
    });

    test('negative status lines expose negative highlight tokens', () {
      final lines = gearStatsFor(GearSlot.mainWeapon, WeaponId.cinderedge);
      final onCritLine = lines.firstWhere((line) => line.label == 'On Crit');

      expect(onCritLine.highlights, isNotEmpty);
      expect(
        onCritLine.highlights.any(
          (entry) =>
              entry.token == 'Stun' && entry.tone == GearStatLineTone.negative,
        ),
        isTrue,
      );
      expect(
        onCritLine.highlights.any(
          (entry) =>
              entry.token == '20%' && entry.tone == GearStatLineTone.negative,
        ),
        isTrue,
      );
    });

    test('positive status lines expose positive highlight tokens', () {
      final lines = gearStatsFor(GearSlot.mainWeapon, WeaponId.sunlitVow);
      final onKillLine = lines.firstWhere((line) => line.label == 'On Kill');

      expect(onKillLine.highlights, isNotEmpty);
      expect(
        onKillLine.highlights.any(
          (entry) =>
              entry.token == 'Haste' && entry.tone == GearStatLineTone.positive,
        ),
        isTrue,
      );
      expect(
        onKillLine.highlights.any(
          (entry) =>
              entry.token == '50%' && entry.tone == GearStatLineTone.positive,
        ),
        isTrue,
      );
    });

    test('accessory base lines include regen stats', () {
      final lines = gearStatsFor(GearSlot.accessory, AccessoryId.diamondRing);
      final manaRegenLine = lines.firstWhere(
        (line) => line.label == 'Mana Regen',
      );

      expect(manaRegenLine.value, equals('+10%'));
      expect(manaRegenLine.tone, GearStatLineTone.positive);
    });

    test('accessory compare includes regen deltas', () {
      final lines = gearCompareStats(
        GearSlot.accessory,
        equipped: AccessoryId.speedBoots,
        candidate: AccessoryId.diamondRing,
      );
      final manaRegenLine = lines.firstWhere(
        (line) => line.label == 'Mana Regen',
      );

      expect(manaRegenLine.value, equals('+10%'));
      expect(manaRegenLine.tone, GearStatLineTone.positive);
    });

    test('accessory can show reactive low-health proc hook labels', () {
      final lines = gearStatsFor(GearSlot.accessory, AccessoryId.goldenRing);
      final onLowHealthLine = lines.where(
        (line) => line.label == 'On Low Health',
      );

      expect(onLowHealthLine.single.value, contains('Restores Health'));
      expect(onLowHealthLine.single.value, contains('35%'));
    });
  });
}
