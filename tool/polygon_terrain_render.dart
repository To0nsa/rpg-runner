import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:runner_core/track/staged_terrain_data.dart';

import 'generated_artifact_plan.dart';

/// Wraps deterministic staged terrain Dart in the root artifact plan.
GeneratedArtifact buildStagedPolygonTerrainArtifact({
  required PolygonTerrainValidatedBatch batch,
  String outputPath = stagedTerrainArtifactRepositoryPath,
}) => GeneratedArtifact(
  path: outputPath,
  content: renderStagedPolygonTerrainDart(batch),
);
