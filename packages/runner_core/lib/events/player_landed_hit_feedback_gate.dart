import '../combat/damage_credit.dart';
import 'game_event.dart';

/// Emits one local feedback cue per tick with accepted player-owned enemy damage.
class PlayerLandedHitFeedbackGate {
  int _lastEmittedTick = -1;

  /// Returns a cue only for positive direct damage credited to the player.
  ///
  /// Repeated qualifying hits in the same tick share one haptic cue.
  PlayerLandedHitFeedbackEvent? eventForAppliedDamage({
    required int tick,
    required bool enemyTarget,
    required DamageCredit credit,
    required int appliedAmount100,
    required DeathSourceKind sourceKind,
  }) {
    if (!enemyTarget ||
        credit != DamageCredit.player ||
        appliedAmount100 <= 0 ||
        sourceKind == DeathSourceKind.statusEffect ||
        tick == _lastEmittedTick) {
      return null;
    }
    _lastEmittedTick = tick;
    return PlayerLandedHitFeedbackEvent(tick: tick);
  }
}
