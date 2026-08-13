import 'package:runner_core/enemies/enemy_id.dart';

import 'chunk_domain_models.dart';

/// Canonical enemy IDs supported by current Chunk marker authoring.
final List<String> chunkMarkerEnemyIds = List<String>.unmodifiable(
  EnemyId.values.map((id) => id.name).toList(growable: false)..sort(),
);

/// Placement queries supported by current Chunk marker authoring.
const List<String> chunkMarkerPlacementModes = <String>[
  markerPlacementGround,
  markerPlacementHighestSurfaceAtX,
  markerPlacementObstacleTop,
];
