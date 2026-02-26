import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/meta/gear_slot.dart';
import 'package:rpg_runner/core/projectiles/projectile_id.dart';
import 'package:rpg_runner/ui/pages/selectCharacter/gear/gear_stats_presenter.dart';

void main() {
  group('gear stats presenter', () {
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
  });
}
