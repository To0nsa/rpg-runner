import '../collision/terrain/terrain_numeric.dart';
import '../track/staged_terrain_data.dart';
import 'world_interaction_catalog.dart';

/// Admitted support interval shared by runtime, editor previews and compilation.
final class WorldInteractionSurface {
  const WorldInteractionSurface({
    required this.placementKey,
    required this.leftTicks,
    required this.rightTicks,
    required this.topTicks,
    required this.scale,
  });
  final String? placementKey;
  final int leftTicks, rightTicks, topTicks;
  final double scale;
}

/// Resolves real collision lineage, never artwork bounds or proximity triggers.
/// An explicit center/width must fit the selected flat top without clamping.
WorldInteractionSurface resolveWorldInteractionSurface(
  WorldInteractionBinding binding,
  StagedTerrainChunkData terrain,
) {
  if (binding.chunkKey != terrain.chunkKey) {
    throw StateError('Interaction ${binding.key} belongs to another chunk.');
  }
  final lineage = terrain.placementLineage
      .where(
        (p) =>
            p.prefabKey == binding.prefabKey &&
            p.sourceId.shapeId == binding.shapeId &&
            (binding.placementKey == null ||
                p.sourceId.placementKey == binding.placementKey),
      )
      .toList();
  final polygons = binding.prefabKey == null
      ? terrain.polygons
            .where(
              (p) =>
                  p.id.placementKey == null && p.id.shapeId == binding.shapeId,
            )
            .toList()
      : terrain.polygons
            .where((p) => lineage.any((l) => l.sourceId == p.id))
            .toList();
  if (polygons.length != 1 ||
      (binding.prefabKey != null && lineage.length != 1) ||
      (binding.prefabKey == null && binding.placementKey != null)) {
    throw StateError(
      'Interaction ${binding.key} requires one unambiguous support shape.',
    );
  }
  final polygon = polygons.single;
  if (polygon.collisionMode == StagedTerrainCollisionMode.none) {
    throw StateError('Interaction ${binding.key} needs a collidable top.');
  }
  final top = polygon.vertices
      .map((p) => p.yTicks)
      .reduce((a, b) => a < b ? a : b);
  final edges = <(int, int)>[];
  for (var i = 0; i < polygon.vertices.length; i++) {
    final a = polygon.vertices[i],
        b = polygon.vertices[(i + 1) % polygon.vertices.length];
    if (a.yTicks == top && b.yTicks == top && a.xTicks != b.xTicks) {
      edges.add(
        a.xTicks < b.xTicks ? (a.xTicks, b.xTicks) : (b.xTicks, a.xTicks),
      );
    }
  }
  if (edges.length != 1) {
    throw StateError('Interaction ${binding.key} needs one flat highest edge.');
  }
  var (left, right) = edges.single;
  if ((binding.surfaceX == null) != (binding.activationWidth == null)) {
    throw StateError(
      'Interaction center and activation width must be specified together.',
    );
  }
  if (binding.surfaceX != null) {
    final x = binding.surfaceX!, width = binding.activationWidth!;
    if (!x.isFinite || !width.isFinite || width <= 0) {
      throw StateError(
        'Interaction surface coordinates must be finite and positive.',
      );
    }
    final center = physicsCoordinateToTicks(x);
    final half = physicsCoordinateToTicks(width / 2);
    if (half <= 0 || center - half < left || center + half > right) {
      throw StateError(
        'Interaction ${binding.key} activation interval must fit its support top.',
      );
    }
    left = center - half;
    right = center + half;
  }
  final scale =
      binding.scaleOverride ??
      (binding.prefabKey == null ? 1.0 : lineage.single.scaleTenths / 10);
  if (!scale.isFinite ||
      scale <= 0 ||
      (binding.scaleOverride != null && scale > 10)) {
    throw StateError('Interaction scale must be in (0, 10].');
  }
  return WorldInteractionSurface(
    placementKey: polygon.id.placementKey,
    leftTicks: left,
    rightTicks: right,
    topTicks: top,
    scale: scale,
  );
}
