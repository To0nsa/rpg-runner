/// Unique identifiers for enemy types.
///
/// **Usage**:
/// - Used for spawning via `SpawnSystem`.
/// - keys for `EnemyCatalog` lookup.
/// - Stable identifiers for networking/snapshots (protocol-stable).
enum EnemyId {
  /// A flying demon enemy that ignores gravity and casts spells.
  unocoDemon,

  /// A basic ground chasing enemy that is affected by gravity.
  groundEnemy,
}

