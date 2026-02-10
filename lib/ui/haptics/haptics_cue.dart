/// Semantic UI haptic cues.
///
/// Cues let gameplay/UI code request feedback without binding to a specific
/// platform call.
enum UiHapticsCue {
  chargeHalfTierReached,
  chargeFullTierReached,
  holdAbilityTimedOut,
  holdAbilityStaminaDepleted,
}

/// Relative haptic intensity.
enum UiHapticsIntensity { selection, light, medium, heavy }
