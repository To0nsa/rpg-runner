import 'package:runner_core/collision/terrain/terrain_authoring_issue.dart';
import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/encounters/encounter_definition.dart';
import 'package:runner_core/encounters/encounter_placement.dart';
import 'package:runner_core/navigation/terrain_spawn_placement.dart';
import 'package:runner_core/tuning/flying_enemy_tuning.dart';

/// Runtime-only admission. Incomplete but structurally valid source stays saveable.
List<TerrainAuthoringIssue> validateEncounterReadiness({
  required Iterable<EncounterDefinition> encounters,
  required TerrainGeometry geometry,
  required double chunkWidth,
  required double? groundTopY,
  required String sourcePath,
  required String chunkKey,
}) {
  if (encounters.isEmpty) return const [];
  TerrainAuthoringIssue issue(
    String code,
    String message,
    String encounterId, [
    String? memberId,
  ]) => TerrainAuthoringIssue(
    severity: TerrainAuthoringIssueSeverity.error,
    code: code,
    message:
        'Encounter $encounterId${memberId == null ? '' : ' / $memberId'}: $message',
    sourcePath: sourcePath,
    ownerKey: chunkKey,
    placementKey: null,
    shapeId: null,
    elementIndex: null,
    elementId: encounterId,
    fieldKey: memberId == null ? 'participants' : 'members.$memberId.placement',
  );
  if (groundTopY == null || !groundTopY.isFinite) {
    return [
      for (final encounter in encounters)
        issue(
          'encounter_level_ground_context_missing',
          'A finite owning level ground height is required.',
          encounter.id,
        ),
    ];
  }
  final resolver = TerrainSpawnPlacementResolver.forGeometry(geometry);
  final issues = <TerrainAuthoringIssue>[];
  for (final encounter in encounters) {
    final result = resolveEncounterPlacement(
      definition: encounter,
      startX: 0,
      chunkWidth: chunkWidth,
      groundTopY: groundTopY,
      flyingHoverOffsetY: const UnocoDemonTuning().unocoDemonHoverOffsetY,
      resolve: resolver.resolve,
    );
    if (!result.accepted) {
      issues.add(
        issue(
          encounter.npcs.isEmpty || encounter.enemies.isEmpty
              ? 'encounter_incomplete'
              : 'encounter_placement_rejected',
          result.diagnostic!,
          encounter.id,
          result.memberId,
        ),
      );
    }
  }
  return List.unmodifiable(issues);
}
