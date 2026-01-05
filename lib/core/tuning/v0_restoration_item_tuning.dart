/// V0 restoration item spawning and restore configuration.
class V0RestorationItemTuning {
  const V0RestorationItemTuning({
    this.enabled = true,
    this.spawnEveryChunks = 16,
    this.spawnStartChunkIndex = 2,
    this.restorePercent = 0.30,
    this.itemSize = 12.0,
    this.surfaceClearanceY = 10.0,
    this.noSpawnMargin = 2.0,
    this.chunkEdgeMarginX = 32.0,
    this.maxAttemptsPerSpawn = 40,
    this.despawnBehindCameraMargin = 900.0,
  });

  final bool enabled;
  final int spawnEveryChunks;
  final int spawnStartChunkIndex;
  final double restorePercent;
  final double itemSize;
  final double surfaceClearanceY;
  final double noSpawnMargin;
  final double chunkEdgeMarginX;
  final int maxAttemptsPerSpawn;
  final double despawnBehindCameraMargin;
}
