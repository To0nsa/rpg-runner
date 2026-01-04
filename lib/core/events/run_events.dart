part of 'game_event.dart';

enum RunEndReason {
  fellBehindCamera,
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

class RunEndedEvent extends GameEvent {
  const RunEndedEvent({
    required this.tick,
    required this.distance,
    required this.reason,
    this.deathInfo,
  });

  final int tick;
  final double distance;
  final RunEndReason reason;
  final DeathInfo? deathInfo;
}
