/// Track streaming / deterministic chunk spawning configuration.
///
/// This is simulation config (Core), not combat/ability tuning.
class TrackTuning {
  const TrackTuning({
    this.enabled = true,
    this.chunkWidth = 600.0,
    this.spawnAheadMargin = 600.0,
    this.cullBehindMargin = 600.0,
    this.gridSnap = 16.0,
    this.playerStartX = 400.0,
    this.gapKillOffsetY = 400.0,
  }) : assert(chunkWidth > 0),
       assert(spawnAheadMargin >= 0),
       assert(cullBehindMargin >= 0),
       assert(gridSnap > 0),
       assert(playerStartX >= 0),
       assert(gapKillOffsetY >= 0);

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

  /// Player spawn X position at run start (world units).
  final double playerStartX;

  /// How far below ground the player must fall before death triggers.
  ///
  /// Set high enough to give visual feedback of falling into the gap
  /// before the death screen appears.
  final double gapKillOffsetY;
}
