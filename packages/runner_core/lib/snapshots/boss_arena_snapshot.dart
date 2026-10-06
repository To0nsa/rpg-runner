/// Arena phases are simulation state; presentation cannot advance them.
enum BossArenaPhase { approaching, introduction, combat, defeated, failed }

/// Read-only boss HUD and boundary presentation from the current Core tick.
final class BossArenaSnapshot {
  const BossArenaSnapshot({
    required this.id,
    required this.phase,
    required this.minX,
    required this.maxX,
    required this.hp100,
    required this.hpMax100,
  });
  final String id;
  final BossArenaPhase phase;
  final double minX;
  final double maxX;
  final int hp100;
  final int hpMax100;
  bool get playerHeld => phase == BossArenaPhase.introduction;
}
