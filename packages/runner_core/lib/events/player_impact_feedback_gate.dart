import 'game_event.dart';

/// Filters applied damage into one feedback event per direct player hit.
/// No time throttle or same-tick coalescing may discard accepted combo strikes.
class PlayerImpactFeedbackGate {
  const PlayerImpactFeedbackGate();

  /// Call once per accepted damage callback, preserving its simulation tick.
  /// Non-player targets, non-positive damage and status ticks produce no event.
  PlayerImpactFeedbackEvent? eventForAppliedDamage({
    required int tick,
    required bool playerTarget,
    required int appliedAmount100,
    required DeathSourceKind sourceKind,
  }) {
    if (!playerTarget ||
        appliedAmount100 <= 0 ||
        sourceKind == DeathSourceKind.statusEffect) {
      return null;
    }
    return PlayerImpactFeedbackEvent(
      tick: tick,
      amount100: appliedAmount100,
      sourceKind: sourceKind,
    );
  }
}
