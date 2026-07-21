/// Stable controller outcomes recorded for deterministic debugging and goldens.
///
/// New values must be appended because enum indices are stored in ECS state and
/// may participate in reviewed signatures.
enum TerrainControllerDiagnostic {
  none,
  staleSupportCleared,
  initialOverlapRecovered,
  recoveryFailed,
  contactIterationLimit,
  invalidSupport,
  blockedWall,
  blockedCeiling,
  unsupported,
  invalidGeometryVersion,
}
