part of 'game_event.dart';

/// Emitted when a non-projectile spell impact executes.
///
/// Used by the renderer to spawn one-shot impact VFX at a world position.
class SpellImpactEvent extends GameEvent {
  const SpellImpactEvent({
    required this.tick,
    required this.impactId,
    required this.pos,
    this.sourceEnemyId,
    this.abilityId,
  });

  /// Simulation tick when the impact occurred.
  final int tick;

  final SpellImpactId impactId;
  final Vec2 pos;

  /// Optional source enemy metadata for UI/debug purposes.
  final EnemyId? sourceEnemyId;

  /// Optional source ability metadata.
  final AbilityKey? abilityId;
}
