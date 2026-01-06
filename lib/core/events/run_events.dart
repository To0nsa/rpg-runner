part of 'game_event.dart';

enum RunEndReason {
  fellBehindCamera,
  fellIntoGap,
  playerDied,
  gaveUp,
}

enum DeathSourceKind {
  projectile,
  meleeHitbox,
  unknown,
}

class DeathInfo {
  const DeathInfo({
    required this.kind,
    this.enemyId,
    this.projectileId,
    this.spellId,
  });

  final DeathSourceKind kind;
  final EnemyId? enemyId;
  final ProjectileId? projectileId;
  final SpellId? spellId;
}

class RunEndStats {
  const RunEndStats({
    required this.collectibles,
    required this.collectibleScore,
    required this.enemyKillCounts,
  });

  final int collectibles;
  final int collectibleScore;

  /// Enemy kill counts aligned to [EnemyId.values].
  final List<int> enemyKillCounts;
}

class RunEndedEvent extends GameEvent {
  const RunEndedEvent({
    required this.tick,
    required this.distance,
    required this.reason,
    required this.stats,
    this.deathInfo,
  });

  final int tick;
  final double distance;
  final RunEndReason reason;
  final RunEndStats stats;
  final DeathInfo? deathInfo;
}
