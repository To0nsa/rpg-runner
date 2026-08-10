import 'package:runner_core/collision/terrain/terrain_authoring_issue.dart';
import 'package:runner_core/collision/terrain/terrain_authoring_polygon_signature.dart';
import 'package:runner_core/collision/terrain/terrain_authoring_seam_signature.dart';
import 'package:runner_core/collision/terrain/terrain_authoring_triangle_signature.dart';
import 'package:runner_core/track/staged_terrain_data.dart';

import 'polygon_terrain_compilation.dart';
import 'polygon_terrain_render.dart';
import 'polygon_terrain_seam_validation.dart';
import 'polygon_terrain_source.dart';

/// Result of comparing one typed staged artifact with a fresh accepted compile.
///
/// Any mismatch is blocking and suppresses [artifact], so future consumers
/// cannot select a partially verified generated terrain snapshot.
final class PolygonTerrainArtifactValidationResult {
  PolygonTerrainArtifactValidationResult._({
    required this.artifact,
    required Iterable<PolygonTerrainGenerationIssue> issues,
  }) : issues = canonicalTerrainAuthoringIssues(issues);

  /// Original typed artifact when every comparison succeeds; otherwise null.
  final StagedTerrainArtifactData? artifact;

  /// Canonically ordered blocking mismatches with artifact/chunk ownership.
  final List<PolygonTerrainGenerationIssue> issues;
}

/// Verifies staged metadata and signatures against fresh Core compilation and
/// scheduler-seam validation.
///
/// [sourcePath] identifies the generated Dart artifact, not the authored Chunk
/// source. Exact generated payload bytes remain owned by
/// `GeneratedArtifactPlan`; this comparison is deterministic and performs no
/// filesystem writes.
PolygonTerrainArtifactValidationResult validateStagedPolygonTerrainArtifact({
  required PolygonTerrainValidatedBatch expected,
  required StagedTerrainArtifactData artifact,
  required String sourcePath,
}) {
  sourcePath = canonicalPolygonTerrainSourcePath(sourcePath);
  final issues = <PolygonTerrainGenerationIssue>[];
  final expectedChunks = expected.chunks;
  final expectedVersions = expectedChunks
      .map((compiled) => compiled.geometry.version)
      .toSet();
  if (expectedChunks.isEmpty || expectedVersions.length != 1) {
    throw ArgumentError.value(
      expectedChunks,
      'expected',
      'Must contain chunks compiled with one geometry version.',
    );
  }

  void globalMismatch({
    required String code,
    required String label,
    required Object expectedValue,
    required Object actualValue,
  }) {
    if (expectedValue == actualValue) return;
    issues.add(
      _artifactIssue(
        code: code,
        message:
            '$label mismatch: expected $expectedValue, found $actualValue.',
        sourcePath: sourcePath,
        ownerKey: sourcePath,
      ),
    );
  }

  globalMismatch(
    code: 'staged_artifact_format_mismatch',
    label: 'Staged artifact format',
    expectedValue: stagedTerrainArtifactFormatVersion,
    actualValue: artifact.formatVersion,
  );
  globalMismatch(
    code: 'staged_compiler_geometry_version_mismatch',
    label: 'Compiler geometry version',
    expectedValue: expectedVersions.single,
    actualValue: artifact.compilerGeometryVersion,
  );
  globalMismatch(
    code: 'authoring_polygon_signature_format_mismatch',
    label: 'Authoring polygon signature format',
    expectedValue: terrainAuthoringPolygonSignatureFormat,
    actualValue: artifact.authoringPolygonSignatureFormat,
  );
  globalMismatch(
    code: 'authoring_seam_signature_format_mismatch',
    label: 'Authoring seam signature format',
    expectedValue: terrainAuthoringSeamSignatureFormat,
    actualValue: artifact.authoringSeamSignatureFormat,
  );
  globalMismatch(
    code: 'authoring_seam_signature_mismatch',
    label: 'Authoring seam signature',
    expectedValue: expected.seamSignature.digest,
    actualValue: artifact.authoringSeamSignature,
  );
  globalMismatch(
    code: 'source_signature_format_mismatch',
    label: 'Source signature format',
    expectedValue: polygonTerrainSourceSignatureFormat,
    actualValue: artifact.sourceSignatureFormat,
  );
  globalMismatch(
    code: 'edge_signature_format_mismatch',
    label: 'Edge signature format',
    expectedValue: polygonTerrainEdgeSignatureFormat,
    actualValue: artifact.edgeSignatureFormat,
  );
  globalMismatch(
    code: 'placement_signature_format_mismatch',
    label: 'Placement signature format',
    expectedValue: polygonTerrainPlacementSignatureFormat,
    actualValue: artifact.placementSignatureFormat,
  );
  globalMismatch(
    code: 'triangle_signature_format_mismatch',
    label: 'Triangle signature format',
    expectedValue: terrainAuthoringTriangleSignatureFormat,
    actualValue: artifact.triangleSignatureFormat,
  );

  final expectedByKey = <String, PolygonTerrainCompiledChunk>{
    for (final compiled in expectedChunks) compiled.chunk.chunkKey: compiled,
  };
  final actualByKey = <String, StagedTerrainChunkData>{};
  final actualKeys = <String>[];
  for (final chunk in artifact.chunks) {
    actualKeys.add(chunk.chunkKey);
    if (actualByKey.containsKey(chunk.chunkKey)) {
      issues.add(
        _artifactIssue(
          code: 'staged_artifact_chunk_duplicate',
          message:
              'Generated artifact contains duplicate chunk ${chunk.chunkKey}.',
          sourcePath: sourcePath,
          ownerKey: chunk.chunkKey,
        ),
      );
      continue;
    }
    actualByKey[chunk.chunkKey] = chunk;
  }

  final canonicalActualKeys = actualByKey.keys.toList()..sort();
  if (actualKeys.length == actualByKey.length &&
      !_listEquals(actualKeys, canonicalActualKeys)) {
    issues.add(
      _artifactIssue(
        code: 'staged_artifact_chunk_order_mismatch',
        message: 'Generated artifact chunks are not in canonical key order.',
        sourcePath: sourcePath,
        ownerKey: sourcePath,
      ),
    );
  }

  for (final actualKey in actualByKey.keys) {
    if (expectedByKey.containsKey(actualKey)) continue;
    issues.add(
      _artifactIssue(
        code: 'staged_artifact_chunk_unexpected',
        message: 'Generated artifact contains unexpected chunk $actualKey.',
        sourcePath: sourcePath,
        ownerKey: actualKey,
      ),
    );
  }
  for (final compiled in expectedChunks) {
    final chunkKey = compiled.chunk.chunkKey;
    final actual = actualByKey[chunkKey];
    if (actual == null) {
      issues.add(
        _artifactIssue(
          code: 'staged_artifact_chunk_missing',
          message: 'Generated artifact is missing compiled chunk $chunkKey.',
          sourcePath: sourcePath,
          ownerKey: chunkKey,
        ),
      );
      continue;
    }
    _validateChunk(
      expected: compiled,
      actual: actual,
      sourcePath: sourcePath,
      issues: issues,
    );
  }

  return PolygonTerrainArtifactValidationResult._(
    artifact: issues.isEmpty ? artifact : null,
    issues: issues,
  );
}

void _validateChunk({
  required PolygonTerrainCompiledChunk expected,
  required StagedTerrainChunkData actual,
  required String sourcePath,
  required List<PolygonTerrainGenerationIssue> issues,
}) {
  final chunk = expected.chunk;
  final ownerKey = chunk.chunkKey;
  final metadataMatches =
      actual.chunkKey == chunk.chunkKey &&
      actual.id == chunk.id &&
      actual.revision == chunk.revision &&
      actual.status == chunk.status &&
      actual.levelId == chunk.levelId &&
      actual.tileSize == chunk.tileSize &&
      actual.width == chunk.width &&
      actual.height == chunk.height &&
      actual.difficulty == chunk.difficulty &&
      actual.assemblyGroupId == chunk.assemblyGroupId;
  if (!metadataMatches) {
    issues.add(
      _artifactIssue(
        code: 'staged_chunk_metadata_mismatch',
        message:
            'Generated metadata does not match fresh source for $ownerKey.',
        sourcePath: sourcePath,
        ownerKey: ownerKey,
      ),
    );
  }

  final signatureChecks = <(String, String, String, String)>[
    (
      'authoring_polygon_signature_mismatch',
      'Authoring polygon signature',
      expected.authoringPolygonSignature(),
      actual.authoringPolygonSignature,
    ),
    (
      'source_signature_mismatch',
      'Core source signature',
      expected.geometry.sourceSignature(),
      actual.sourceSignature,
    ),
    (
      'edge_signature_mismatch',
      'Core edge signature',
      expected.geometry.edgeSignature(),
      actual.edgeSignature,
    ),
    (
      'placement_signature_mismatch',
      'Placement signature',
      expected.placementSignature(),
      actual.placementSignature,
    ),
    (
      'triangle_signature_mismatch',
      'Triangle signature',
      expected.triangleSignature(),
      actual.triangleSignature,
    ),
  ];
  for (final check in signatureChecks) {
    if (check.$3 == check.$4) continue;
    issues.add(
      _artifactIssue(
        code: check.$1,
        message:
            '${check.$2} mismatch: expected ${check.$3}, found ${check.$4}.',
        sourcePath: sourcePath,
        ownerKey: ownerKey,
      ),
    );
  }
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

PolygonTerrainGenerationIssue _artifactIssue({
  required String code,
  required String message,
  required String sourcePath,
  required String ownerKey,
}) => TerrainAuthoringIssue(
  severity: TerrainAuthoringIssueSeverity.error,
  code: code,
  message: message,
  sourcePath: sourcePath,
  ownerKey: ownerKey,
  placementKey: null,
  shapeId: null,
  elementIndex: null,
);
