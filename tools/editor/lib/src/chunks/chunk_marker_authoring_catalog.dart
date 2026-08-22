import 'package:runner_core/contracts/render_anim_set_definition.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/enemies/enemy_terrain_profile.dart';
import 'package:runner_core/snapshots/enums.dart';

import 'chunk_domain_models.dart';

/// Presentation projection of one Core enemy available to marker authoring.
///
/// Identity, movement role, and preview strip geometry come directly from the
/// Core catalogs. Display labels are editor-only and never enter Chunk source.
final class ChunkMarkerEnemyCatalogEntry {
  const ChunkMarkerEnemyCatalogEntry({
    required this.enemyId,
    required this.displayName,
    required this.motionKind,
    required this.renderAnim,
  });

  final EnemyId enemyId;
  final String displayName;
  final EnemyTerrainMotionKind motionKind;
  final RenderAnimSetDefinition renderAnim;

  String get markerId => enemyId.name;

  String get roleLabel => chunkMarkerEnemyRoleLabel(motionKind);

  String? get previewSourcePath => renderAnim.sourcesByKey[AnimKey.idle];

  int get previewRow => renderAnim.rowByKey[AnimKey.idle] ?? 0;

  int get previewStartFrame => renderAnim.frameStartByKey[AnimKey.idle] ?? 0;

  int? get previewGridColumns => renderAnim.gridColumnsByKey[AnimKey.idle];
}

/// Canonically ordered Core enemies supported by current marker authoring.
final List<ChunkMarkerEnemyCatalogEntry> chunkMarkerEnemyCatalog =
    List<ChunkMarkerEnemyCatalogEntry>.unmodifiable(() {
      const catalog = EnemyCatalog();
      final entries = <ChunkMarkerEnemyCatalogEntry>[
        for (final enemyId in EnemyId.values)
          ChunkMarkerEnemyCatalogEntry(
            enemyId: enemyId,
            displayName: _enemyDisplayName(enemyId),
            motionKind: catalog.terrainContactProfile(enemyId).motionKind,
            renderAnim: catalog.get(enemyId).renderAnim,
          ),
      ];
      entries.sort((left, right) => left.markerId.compareTo(right.markerId));
      return entries;
    }());

/// Canonical enemy IDs retained for serialization and validation consumers.
final List<String> chunkMarkerEnemyIds = List<String>.unmodifiable(
  chunkMarkerEnemyCatalog.map((entry) => entry.markerId),
);

/// Resolves one authoring entry without accepting aliases or case drift.
ChunkMarkerEnemyCatalogEntry? chunkMarkerEnemyCatalogEntryFor(String markerId) {
  for (final entry in chunkMarkerEnemyCatalog) {
    if (entry.markerId == markerId) return entry;
  }
  return null;
}

/// Short editor label for one authoritative Core terrain-motion role.
String chunkMarkerEnemyRoleLabel(EnemyTerrainMotionKind motionKind) =>
    switch (motionKind) {
      EnemyTerrainMotionKind.groundedDynamic => 'Ground',
      EnemyTerrainMotionKind.flyingDynamic => 'Flying',
      EnemyTerrainMotionKind.kinematicPlacement => 'Perched',
    };

/// Placement queries supported by current Chunk marker authoring.
const List<String> chunkMarkerPlacementModes = <String>[
  markerPlacementGround,
  markerPlacementHighestSurfaceAtX,
  markerPlacementObstacleTop,
];

String _enemyDisplayName(EnemyId enemyId) => switch (enemyId) {
  EnemyId.unocoDemon => 'Unoco Demon',
  EnemyId.grojib => 'Grojib',
  EnemyId.hashash => 'Hashash',
  EnemyId.derf => 'Derf',
};
