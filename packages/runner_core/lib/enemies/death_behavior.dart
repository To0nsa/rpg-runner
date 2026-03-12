/// Enemy death behavior configuration (data-driven).
library;

/// Determines how an enemy transitions from "killed" to final despawn.
enum DeathBehavior {
  /// Start the death animation immediately on kill.
  instant,

  /// If killed mid-air, fall until grounded before starting the death animation.
  groundImpactThenDeath,
}

/// Runtime death phase for enemies that are waiting to despawn.
enum DeathPhase {
  none,
  fallingUntilGround,
  deathAnim,
}

