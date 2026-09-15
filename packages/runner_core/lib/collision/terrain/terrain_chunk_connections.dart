import 'terrain_boundary_signature.dart';
import 'terrain_connection_schedule.dart';
import 'terrain_geometry.dart';
import 'terrain_numeric.dart';
import 'terrain_polygon.dart';

/// Derives exact joins and a conservative normal-ground opening from compiled
/// geometry. The 32 by 64 pixel spawn envelope covers both current characters;
/// a flat landing must support the whole width with clear space above it.
TerrainChunkConnection buildTerrainChunkConnection({
  required String chunkKey,
  required int chunkWidth,
  required TerrainGeometry geometry,
  required double groundTopY,
  double spawnX = 300,
}) {
  final entrance = buildTerrainBoundarySignature(
    chunkKey: chunkKey,
    chunkWidth: chunkWidth,
    geometry: geometry,
    side: TerrainBoundarySide.left,
  );
  final exit = buildTerrainBoundarySignature(
    chunkKey: chunkKey,
    chunkWidth: chunkWidth,
    geometry: geometry,
    side: TerrainBoundarySide.right,
  );
  final ground = physicsCoordinateToTicks(groundTopY, name: 'groundTopY');
  final left = physicsCoordinateToTicks(spawnX - 16, name: 'spawnLeft');
  final right = physicsCoordinateToTicks(spawnX + 16, name: 'spawnRight');
  final top = physicsCoordinateToTicks(groundTopY - 64, name: 'spawnTop');
  final startsAtNormal = entrance.coverageIntervals.any(
    (interval) =>
        interval.collisionMode == TerrainCollisionMode.solid &&
        interval.minYTicks == ground,
  );
  final supported = geometry.edges.any(
    (edge) =>
        edge.collisionMode == TerrainCollisionMode.solid &&
        edge.outwardNormal.yTicks < 0 &&
        edge.start.yTicks == ground &&
        edge.end.yTicks == ground &&
        edge.bounds.minX <= left &&
        edge.bounds.maxX >= right,
  );
  final obstructed = geometry.edges.any(
    (edge) =>
        edge.bounds.minX < right &&
        edge.bounds.maxX > left &&
        edge.bounds.minY < ground &&
        edge.bounds.maxY > top,
  );
  return TerrainChunkConnection(
    entrance: entrance.physicalRecord,
    exit: exit.physicalRecord,
    canStart: startsAtNormal && supported && !obstructed,
  );
}
