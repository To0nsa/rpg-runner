/// V0 track streaming / deterministic chunk spawning configuration.
///
/// This is simulation config (Core), not combat/ability tuning.
class V0TrackTuning {
  const V0TrackTuning({
    this.enabled = true,
    this.chunkWidth = 600.0,
    this.spawnAheadMargin = 600.0,
    this.cullBehindMargin = 600.0,
    this.gridSnap = 16.0,
  }) : assert(chunkWidth > 0),
       assert(spawnAheadMargin >= 0),
       assert(cullBehindMargin >= 0),
       assert(gridSnap > 0);

  /// If false, no chunk streaming is performed (static world only).
  final bool enabled;

  /// Width of a chunk in world units.
  final double chunkWidth;

  /// Spawn chunks while `cameraRight + spawnAheadMargin >= nextChunkStartX`.
  final double spawnAheadMargin;

  /// Cull chunks while `chunkEndX < cameraLeft - cullBehindMargin`.
  final double cullBehindMargin;

  /// Authoring grid snap for chunk patterns (world units).
  final double gridSnap;
}
