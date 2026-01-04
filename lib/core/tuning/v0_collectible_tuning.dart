/// V0 collectible spawning and value configuration.
class V0CollectibleTuning {
  const V0CollectibleTuning({
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

  final bool enabled;
  final int minPerChunk;
  final int maxPerChunk;
  final int spawnStartChunkIndex;
  final double collectibleSize;
  final double surfaceClearanceY;
  final double noSpawnMargin;
  final double minSpacingX;
  final double chunkEdgeMarginX;
  final int maxAttemptsPerChunk;
  final double despawnBehindCameraMargin;
  final int valuePerCollectible;
}
