import 'package:runner_core/bosses/boss_arena_definition.dart';
import 'package:runner_core/bosses/boss_arena_placement.dart';
import 'package:runner_core/collision/terrain/terrain_authoring_issue.dart';
import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/navigation/terrain_spawn_placement.dart';

/// Build and Play reject a boss whose complete capsule cannot occupy its arena.
List<TerrainAuthoringIssue> validateBossArenaReadiness({
  required BossArenaDefinition? arena,
  required TerrainGeometry geometry,
  required double? groundTopY,
  required String sourcePath,
  required String chunkKey,
}) {
  if (arena == null) return const [];
  final valid =
      groundTopY != null &&
      groundTopY.isFinite &&
      resolveBossArenaPlacement(
            arena: arena,
            startX: 0,
            groundTopY: groundTopY,
            resolve: TerrainSpawnPlacementResolver.forGeometry(geometry)
                .resolve,
          ) !=
          null;
  if (valid) return const [];
  return [
    TerrainAuthoringIssue(
      severity: TerrainAuthoringIssueSeverity.error,
      code: 'boss_arena_placement_rejected',
      message:
          'Boss ${arena.id} needs complete ground support and clearance inside its combat bounds.',
      sourcePath: sourcePath,
      ownerKey: chunkKey,
      placementKey: null,
      shapeId: null,
      elementIndex: null,
      elementId: arena.id,
      fieldKey: 'bossArena.spawnX',
    ),
  ];
}
