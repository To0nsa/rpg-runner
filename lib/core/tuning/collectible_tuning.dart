/// Collectible spawning and value configuration.
class CollectibleTuning {
  const CollectibleTuning({
    this.enabled = true,
    this.minPerChunk = 1,
    this.maxPerChunk = 2,
    this.spawnStartChunkIndex = 2,
    this.collectibleSize = 10.0,
    this.surfaceClearanceY = 10.0,
    this.noSpawnMargin = 2.0,
    this.minSpacingX = 80.0,
    this.chunkEdgeMarginX = 32.0,
    this.maxAttemptsPerChunk = 40,
    this.despawnBehindCameraMargin = 900.0,
    this.valuePerCollectible = 50,
  }) : assert(maxPerChunk >= minPerChunk);

  /// Master toggle for collectible spawning.
  final bool enabled;

  /// Min collectibles spawned per chunk.
  final int minPerChunk;

  /// Max collectibles spawned per chunk.
  final int maxPerChunk;

  /// First chunk index where collectibles can spawn.
  final int spawnStartChunkIndex;

  /// Collision/render size (world units).
  final double collectibleSize;

  /// Vertical clearance above surface (world units).
  final double surfaceClearanceY;

  /// Margin from surface edges to avoid clipping (world units).
  final double noSpawnMargin;

  /// Minimum horizontal spacing between collectibles (world units).
  final double minSpacingX;

  /// Margin from chunk edges (world units).
  final double chunkEdgeMarginX;

  /// Max placement attempts before giving up.
  final int maxAttemptsPerChunk;

  /// Distance behind camera before despawn (world units).
  final double despawnBehindCameraMargin;

  /// Score value per collectible.
  final int valuePerCollectible;
}
