import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:runner_core/collision/terrain/terrain_authoring_issue.dart';
import 'package:runner_core/track/staged_terrain_data.dart';

import 'generated_artifact_plan.dart';

/// Applies semantic checks and root generated-output drift inspection as one
/// read-only, fail-closed selection gate.
Future<PolygonTerrainArtifactValidationResult>
validateStagedPolygonTerrainOutput({
  required PolygonTerrainValidatedBatch expected,
  required StagedTerrainArtifactData artifact,
  required GeneratedArtifactPlan outputPlan,
  required String sourcePath,
}) async {
  final semantic = validateStagedPolygonTerrainArtifact(
    expected: expected,
    artifact: artifact,
    sourcePath: sourcePath,
  );
  final issues = <PolygonTerrainGenerationIssue>[
    ...semantic.issues,
    for (final drift in await outputPlan.inspectDrift())
      TerrainAuthoringIssue(
        severity: TerrainAuthoringIssueSeverity.error,
        code: drift.code,
        message: drift.message,
        sourcePath: drift.path,
        ownerKey: drift.path,
        placementKey: null,
        shapeId: null,
        elementIndex: null,
      ),
  ];
  return PolygonTerrainArtifactValidationResult(
    artifact: issues.isEmpty ? artifact : null,
    issues: issues,
  );
}
