part of 'game_event.dart';

/// The specific cause for a run ending.
enum RunEndReason {
  /// Player was too slow and scrolled off the screen.
  fellBehindCamera,
  
  /// Player fell into a death pit.
  fellIntoGap,
  
  /// HP reached 0 (combat death).
  playerDied,
  
  /// User manually exited the run.
  gaveUp,
}

/// Identifies the category of damage source that caused death.
enum DeathSourceKind {
  projectile,
  meleeHitbox,
  statusEffect,
  unknown,
}

/// Detailed context about what killed the player.
class DeathInfo {
  const DeathInfo({
    required this.kind,
    this.enemyId,
    this.projectileId,
    this.spellId,
  });

  /// Category of the damage source.
  final DeathSourceKind kind;
  
  /// The [EnemyId] responsible (if applicable).
  final EnemyId? enemyId;
  
  /// The [ProjectileId] responsible (if applicable).
  final ProjectileId? projectileId;
  
  /// The [SpellId] responsible (if applicable).
  final SpellId? spellId;
}

/// Aggregate statistics collected during a run.
class RunEndStats {
  const RunEndStats({
    required this.collectibles,
    required this.collectibleScore,
    required this.enemyKillCounts,
  });

  /// Total count of collectibles picked up.
  final int collectibles;
  
  /// Total score value of collectibles.
  final int collectibleScore;

  /// Kill counts per enemy type.
  ///
  /// **Ordering**: Indices strictly align with [EnemyId.values].
  /// `enemyKillCounts[i]` corresponds to the kills for the enemy at `EnemyId.values[i]`.
  final List<int> enemyKillCounts;
}

/// Event emitted when the game session terminates.
///
/// Contains all necessary data to display the "Game Over" screen.
class RunEndedEvent extends GameEvent {
  const RunEndedEvent({
    required this.tick,
    required this.distance,
    required this.reason,
    required this.stats,
    this.deathInfo,
  });

  /// The tick on which the run ended.
  final int tick;
  
  /// Total distance traveled (meters/pixels).
  final double distance;
  
  /// Why the run ended (Death vs GiveUp).
  final RunEndReason reason;
  
  /// Performance stats.
  final RunEndStats stats;
  
  /// Details on the lethal hit (if applicable).
  final DeathInfo? deathInfo;
}
