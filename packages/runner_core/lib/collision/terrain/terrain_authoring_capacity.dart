import 'terrain_compiler.dart';

/// Non-blocking terrain authoring targets frozen by the slopes performance
/// specification.
///
/// Exceeding a target should warn an author, but must not reject, truncate, or
/// otherwise change geometry accepted by [TerrainCompiler]. Runtime safety is
/// enforced separately by [TerrainGeometryLimits].
abstract final class TerrainAuthoringCapacityTargets {
  /// Normal authoring target for collision shapes owned by one prefab.
  static const int shapesPerPrefab = 16;

  /// Normal authoring target for vertices retained by one collision shape.
  static const int verticesPerShape = 24;

  /// Normal authoring target for exposed runtime segments in one chunk.
  static const int exposedEdgesPerChunk = 1024;
}
