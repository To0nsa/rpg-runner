import 'game_event.dart';

/// Coalesces and throttles player impact feedback events.
///
/// Rules:
/// - Only direct impacts should be recorded (status effect ticks are ignored).
/// - Multiple direct impacts in the same tick are coalesced into one event.
/// - At most one event can be emitted per second (`tickHz` ticks).
class PlayerImpactFeedbackGate {
  PlayerImpactFeedbackGate({required this.tickHz})
    : assert(tickHz > 0, 'tickHz must be > 0');

  final int tickHz;

  int _nextAllowedTick = 0;
  int _pendingTick = -1;
  int _pendingAmount100 = 0;
  DeathSourceKind _pendingSourceKind = DeathSourceKind.unknown;

  /// Records a damage application candidate for this tick.
  void recordAppliedDamage({
    required int tick,
    required bool playerTarget,
    required int appliedAmount100,
    required DeathSourceKind sourceKind,
  }) {
    if (!playerTarget) return;
    if (appliedAmount100 <= 0) return;
    if (sourceKind == DeathSourceKind.statusEffect) return;
    if (tick < _nextAllowedTick) return;

    if (_pendingTick != tick) {
      _pendingTick = tick;
      _pendingAmount100 = appliedAmount100;
      _pendingSourceKind = sourceKind;
      return;
    }

    if (appliedAmount100 > _pendingAmount100) {
      _pendingAmount100 = appliedAmount100;
      _pendingSourceKind = sourceKind;
    }
  }

  /// Emits the coalesced event for [tick], if any.
  PlayerImpactFeedbackEvent? flushTick(int tick) {
    if (_pendingTick != tick) return null;

    final event = PlayerImpactFeedbackEvent(
      tick: tick,
      amount100: _pendingAmount100,
      sourceKind: _pendingSourceKind,
    );
    _nextAllowedTick = tick + tickHz;
    _clearPending();
    return event;
  }

  void _clearPending() {
    _pendingTick = -1;
    _pendingAmount100 = 0;
    _pendingSourceKind = DeathSourceKind.unknown;
  }
}
