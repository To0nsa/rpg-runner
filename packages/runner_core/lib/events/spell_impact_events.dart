part of 'game_event.dart';

/// A Core-timed one-shot effect, including non-damaging blessings.
///
/// Render attachment never participates in collision or reward resolution.
class SpellImpactEvent extends GameEvent {
  const SpellImpactEvent({
    required this.tick,
    required this.impactId,
    required this.pos,
    this.sourceEnemyId,
    this.abilityId,
    this.followEntityId,
    this.followOffset = Vec2.zero,
  });

  /// Simulation tick when the impact occurred.
  final int tick;

  final SpellImpactId impactId;
  final Vec2 pos;

  /// Optional visual attachment; [pos] remains the fallback if it disappears.
  final int? followEntityId;
  final Vec2 followOffset;

  /// Optional source enemy metadata for UI/debug purposes.
  final EnemyId? sourceEnemyId;

  /// Optional source ability metadata.
  final AbilityKey? abilityId;
}
