/// Restoration item spawning and restore configuration.
class RestorationItemTuning {
  const RestorationItemTuning({
    this.enabled = true,
    this.spawnEveryChunks = 16,
    this.spawnStartChunkIndex = 2,
    this.restorePercentBp = 3000,
    this.itemSize = 16.0,
    this.surfaceClearanceY = 10.0,
    this.noSpawnMargin = 2.0,
    this.chunkEdgeMarginX = 32.0,
    this.maxAttemptsPerSpawn = 40,
    this.despawnBehindCameraMargin = 900.0,
  });

  /// Master toggle for restoration item spawning.
  final bool enabled;

  /// Spawn one item every N chunks.
  final int spawnEveryChunks;

  /// First chunk index where items can spawn.
  final int spawnStartChunkIndex;

  /// Fraction of max HP/mana/stamina restored in basis points (100 = 1%).
  final int restorePercentBp;

  /// Collision/render size (world units).
  final double itemSize;

  /// Vertical clearance above surface (world units).
  final double surfaceClearanceY;

  /// Margin from surface edges (world units).
  final double noSpawnMargin;

  /// Margin from chunk edges (world units).
  final double chunkEdgeMarginX;

  /// Max placement attempts before giving up.
  final int maxAttemptsPerSpawn;

  /// Distance behind camera before despawn (world units).
  final double despawnBehindCameraMargin;
}
