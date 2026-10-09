part of 'game_event.dart';

/// Emitted when a projectile hits a damageable target.
///
/// Used by the renderer to spawn impact VFX even though the projectile entity
/// is despawned immediately in Core.
class ProjectileHitEvent extends GameEvent {
  const ProjectileHitEvent({
    required this.tick,
    required this.projectileId,
    required this.pos,
    required this.targetCenter,
    required this.facing,
    required this.rotationRad,
    this.sourceProjectileId,
  });

  /// Simulation tick when the hit occurred.
  final int tick;

  final ProjectileId projectileId;
  final ProjectileId? sourceProjectileId;
  final Vec2 pos;

  /// Struck body-pose center in world units, captured at this hit's tick.
  /// Impact art may use it instead of [pos], the projectile's contact position.
  /// It does not follow later target movement or create another damage area.
  final Vec2 targetCenter;
  final Facing facing;
  final double rotationRad;
}
