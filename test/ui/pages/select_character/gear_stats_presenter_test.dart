import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/meta/gear_slot.dart';
import 'package:rpg_runner/core/projectiles/projectile_id.dart';
import 'package:rpg_runner/core/weapons/weapon_id.dart';
import 'package:rpg_runner/ui/pages/selectCharacter/gear/gear_stats_presenter.dart';

void main() {
  group('gear stats presenter', () {
    test('main weapon shows proc hook and hides type line', () {
      final lines = gearStatsFor(GearSlot.mainWeapon, WeaponId.cinderedge);
      final typeLine = lines.where((line) => line.label == 'Type');
      final procHookLine = lines.where((line) => line.label == 'On Crit');
      expect(typeLine, isEmpty);
      expect(procHookLine.single.value, contains('Applies Burn'));
      expect(procHookLine.single.value, contains('5 damage per second'));
      expect(lines.last.label, equals('On Crit'));
    });

    test('hides ballistic line for throwing axe', () {
      final lines = gearStatsFor(
        GearSlot.throwingWeapon,
        ProjectileId.throwingAxe,
      );
      final hasBallistic = lines.any((line) => line.label == 'Ballistic');
      expect(hasBallistic, isFalse);
    });

    test('hides ballistic line for throwing knife', () {
      final lines = gearStatsFor(
        GearSlot.throwingWeapon,
        ProjectileId.throwingKnife,
      );
      final hasBallistic = lines.any((line) => line.label == 'Ballistic');
      expect(hasBallistic, isFalse);
    });

    test('throwing weapon hides type line', () {
      final lines = gearStatsFor(
        GearSlot.throwingWeapon,
        ProjectileId.throwingAxe,
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

    test('bleed proc uses semantic status naming', () {
      final lines = gearStatsFor(GearSlot.mainWeapon, WeaponId.waspfang);
      final onHitLine = lines.firstWhere((line) => line.label == 'On Hit');

      expect(onHitLine.value, contains('Applies Bleed'));
      expect(onHitLine.value, isNot(contains('Physical damage-over-time')));
    });

    test('base stat tone is positive for positive values', () {
      final lines = gearStatsFor(GearSlot.mainWeapon, WeaponId.plainsteel);
      final powerLine = lines.firstWhere((line) => line.label == 'Power');

      expect(powerLine.value, equals('+10%'));
      expect(powerLine.tone, GearStatLineTone.positive);
    });

    test('base stat tone is negative for negative values', () {
      final lines = gearStatsFor(GearSlot.mainWeapon, WeaponId.graveglass);
      final defenseLine = lines.firstWhere((line) => line.label == 'Defense');

      expect(defenseLine.value, equals('-15%'));
      expect(defenseLine.tone, GearStatLineTone.negative);
    });

    test('negative status lines expose negative highlight tokens', () {
      final lines = gearStatsFor(GearSlot.mainWeapon, WeaponId.frostbrand);
      final onHitLine = lines.firstWhere((line) => line.label == 'On Hit');

      expect(onHitLine.highlights, isNotEmpty);
      expect(
        onHitLine.highlights.any(
          (entry) =>
              entry.token == 'Slow' && entry.tone == GearStatLineTone.negative,
        ),
        isTrue,
      );
      expect(
        onHitLine.highlights.any(
          (entry) =>
              entry.token == '25%' && entry.tone == GearStatLineTone.negative,
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
  });
}
