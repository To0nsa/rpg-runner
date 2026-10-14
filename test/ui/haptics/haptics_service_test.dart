import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/ui/haptics/haptics_cue.dart';
import 'package:rpg_runner/ui/haptics/haptics_driver.dart';
import 'package:rpg_runner/ui/haptics/haptics_service.dart';

void main() {
  test('every player combo hit reaches the vibration driver', () {
    final driver = _FakeHapticsDriver();
    final haptics = UiHapticsService(driver: driver);
    for (var hit = 0; hit < 4; hit++) {
      haptics.trigger(UiHapticsCue.playerHit);
    }
    expect(driver.calls, List.filled(4, 'vibration'));
  });

  test('maps cues to default intensity channels', () {
    final driver = _FakeHapticsDriver();
    final haptics = UiHapticsService(driver: driver);

    haptics.trigger(UiHapticsCue.chargeHalfTierReached);
    haptics.trigger(UiHapticsCue.playerLandedHit);
    haptics.trigger(UiHapticsCue.chargeFullTierReached);
    haptics.trigger(UiHapticsCue.holdAbilityStaminaDepleted);
    haptics.trigger(UiHapticsCue.holdAbilityTimedOut);
    haptics.trigger(UiHapticsCue.playerHit);
    haptics.trigger(UiHapticsCue.bossEntrancePulse);

    expect(
      driver.calls,
      equals(<String>[
        'selection',
        'light',
        'light',
        'medium',
        'heavy',
        'vibration',
        'medium',
      ]),
    );
  });

  test('intensity override wins over default cue mapping', () {
    final driver = _FakeHapticsDriver();
    final haptics = UiHapticsService(driver: driver);

    haptics.trigger(
      UiHapticsCue.chargeHalfTierReached,
      intensityOverride: UiHapticsIntensity.heavy,
    );

    expect(driver.calls, equals(<String>['heavy']));
  });

  test('disabled service suppresses all output', () {
    final driver = _FakeHapticsDriver();
    final haptics = UiHapticsService(enabled: false, driver: driver);

    haptics.trigger(UiHapticsCue.holdAbilityTimedOut);
    expect(driver.calls, isEmpty);
  });
}

class _FakeHapticsDriver implements UiHapticsDriver {
  final List<String> calls = <String>[];

  @override
  void vibrate() => calls.add('vibration');

  @override
  void heavyImpact() => calls.add('heavy');

  @override
  void lightImpact() => calls.add('light');

  @override
  void mediumImpact() => calls.add('medium');

  @override
  void selectionClick() => calls.add('selection');
}
