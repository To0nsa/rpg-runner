part of 'game_event.dart';

/// Emitted when an enemy is killed (HP reaches 0 and the entity despawns).
///
/// This exists because Core typically despawns dead enemies immediately, so the
/// renderer would otherwise have no chance to play a death animation.
class EnemyKilledEvent extends GameEvent {
  const EnemyKilledEvent({
    required this.tick,
    required this.enemyId,
    required this.pos,
    required this.facing,
    required this.artFacingDir,
  });

  /// Simulation tick when the kill occurred.
  final int tick;

  final EnemyId enemyId;
  final Vec2 pos;
  final Facing facing;
  final Facing artFacingDir;
}
