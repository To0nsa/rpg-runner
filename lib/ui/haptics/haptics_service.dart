import 'haptics_cue.dart';
import 'haptics_driver.dart';

/// UI-facing haptics service.
///
/// Consumers should trigger semantic cues instead of raw platform calls.
abstract interface class UiHaptics {
  void trigger(UiHapticsCue cue, {UiHapticsIntensity? intensityOverride});
}

/// Default UI haptics implementation with cue-to-intensity mapping.
class UiHapticsService implements UiHaptics {
  const UiHapticsService({
    this.enabled = true,
    this.driver = const SystemUiHapticsDriver(),
  });

  final bool enabled;
  final UiHapticsDriver driver;

  @override
  void trigger(UiHapticsCue cue, {UiHapticsIntensity? intensityOverride}) {
    if (!enabled) return;
    final intensity = intensityOverride ?? _defaultIntensityFor(cue);
    switch (intensity) {
      case UiHapticsIntensity.selection:
        driver.selectionClick();
      case UiHapticsIntensity.light:
        driver.lightImpact();
      case UiHapticsIntensity.medium:
        driver.mediumImpact();
      case UiHapticsIntensity.heavy:
        driver.heavyImpact();
    }
  }

  UiHapticsIntensity _defaultIntensityFor(UiHapticsCue cue) {
    switch (cue) {
      case UiHapticsCue.chargeHalfTierReached:
        return UiHapticsIntensity.selection;
      case UiHapticsCue.chargeFullTierReached:
        return UiHapticsIntensity.light;
      case UiHapticsCue.holdAbilityTimedOut:
        return UiHapticsIntensity.heavy;
      case UiHapticsCue.holdAbilityStaminaDepleted:
        return UiHapticsIntensity.medium;
      case UiHapticsCue.playerHit:
        return UiHapticsIntensity.medium;
    }
  }
}
