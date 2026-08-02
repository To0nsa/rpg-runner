import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/enemies/enemy_id.dart';

import 'chunk_domain_models.dart';
import 'chunk_v2_file_data.dart';

/// Whether a level ground plane can cross the deterministic Core boundary.
bool isChunkV2MarkerGroundContextValid(double? value) {
  if (value == null || !value.isFinite) return false;
  try {
    physicsCoordinateToTicks(value, name: 'levelGroundTopY');
    return true;
  } on RangeError {
    return false;
  } on ArgumentError {
    return false;
  }
}

/// Stable semantic contract violations for one staged enemy marker.
List<String> chunkV2MarkerContractCodes({
  required ChunkV2FileData chunk,
  required PlacedMarkerDef marker,
  required bool hasGroundContext,
  bool includeGroundContext = true,
}) {
  final codes = <String>[];
  if (marker.markerId.isEmpty) {
    codes.add('missing_marker_id');
  } else if (!EnemyId.values.any(
    (enemyId) => enemyId.name == marker.markerId,
  )) {
    codes.add('unknown_enemy_marker_id');
  }
  if (marker.placement != markerPlacementGround &&
      marker.placement != markerPlacementHighestSurfaceAtX &&
      marker.placement != markerPlacementObstacleTop) {
    codes.add('marker_invalid_placement');
  }
  if (marker.x < 0 || marker.x > chunk.width) {
    codes.add('marker_x_out_of_bounds');
  }
  if (marker.y < 0 || marker.y > chunk.height) {
    codes.add('marker_y_out_of_bounds');
  }
  if (marker.chancePercent < 0 || marker.chancePercent > 100) {
    codes.add('marker_chance_out_of_range');
  }
  if (marker.salt < 0) codes.add('marker_salt_negative');
  if (includeGroundContext && !hasGroundContext) {
    codes.add('marker_level_ground_context_missing');
  }
  return List<String>.unmodifiable(codes);
}

/// Concise source-facing explanation for a marker contract violation.
String chunkV2MarkerContractMessage({
  required ChunkV2FileData chunk,
  required PlacedMarkerDef marker,
  required String code,
}) => switch (code) {
  'missing_marker_id' => 'Chunk ${chunk.id} has a marker with no enemy ID.',
  'unknown_enemy_marker_id' =>
    'Chunk ${chunk.id} marker references unknown enemy '
        '"${marker.markerId}".',
  'marker_invalid_placement' =>
    'Chunk ${chunk.id} marker ${marker.markerId} uses unsupported placement '
        '"${marker.placement}".',
  'marker_x_out_of_bounds' =>
    'Chunk ${chunk.id} marker ${marker.markerId} x ${marker.x} is outside '
        'closed chunk bounds 0..${chunk.width}.',
  'marker_y_out_of_bounds' =>
    'Chunk ${chunk.id} marker ${marker.markerId} editor anchor y ${marker.y} '
        'is outside closed chunk bounds 0..${chunk.height}.',
  'marker_chance_out_of_range' =>
    'Chunk ${chunk.id} marker ${marker.markerId} chancePercent must be '
        'between 0 and 100.',
  'marker_salt_negative' =>
    'Chunk ${chunk.id} marker ${marker.markerId} salt must be non-negative.',
  'marker_level_ground_context_missing' =>
    'Chunk ${chunk.id} has authored markers but level ${chunk.levelId} has '
        'no finite deterministic groundTopY context.',
  _ => 'Chunk ${chunk.id} marker ${marker.markerId} violates $code.',
};
