import '../ecs/entity_id.dart';

/// One attack activation with ordered, independently damaging strikes.
///
/// Source-animation frames start each strike; intervening poses share its hit
/// ledger. Any actor can author a combo on a melee or world-anchored profile.
final class CombatCombo {
  const CombatCombo({required this.strikeStartFrames});

  /// At least two strictly increasing frame indices within the attack profile.
  final List<int> strikeStartFrames;

  /// Zero before the opener, then a one-based strike window.
  int strikeWindowAt(int frame) {
    var window = 0;
    for (final start in strikeStartFrames) {
      if (frame < start) break;
      window++;
    }
    return window;
  }

  /// Rejects malformed authored combos before their hitbox joins the world.
  void validate(int frameCount) {
    if (strikeStartFrames.length < 2) {
      throw ArgumentError('A combat combo requires at least two strikes.');
    }
    var previous = -1;
    for (final frame in strikeStartFrames) {
      if (frame <= previous || frame >= frameCount) {
        throw ArgumentError(
          'Combo strike frames must increase within the profile.',
        );
      }
      previous = frame;
    }
  }
}

/// Captured provenance for one strike in a deterministic combo activation.
///
/// Activation IDs are allocated by the world's hitbox store and never recycled.
/// Enemy type or ability identity alone must never authorize a follow-up hit.
final class ComboHit {
  const ComboHit({
    required this.source,
    required this.activation,
    required this.strike,
  });

  final EntityId source;
  final int activation;
  final int strike;

  /// Only a later strike from this exact attacker and activation may follow.
  bool follows(ComboHit? previous) =>
      previous != null &&
      source == previous.source &&
      activation == previous.activation &&
      strike > previous.strike;
}
