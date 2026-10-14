/// Semantic UI haptic cues.
///
/// Cues let gameplay/UI code request feedback without binding to a specific
/// platform call.
enum UiHapticsCue {
  chargeHalfTierReached,
  chargeFullTierReached,
  holdAbilityTimedOut,
  holdAbilityStaminaDepleted,
  playerHit,
  playerLandedHit,
  bossEntrancePulse,
}

/// Platform haptic channels used by UI cues.
enum UiHapticsIntensity { selection, light, medium, heavy, vibration }
