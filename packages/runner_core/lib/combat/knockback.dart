/// Which authored hit may carry a shove; a missed finisher never falls back.
enum KnockbackTrigger { everyHit, comboFinisher }

/// Optional horizontal displacement after positive HP loss.
///
/// Distance is unobstructed world-space travel; terrain and body velocity caps
/// may shorten it. Duration is quantized upward to whole simulation ticks.
class KnockbackDef {
  const KnockbackDef({
    required this.distance,
    required this.durationSeconds,
    this.trigger = KnockbackTrigger.everyHit,
  }) : assert(distance > 0 && distance < double.infinity),
       assert(durationSeconds > 0 && durationSeconds < double.infinity);

  final double distance;
  final double durationSeconds;
  final KnockbackTrigger trigger;
}

/// Captured launch origin, retained even if the attacking entity retires.
///
/// World-anchored effects use their caster's origin, rather than their effect
/// center, so a centered pillar has a meaningful push direction.
class KnockbackSource {
  const KnockbackSource({
    required this.effect,
    required this.originX,
    required this.fallbackDirectionX,
  }) : assert(fallbackDirectionX == -1 || fallbackDirectionX == 1);

  final KnockbackDef effect;
  final double originX;
  final int fallbackDirectionX;

  /// Freezes the push direction at contact. Finisher-only effects require the
  /// last authored combo window, regardless of how many earlier strikes landed.
  /// Returns null when that trigger is not met.
  KnockbackHit? resolve(double targetX, {bool isComboFinisher = false}) {
    if (effect.trigger == KnockbackTrigger.comboFinisher && !isComboFinisher) {
      return null;
    }
    return KnockbackHit(
      effect: effect,
      directionX: targetX == originX
          ? fallbackDirectionX
          : (targetX > originX ? 1 : -1),
    );
  }
}

/// Contact-time direction, frozen before damage middleware is evaluated.
class KnockbackHit {
  const KnockbackHit({required this.effect, required this.directionX})
    : assert(directionX == -1 || directionX == 1);

  final KnockbackDef effect;
  final int directionX;
}
