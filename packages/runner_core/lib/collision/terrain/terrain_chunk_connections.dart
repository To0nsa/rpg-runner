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
  final startsAtNormal = _startsAtNormal(entrance, ground);
  final canLand = _hasClearLanding(
    geometry: geometry,
    ground: ground,
    spawnX: physicsCoordinateToTicks(spawnX, name: 'spawnX'),
  );
  return TerrainChunkConnection(
    entrance: entrance.physicalRecord,
    exit: exit.physicalRecord,
    canStart: startsAtNormal && canLand,
  );
}

/// Finds a deterministic alternate landing for an isolated Chunk Play loop.
/// Searches the configured [preferredX] first, then nearby half-pixel X
/// positions, preferring the larger X on ties. Requires the normal-height
/// entrance and the same flat 32-by-64 pixel landing as ordinary scheduling.
/// Returns a world-pixel X or null. Normal level scheduling uses only its
/// configured X and does not call this fallback.
double? findTerrainChunkPlaytestStartX({
  required String chunkKey,
  required int chunkWidth,
  required TerrainGeometry geometry,
  required double groundTopY,
  required double preferredX,
}) {
  final ground = physicsCoordinateToTicks(groundTopY, name: 'groundTopY');
  final entrance = buildTerrainBoundarySignature(
    chunkKey: chunkKey,
    chunkWidth: chunkWidth,
    geometry: geometry,
    side: TerrainBoundarySide.left,
  );
  if (!_startsAtNormal(entrance, ground)) return null;
  final preferred = physicsCoordinateToTicks(preferredX, name: 'preferredX');
  final minX = 16 * terrainPhysicsTicksPerWorldUnit;
  final maxX = (chunkWidth - 16) * terrainPhysicsTicksPerWorldUnit;
  if (maxX < minX) return null;
  if (preferred >= minX &&
      preferred <= maxX &&
      _hasClearLanding(geometry: geometry, ground: ground, spawnX: preferred)) {
    return preferredX;
  }

  // Search authored half-pixel positions nearest the usual start first.
  final minCandidate = 32;
  final maxCandidate = (chunkWidth - 16) * 2;
  var center = (preferredX * 2).round();
  if (center < minCandidate) center = minCandidate;
  if (center > maxCandidate) center = maxCandidate;
  for (
    var distance = 0;
    distance <= maxCandidate - minCandidate;
    distance += 1
  ) {
    final right = center + distance;
    if (right <= maxCandidate &&
        _hasClearLanding(
          geometry: geometry,
          ground: ground,
          spawnX: right * terrainPhysicsTicksPerWorldUnit ~/ 2,
        )) {
      return right / 2;
    }
    final left = center - distance;
    if (distance > 0 &&
        left >= minCandidate &&
        _hasClearLanding(
          geometry: geometry,
          ground: ground,
          spawnX: left * terrainPhysicsTicksPerWorldUnit ~/ 2,
        )) {
      return left / 2;
    }
  }
  return null;
}

bool _startsAtNormal(TerrainBoundarySignature entrance, int ground) =>
    entrance.coverageIntervals.any(
      (interval) =>
          interval.collisionMode == TerrainCollisionMode.solid &&
          interval.minYTicks == ground,
    );

bool _hasClearLanding({
  required TerrainGeometry geometry,
  required int ground,
  required int spawnX,
}) {
  final left = spawnX - 16 * terrainPhysicsTicksPerWorldUnit;
  final right = spawnX + 16 * terrainPhysicsTicksPerWorldUnit;
  final top = ground - 64 * terrainPhysicsTicksPerWorldUnit;
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
  return supported && !obstructed;
}
