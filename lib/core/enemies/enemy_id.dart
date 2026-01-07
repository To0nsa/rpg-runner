/// Unique identifiers for enemy types.
///
/// **Usage**:
/// - Used for spawning via `SpawnSystem`.
/// - keys for `EnemyCatalog` lookup.
/// - Stable identifiers for networking/snapshots (protocol-stable).
enum EnemyId {
  /// A basic flying enemy that ignores gravity and casts spells.
  flyingEnemy,

  /// A basic ground chasing enemy that is affected by gravity.
  groundEnemy,
}

