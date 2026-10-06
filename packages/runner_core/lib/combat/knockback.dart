/// Optional horizontal displacement after positive HP loss.
///
/// Distance is unobstructed world-space travel; terrain and body velocity caps
/// may shorten it. Duration is quantized upward to whole simulation ticks.
class KnockbackDef {
  const KnockbackDef({required this.distance, required this.durationSeconds})
    : assert(distance > 0 && distance < double.infinity),
      assert(durationSeconds > 0 && durationSeconds < double.infinity);

  final double distance;
  final double durationSeconds;
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

  KnockbackHit resolve(double targetX) => KnockbackHit(
    effect: effect,
    directionX: targetX == originX
        ? fallbackDirectionX
        : (targetX > originX ? 1 : -1),
  );
}

/// Contact-time direction, frozen before damage middleware is evaluated.
class KnockbackHit {
  const KnockbackHit({required this.effect, required this.directionX})
    : assert(directionX == -1 || directionX == 1);

  final KnockbackDef effect;
  final int directionX;
}
