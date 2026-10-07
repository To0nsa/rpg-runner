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
  grojib,

  /// A nimble ground assassin that chases and jumps with the surface navigator.
  hashash,

  /// A perched cultist that transforms on first visibility, then pursues in melee.
  derf,

  /// Arena-exclusive first boss; append to preserve existing ordinal identities.
  bringerOfDeath,

  // Append identities to preserve existing replay and snapshot ordinals.
  voidbornGoddess,
  shoggoth,
  voidcaller,
  shoggothMinion,
  voidTentacle,
}

/// Required arena objectives, also used by authoring selectors.
const bossEnemyIds = <EnemyId>[
  EnemyId.bringerOfDeath,
  EnemyId.voidbornGoddess,
  EnemyId.shoggoth,
  EnemyId.voidcaller,
];

extension EnemyArenaRole on EnemyId {
  /// Catalog identity label shared by encounter and authoring presentation.
  String get displayName => switch (this) {
    EnemyId.unocoDemon => 'Unoco Demon',
    EnemyId.grojib => 'Grojib',
    EnemyId.hashash => 'Hashash',
    EnemyId.derf => 'Derf',
    EnemyId.bringerOfDeath => 'Bringer of Death',
    EnemyId.voidbornGoddess => 'Voidborn Goddess',
    EnemyId.shoggoth => 'Shoggoth',
    EnemyId.voidcaller => 'Voidcaller',
    EnemyId.shoggothMinion => 'Shoggoth Minion',
    EnemyId.voidTentacle => 'Void Tentacle',
  };
  bool get isBoss => bossEnemyIds.contains(this);
  bool get isBossSummon =>
      this == EnemyId.shoggothMinion || this == EnemyId.voidTentacle;
  bool get isArenaOnly => isBoss || isBossSummon;
}

/// Enemy types that use the surface-navigation stack for grounded traversal.
const List<EnemyId> groundNavigatingEnemyIds = <EnemyId>[
  EnemyId.grojib,
  EnemyId.hashash,
  EnemyId.derf,
  EnemyId.bringerOfDeath,
  EnemyId.voidbornGoddess,
  EnemyId.shoggoth,
  EnemyId.voidcaller,
  EnemyId.shoggothMinion,
  EnemyId.voidTentacle,
];
