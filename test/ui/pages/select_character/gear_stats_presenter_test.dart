import 'package:rpg_runner/ui/l10n/app_localization.dart';
import 'package:game_presentation/game_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/accessories/accessory_id.dart';
import 'package:runner_core/meta/gear_slot.dart';
import 'package:runner_core/spellBook/spell_book_id.dart';
import 'package:runner_core/weapons/weapon_id.dart';
import 'package:rpg_runner/ui/pages/selectCharacter/gear/gear_stats_presenter.dart';

void main() {
  test('Willow uses Supplies in stats, comparison and rich sustain text', () {
    final field = gearStatsFor(
      GearSlot.spellBook,
      SpellBookId.hunterFieldKit,
      manaPresentation: ManaPresentation.supplies,
      strings: gameStringsFor(null),
      l10n: appStringsFor(null),
    );
    expect(field.any((line) => line.label.contains('Supplies')), isTrue);
    final comparison = gearCompareStats(
      GearSlot.spellBook,
      equipped: SpellBookId.hunterFieldKit,
      candidate: SpellBookId.hunterLongtrailPack,
      manaPresentation: ManaPresentation.supplies,
      strings: gameStringsFor(null),
      l10n: appStringsFor(null),
    );
    expect(comparison.any((line) => line.label.contains('Supplies')), isTrue);
    final lines = gearStatsFor(
      GearSlot.accessory,
      AccessoryId.diamondRing,
      manaPresentation: ManaPresentation.supplies,
      strings: gameStringsFor(null),
      l10n: appStringsFor(null),
    );
    final text = [
      for (final line in lines)
        '${line.label} ${line.value} ${line.semanticValue?.segments.map((s) => s.text).join()}',
    ].join();
    expect(text, contains('Supplies'));
    expect(text.toLowerCase(), isNot(contains('mana')));
    expect(
      gearStatsFor(
        GearSlot.accessory,
        AccessoryId.diamondRing,
        strings: gameStringsFor(null),
        l10n: appStringsFor(null),
      ).any((line) => line.label.contains('Mana')),
      isTrue,
    );
  });

  group('gear stats presenter', () {
    test('main weapon shows proc hook and hides type line', () {
      final lines = gearStatsFor(
        GearSlot.mainWeapon,
        WeaponId.cinderedge,
        strings: gameStringsFor(null),
        l10n: appStringsFor(null),
      );
      final typeLine = lines.where((line) => line.label == 'Type');
      final procHookLine = lines.where((line) => line.label == 'On Crit');
      expect(typeLine, isEmpty);
      expect(procHookLine.single.value, contains('Applies Burn'));
      expect(procHookLine.single.value, contains('5 seconds'));
      expect(lines.last.label, equals('On Crit'));
    });

    test('hides ballistic line for spellbook', () {
      final lines = gearStatsFor(
        GearSlot.spellBook,
        SpellBookId.apprenticePrimer,
        strings: gameStringsFor(null),
        l10n: appStringsFor(null),
      );
      final hasBallistic = lines.any((line) => line.label == 'Ballistic');
      expect(hasBallistic, isFalse);
    });

    test('hides ballistic line for alternate spellbook', () {
      final lines = gearStatsFor(
        GearSlot.spellBook,
        SpellBookId.emberGrimoire,
        strings: gameStringsFor(null),
        l10n: appStringsFor(null),
      );
      final hasBallistic = lines.any((line) => line.label == 'Ballistic');
      expect(hasBallistic, isFalse);
    });

    test('spellbook hides type line', () {
      final lines = gearStatsFor(
        GearSlot.spellBook,
        SpellBookId.apprenticePrimer,
        strings: gameStringsFor(null),
        l10n: appStringsFor(null),
      );
      final hasType = lines.any((line) => line.label == 'Type');
      expect(hasType, isFalse);
    });

    test('on kill line shows effect details', () {
      final lines = gearStatsFor(
        GearSlot.mainWeapon,
        WeaponId.sunlitVow,
        strings: gameStringsFor(null),
        l10n: appStringsFor(null),
      );
      final onKillLine = lines.where((line) => line.label == 'On Kill');
      expect(onKillLine.single.value, contains('Offense Buff'));
      expect(onKillLine.single.value, contains('35% chance'));
      expect(onKillLine.single.value, contains('5 seconds'));
    });

    test('offhand can show reactive proc hook labels', () {
      final onDamagedLines = gearStatsFor(
        GearSlot.offhandWeapon,
        WeaponId.thornbark,
        strings: gameStringsFor(null),
        l10n: appStringsFor(null),
      );
      final onLowHealthLines = gearStatsFor(
        GearSlot.offhandWeapon,
        WeaponId.oathwallRelic,
        strings: gameStringsFor(null),
        l10n: appStringsFor(null),
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
      final lines = gearStatsFor(
        GearSlot.mainWeapon,
        WeaponId.waspfang,
        strings: gameStringsFor(null),
        l10n: appStringsFor(null),
      );
      final onHitLine = lines.firstWhere((line) => line.label == 'On Hit');

      expect(onHitLine.value, contains('Applies Bleed'));
      expect(onHitLine.value, isNot(contains('Physical damage-over-time')));
    });

    test('base stat tone is positive for positive values', () {
      final lines = gearStatsFor(
        GearSlot.mainWeapon,
        WeaponId.plainsteel,
        strings: gameStringsFor(null),
        l10n: appStringsFor(null),
      );
      final powerLine = lines.firstWhere((line) => line.label == 'Power');

      expect(powerLine.value, equals('+15%'));
      expect(powerLine.tone, GearStatLineTone.positive);
    });

    test('base stat tone is negative for negative values', () {
      final lines = gearStatsFor(
        GearSlot.mainWeapon,
        WeaponId.plainsteel,
        strings: gameStringsFor(null),
        l10n: appStringsFor(null),
      );
      final defenseLine = lines.firstWhere((line) => line.label == 'Defense');

      expect(defenseLine.value, equals('-5%'));
      expect(defenseLine.tone, GearStatLineTone.negative);
    });

    test('base stats place negative lines before positive lines', () {
      final lines = gearStatsFor(
        GearSlot.offhandWeapon,
        WeaponId.roadguard,
        strings: gameStringsFor(null),
        l10n: appStringsFor(null),
      );
      final firstPositiveIndex = lines.indexWhere(
        (line) => line.tone == GearStatLineTone.positive,
      );
      final lastNegativeIndex = lines.lastIndexWhere(
        (line) => line.tone == GearStatLineTone.negative,
      );

      expect(lastNegativeIndex, greaterThanOrEqualTo(0));
      expect(firstPositiveIndex, greaterThanOrEqualTo(0));
      expect(lastNegativeIndex, lessThan(firstPositiveIndex));
    });

    test('negative status lines expose negative highlight tokens', () {
      final lines = gearStatsFor(
        GearSlot.mainWeapon,
        WeaponId.cinderedge,
        strings: gameStringsFor(null),
        l10n: appStringsFor(null),
      );
      final onCritLine = lines.firstWhere((line) => line.label == 'On Crit');

      expect(onCritLine.highlights, isNotEmpty);
      expect(
        onCritLine.highlights.any(
          (entry) =>
              entry.token == 'Burn' && entry.tone == GearStatLineTone.negative,
        ),
        isTrue,
      );
      expect(
        onCritLine.highlights.any(
          (entry) =>
              entry.token == '3' && entry.tone == GearStatLineTone.negative,
        ),
        isTrue,
      );
    });

    test('positive status lines expose positive highlight tokens', () {
      final lines = gearStatsFor(
        GearSlot.mainWeapon,
        WeaponId.sunlitVow,
        strings: gameStringsFor(null),
        l10n: appStringsFor(null),
      );
      final onKillLine = lines.firstWhere((line) => line.label == 'On Kill');

      expect(onKillLine.highlights, isNotEmpty);
      expect(
        onKillLine.highlights.any(
          (entry) =>
              entry.token == 'Offense Buff' &&
              entry.tone == GearStatLineTone.positive,
        ),
        isTrue,
      );
      expect(
        onKillLine.highlights.any(
          (entry) =>
              entry.token == '25%' && entry.tone == GearStatLineTone.positive,
        ),
        isTrue,
      );
    });

    test('accessory base lines include regen stats', () {
      final lines = gearStatsFor(
        GearSlot.accessory,
        AccessoryId.oathBeads,
        strings: gameStringsFor(null),
        l10n: appStringsFor(null),
      );
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
        candidate: AccessoryId.oathBeads,
        strings: gameStringsFor(null),
        l10n: appStringsFor(null),
      );
      final manaRegenLine = lines.firstWhere(
        (line) => line.label == 'Mana Regen',
      );

      expect(manaRegenLine.value, equals('+10%'));
      expect(manaRegenLine.tone, GearStatLineTone.positive);
    });

    test('accessory can show reactive low-health proc hook labels', () {
      final lines = gearStatsFor(
        GearSlot.accessory,
        AccessoryId.goldenRing,
        strings: gameStringsFor(null),
        l10n: appStringsFor(null),
      );
      final onLowHealthLine = lines.where(
        (line) => line.label == 'On Low Health',
      );

      expect(onLowHealthLine.single.value, contains('Restores Health'));
      expect(onLowHealthLine.single.value, contains('35%'));
    });
  });
}
