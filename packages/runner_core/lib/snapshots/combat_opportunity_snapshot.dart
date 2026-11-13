/// Read-only opportunity at the current tick, never a promised future hit.
/// Core uses equipped attack geometry and the target's current vulnerable pose.
final class CombatOpportunitySnapshot {
  const CombatOpportunitySnapshot({
    required this.entityId,
    required this.x,
    required this.y,
    required this.playerIdle,
    required this.targetStationary,
    required this.inMeleeReach,
    required this.inProjectileReach,
  });
  final int entityId;
  final double x, y;
  final bool playerIdle, targetStationary, inMeleeReach, inProjectileReach;
}
