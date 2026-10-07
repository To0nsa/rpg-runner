import '../enemies/enemy_id.dart';

/// Arena phases are simulation state; presentation cannot advance them.
enum BossArenaPhase { approaching, introduction, combat, defeated, failed }

/// Existing catalog-driven entrance timing, exposed for read-only feedback.
final class BossEntranceSnapshot {
  const BossEntranceSnapshot({
    required this.startTick,
    required this.durationTicks,
  });
  final int startTick;
  final int durationTicks;
}

/// Read-only boss HUD and boundary presentation from the current Core tick.
final class BossArenaSnapshot {
  const BossArenaSnapshot({
    required this.id,
    required this.enemyId,
    required this.phase,
    required this.minX,
    required this.maxX,
    required this.hp100,
    required this.hpMax100,
    this.entrance,
  });
  final String id;
  final EnemyId enemyId;
  final BossArenaPhase phase;
  final double minX;
  final double maxX;
  final int hp100;
  final int hpMax100;
  final BossEntranceSnapshot? entrance;
  bool get playerHeld => phase == BossArenaPhase.introduction;
}
