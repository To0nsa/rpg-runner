import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/ui/haptics/haptics_cue.dart';
import 'package:rpg_runner/ui/haptics/haptics_driver.dart';
import 'package:rpg_runner/ui/haptics/haptics_service.dart';

void main() {
  test('maps cues to default intensity channels', () {
    final driver = _FakeHapticsDriver();
    final haptics = UiHapticsService(driver: driver);

    haptics.trigger(UiHapticsCue.chargeHalfTierReached);
    haptics.trigger(UiHapticsCue.chargeFullTierReached);
    haptics.trigger(UiHapticsCue.holdAbilityStaminaDepleted);
    haptics.trigger(UiHapticsCue.holdAbilityTimedOut);

    expect(
      driver.calls,
      equals(<String>['selection', 'light', 'medium', 'heavy']),
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
  void heavyImpact() => calls.add('heavy');

  @override
  void lightImpact() => calls.add('light');

  @override
  void mediumImpact() => calls.add('medium');

  @override
  void selectionClick() => calls.add('selection');
}
