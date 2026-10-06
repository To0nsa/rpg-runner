/// Narrative identities for one-shot boss victory blessings, separate from
/// persistent level regeneration modifiers.
enum BossVictoryBlessingId { forestLadies }

/// Core-owned presentation clock that survives arena release and pause/remount.
final class BossVictoryBlessingSnapshot {
  const BossVictoryBlessingSnapshot({
    required this.id,
    required this.restorationBp,
    required this.startTick,
    required this.durationTicks,
  });
  final BossVictoryBlessingId id;
  final int restorationBp;
  final int startTick;
  final int durationTicks;
}
