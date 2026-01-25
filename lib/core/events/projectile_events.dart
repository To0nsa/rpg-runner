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
    required this.facing,
    required this.rotationRad,
    this.projectileItemId,
  });

  /// Simulation tick when the hit occurred.
  final int tick;

  final ProjectileId projectileId;
  final ProjectileItemId? projectileItemId;
  final Vec2 pos;
  final Facing facing;
  final double rotationRad;
}
