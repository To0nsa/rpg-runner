import 'dart:convert';

import '../chunks/chunk_domain_models.dart';
import '../chunks/migration/legacy_chunk_ground_migration.dart';
import '../prefabs/migration/legacy_prefab_collider_union.dart';
import '../prefabs/migration/reviewed_legacy_prefab_collision_reauthorings.dart';
import '../prefabs/models/models.dart';
import '../terrain_authoring/terrain_source_models.dart';

/// Classification of one legacy prefab collision conversion.
enum PrefabPolygonMigrationKind {
  decoration,
  isolated,
  union,
  disconnected,
  reviewedReauthoring,
}

/// One deterministic blocker in a complete polygon-authoring migration plan.
final class PolygonAuthoringMigrationIssue
    implements Comparable<PolygonAuthoringMigrationIssue> {
  const PolygonAuthoringMigrationIssue({
    required this.sourcePath,
    required this.ownerKey,
    required this.elementIndex,
    required this.code,
    required this.message,
  });

  final String sourcePath;
  final String ownerKey;
  final int elementIndex;
  final String code;
  final String message;

  Map<String, Object> toJson() => <String, Object>{
    'sourcePath': sourcePath,
    'ownerKey': ownerKey,
    'elementIndex': elementIndex,
    'code': code,
    'message': message,
  };

  @override
  int compareTo(PolygonAuthoringMigrationIssue other) {
    var order = sourcePath.compareTo(other.sourcePath);
    if (order != 0) return order;
    order = ownerKey.compareTo(other.ownerKey);
    if (order != 0) return order;
    order = elementIndex.compareTo(other.elementIndex);
    if (order != 0) return order;
    return code.compareTo(other.code);
  }
}

/// Exact legacy source signature captured by one migration check plan.
final class PolygonAuthoringMigrationSourceFile
    implements Comparable<PolygonAuthoringMigrationSourceFile> {
  const PolygonAuthoringMigrationSourceFile({
    required this.sourceKind,
    required this.ownerKey,
    required this.sourcePath,
    required this.sha256,
  });

  /// Either `prefabs` or `chunk`; serialized for human-readable review.
  final String sourceKind;
  final String ownerKey;
  final String sourcePath;

  /// SHA-256 of the exact UTF-8 legacy source text used to build the plan.
  final String sha256;

  Map<String, Object> toJson() => <String, Object>{
    'sourceKind': sourceKind,
    'ownerKey': ownerKey,
    'sourcePath': sourcePath,
    'sha256': sha256,
  };

  @override
  int compareTo(PolygonAuthoringMigrationSourceFile other) {
    var order = sourcePath.compareTo(other.sourcePath);
    if (order != 0) return order;
    order = sourceKind.compareTo(other.sourceKind);
    if (order != 0) return order;
    return ownerKey.compareTo(other.ownerKey);
  }
}

/// Planned canonical polygon source for one legacy prefab record.
final class PrefabPolygonMigrationEntry {
  PrefabPolygonMigrationEntry({
    required this.prefabKey,
    required this.sourcePath,
    required this.kind,
    required this.legacyColliderCount,
    required Iterable<TerrainSourceShapeDef> collisionShapes,
    required this.legacyAreaHalfPixelSquared,
    required this.plannedAreaHalfPixelSquared,
  }) : collisionShapes = canonicalTerrainSourceShapes(collisionShapes);

  final String prefabKey;
  final String sourcePath;
  final PrefabPolygonMigrationKind kind;
  final int legacyColliderCount;
  final List<TerrainSourceShapeDef> collisionShapes;

  /// Exact legacy occupied area in half-pixel ticks squared.
  final BigInt legacyAreaHalfPixelSquared;

  /// Exact planned occupied area in half-pixel ticks squared.
  final BigInt plannedAreaHalfPixelSquared;

  BigInt get areaDeltaHalfPixelSquared =>
      plannedAreaHalfPixelSquared - legacyAreaHalfPixelSquared;

  Map<String, Object> toJson() => <String, Object>{
    'prefabKey': prefabKey,
    'sourcePath': sourcePath,
    'kind': _prefabKindJson(kind),
    'legacyColliderCount': legacyColliderCount,
    'outputShapeCount': collisionShapes.length,
    'legacyAreaHalfPixelSquared': legacyAreaHalfPixelSquared.toString(),
    'plannedAreaHalfPixelSquared': plannedAreaHalfPixelSquared.toString(),
    'areaDeltaHalfPixelSquared': areaDeltaHalfPixelSquared.toString(),
    'collisionShapes': terrainSourceShapesToJson(collisionShapes),
  };
}

/// Planned finite ground polygon source for one legacy chunk record.
final class ChunkGroundPolygonMigrationEntry {
  ChunkGroundPolygonMigrationEntry({
    required this.chunkKey,
    required this.sourcePath,
    required this.legacyGapCount,
    required Iterable<TerrainSourceShapeDef> terrainShapes,
    required this.occupiedAreaHalfPixelSquared,
  }) : terrainShapes = canonicalTerrainSourceShapes(terrainShapes);

  final String chunkKey;
  final String sourcePath;
  final int legacyGapCount;
  final List<TerrainSourceShapeDef> terrainShapes;

  /// Exact planned ground area in half-pixel ticks squared.
  final BigInt occupiedAreaHalfPixelSquared;

  Map<String, Object> toJson() => <String, Object>{
    'chunkKey': chunkKey,
    'sourcePath': sourcePath,
    'legacyGapCount': legacyGapCount,
    'outputShapeCount': terrainShapes.length,
    'occupiedAreaHalfPixelSquared': occupiedAreaHalfPixelSquared.toString(),
    'terrainShapes': terrainSourceShapesToJson(terrainShapes),
  };
}

/// Stable count summary for review and golden validation.
final class PolygonAuthoringMigrationSummary {
  const PolygonAuthoringMigrationSummary({
    required this.prefabCount,
    required this.collisionPrefabCount,
    required this.decorationPrefabCount,
    required this.multiColliderPrefabCount,
    required this.reauthoredPrefabCount,
    required this.prefabShapeCount,
    required this.chunkCount,
    required this.legacyGapCount,
    required this.groundShapeCount,
    required this.blockerCount,
  });

  final int prefabCount;
  final int collisionPrefabCount;
  final int decorationPrefabCount;
  final int multiColliderPrefabCount;
  final int reauthoredPrefabCount;
  final int prefabShapeCount;
  final int chunkCount;
  final int legacyGapCount;
  final int groundShapeCount;
  final int blockerCount;

  Map<String, Object> toJson() => <String, Object>{
    'prefabCount': prefabCount,
    'collisionPrefabCount': collisionPrefabCount,
    'decorationPrefabCount': decorationPrefabCount,
    'multiColliderPrefabCount': multiColliderPrefabCount,
    'reauthoredPrefabCount': reauthoredPrefabCount,
    'prefabShapeCount': prefabShapeCount,
    'chunkCount': chunkCount,
    'legacyGapCount': legacyGapCount,
    'groundShapeCount': groundShapeCount,
    'blockerCount': blockerCount,
  };
}

/// Complete deterministic, read-only plan for legacy prefab and chunk terrain.
///
/// Input order and host path separators do not affect the canonical report.
/// The plan performs no filesystem I/O and never implies that schema writes are
/// ready; write transactions and post-write validation remain later gates.
final class PolygonAuthoringMigrationPlan {
  PolygonAuthoringMigrationPlan._({
    required Iterable<PolygonAuthoringMigrationSourceFile> sourceFiles,
    required Iterable<PrefabPolygonMigrationEntry> prefabs,
    required Iterable<ChunkGroundPolygonMigrationEntry> chunks,
    required Iterable<PolygonAuthoringMigrationIssue> issues,
    required this.summary,
  }) : sourceFiles = List<PolygonAuthoringMigrationSourceFile>.unmodifiable(
         sourceFiles,
       ),
       prefabs = List<PrefabPolygonMigrationEntry>.unmodifiable(prefabs),
       chunks = List<ChunkGroundPolygonMigrationEntry>.unmodifiable(chunks),
       issues = List<PolygonAuthoringMigrationIssue>.unmodifiable(issues);

  /// Version of the deterministic check-report structure, not source schemas.
  static const int reportVersion = 2;

  final List<PolygonAuthoringMigrationSourceFile> sourceFiles;
  final List<PrefabPolygonMigrationEntry> prefabs;
  final List<ChunkGroundPolygonMigrationEntry> chunks;
  final List<PolygonAuthoringMigrationIssue> issues;
  final PolygonAuthoringMigrationSummary summary;

  /// Whether any condition prevents a later migration write from proceeding.
  bool get hasBlockers => issues.isNotEmpty;

  /// Builds one canonical plan without reading or writing repository files.
  factory PolygonAuthoringMigrationPlan.build({
    required PrefabData prefabData,
    required String prefabSourcePath,
    required String prefabSourceSha256,
    required Iterable<LevelChunkDef> chunks,
    required Map<String, String> chunkSourcePathByKey,
    required Map<String, String> chunkSourceSha256ByKey,
  }) {
    final issues = <PolygonAuthoringMigrationIssue>[];
    final sourceFiles = <PolygonAuthoringMigrationSourceFile>[];
    final prefabEntries = <PrefabPolygonMigrationEntry>[];
    final canonicalPrefabSourcePath = _canonicalPath(prefabSourcePath);
    sourceFiles.add(
      PolygonAuthoringMigrationSourceFile(
        sourceKind: 'prefabs',
        ownerKey: 'prefab_defs',
        sourcePath: canonicalPrefabSourcePath,
        sha256: prefabSourceSha256,
      ),
    );
    _validateSourceSha256(
      prefabSourceSha256,
      sourcePath: canonicalPrefabSourcePath,
      ownerKey: 'prefab_defs',
      issues: issues,
    );
    final prefabsByKey = _uniquePrefabsByKey(
      prefabData.prefabs,
      sourcePath: canonicalPrefabSourcePath,
      issues: issues,
    );
    for (final prefabKey in prefabsByKey.keys.toList()..sort()) {
      final prefab = prefabsByKey[prefabKey]!;
      final sourcePath = '$canonicalPrefabSourcePath:$prefabKey';
      final result = LegacyPrefabColliderUnion.plan(
        colliders: prefab.colliders,
        sourcePath: sourcePath,
        reviewedReauthoring:
            ReviewedLegacyPrefabCollisionReauthorings.forPrefabKey(prefabKey),
      );
      issues.addAll(
        result.issues.map(
          (issue) => PolygonAuthoringMigrationIssue(
            sourcePath: _canonicalPath(issue.sourcePath),
            ownerKey: prefabKey,
            elementIndex: issue.elementIndex,
            code: issue.code,
            message: issue.message,
          ),
        ),
      );
      prefabEntries.add(
        PrefabPolygonMigrationEntry(
          prefabKey: prefabKey,
          sourcePath: sourcePath,
          kind: _classifyPrefab(prefab, result),
          legacyColliderCount: prefab.colliders.length,
          collisionShapes: result.shapes,
          legacyAreaHalfPixelSquared: result.occupiedAreaHalfPixelSquared,
          plannedAreaHalfPixelSquared: result.plannedAreaHalfPixelSquared,
        ),
      );
    }
    for (final reauthoring in ReviewedLegacyPrefabCollisionReauthorings.all) {
      if (!prefabsByKey.containsKey(reauthoring.prefabKey)) {
        issues.add(
          PolygonAuthoringMigrationIssue(
            sourcePath: canonicalPrefabSourcePath,
            ownerKey: reauthoring.prefabKey,
            elementIndex: 0,
            code: 'migration_reauthoring_prefab_missing',
            message:
                'Reviewed collision correction has no matching legacy prefab.',
          ),
        );
      }
    }

    final chunkEntries = <ChunkGroundPolygonMigrationEntry>[];
    final chunksByKey = _uniqueChunksByKey(chunks, issues: issues);
    for (final chunkKey in chunksByKey.keys.toList()..sort()) {
      final chunk = chunksByKey[chunkKey]!;
      final rawSourcePath = chunkSourcePathByKey[chunkKey];
      final sourcePath = _canonicalPath(
        rawSourcePath ?? 'assets/authoring/level/chunks/$chunkKey.json',
      );
      if (rawSourcePath == null) {
        issues.add(
          PolygonAuthoringMigrationIssue(
            sourcePath: sourcePath,
            ownerKey: chunkKey,
            elementIndex: 0,
            code: 'migration_chunk_source_path_missing',
            message: 'Chunk migration requires its exact source path.',
          ),
        );
      }
      final sourceSha256 = chunkSourceSha256ByKey[chunkKey] ?? '';
      sourceFiles.add(
        PolygonAuthoringMigrationSourceFile(
          sourceKind: 'chunk',
          ownerKey: chunkKey,
          sourcePath: sourcePath,
          sha256: sourceSha256,
        ),
      );
      _validateSourceSha256(
        sourceSha256,
        sourcePath: sourcePath,
        ownerKey: chunkKey,
        issues: issues,
      );
      final result = LegacyChunkGroundMigration.plan(
        chunk: chunk,
        sourcePath: sourcePath,
      );
      issues.addAll(
        result.issues.map(
          (issue) => PolygonAuthoringMigrationIssue(
            sourcePath: _canonicalPath(issue.sourcePath),
            ownerKey: chunkKey,
            elementIndex: issue.elementIndex,
            code: issue.code,
            message: issue.message,
          ),
        ),
      );
      chunkEntries.add(
        ChunkGroundPolygonMigrationEntry(
          chunkKey: chunkKey,
          sourcePath: sourcePath,
          legacyGapCount: chunk.groundGaps.length,
          terrainShapes: result.shapes,
          occupiedAreaHalfPixelSquared: result.occupiedAreaHalfPixelSquared,
        ),
      );
    }

    prefabEntries.sort(
      (left, right) => left.prefabKey.compareTo(right.prefabKey),
    );
    chunkEntries.sort((left, right) => left.chunkKey.compareTo(right.chunkKey));
    sourceFiles.sort();
    for (var index = 1; index < sourceFiles.length; index += 1) {
      final previous = sourceFiles[index - 1];
      final current = sourceFiles[index];
      if (previous.sourcePath == current.sourcePath) {
        issues.add(
          PolygonAuthoringMigrationIssue(
            sourcePath: current.sourcePath,
            ownerKey: current.ownerKey,
            elementIndex: 0,
            code: 'migration_source_path_duplicate',
            message: 'Migration source paths must identify one file each.',
          ),
        );
      }
    }
    issues.sort();
    final summary = PolygonAuthoringMigrationSummary(
      prefabCount: prefabEntries.length,
      collisionPrefabCount: prefabEntries
          .where((entry) => entry.legacyColliderCount > 0)
          .length,
      decorationPrefabCount: prefabEntries
          .where((entry) => entry.kind == PrefabPolygonMigrationKind.decoration)
          .length,
      multiColliderPrefabCount: prefabEntries
          .where((entry) => entry.legacyColliderCount > 1)
          .length,
      reauthoredPrefabCount: prefabEntries
          .where(
            (entry) =>
                entry.kind == PrefabPolygonMigrationKind.reviewedReauthoring,
          )
          .length,
      prefabShapeCount: prefabEntries.fold<int>(
        0,
        (sum, entry) => sum + entry.collisionShapes.length,
      ),
      chunkCount: chunkEntries.length,
      legacyGapCount: chunkEntries.fold<int>(
        0,
        (sum, entry) => sum + entry.legacyGapCount,
      ),
      groundShapeCount: chunkEntries.fold<int>(
        0,
        (sum, entry) => sum + entry.terrainShapes.length,
      ),
      blockerCount: issues.length,
    );
    return PolygonAuthoringMigrationPlan._(
      sourceFiles: sourceFiles,
      prefabs: prefabEntries,
      chunks: chunkEntries,
      issues: issues,
      summary: summary,
    );
  }

  /// Compares current source signatures with the exact files behind this plan.
  ///
  /// Callers compute SHA-256 values from freshly read source text immediately
  /// before any write. Missing, changed, or ambiguously addressed paths fail
  /// closed; extra paths outside this plan are ignored.
  List<PolygonAuthoringMigrationIssue> auditSourceDigests(
    Map<String, String> currentSha256BySourcePath,
  ) {
    final currentByCanonicalPath = <String, Set<String>>{};
    for (final entry in currentSha256BySourcePath.entries) {
      currentByCanonicalPath
          .putIfAbsent(_canonicalPath(entry.key), () => <String>{})
          .add(entry.value);
    }
    final driftIssues = <PolygonAuthoringMigrationIssue>[];
    for (final source in sourceFiles) {
      final current = currentByCanonicalPath[source.sourcePath];
      if (current == null || current.isEmpty) {
        driftIssues.add(
          PolygonAuthoringMigrationIssue(
            sourcePath: source.sourcePath,
            ownerKey: source.ownerKey,
            elementIndex: 0,
            code: 'migration_source_missing',
            message: 'Migration source no longer exists at its reviewed path.',
          ),
        );
      } else if (current.length != 1) {
        driftIssues.add(
          PolygonAuthoringMigrationIssue(
            sourcePath: source.sourcePath,
            ownerKey: source.ownerKey,
            elementIndex: 0,
            code: 'migration_source_path_ambiguous',
            message:
                'Multiple current files resolve to the reviewed source path.',
          ),
        );
      } else if (current.single != source.sha256) {
        driftIssues.add(
          PolygonAuthoringMigrationIssue(
            sourcePath: source.sourcePath,
            ownerKey: source.ownerKey,
            elementIndex: 0,
            code: 'migration_source_drift',
            message:
                'Migration source SHA-256 changed after the plan was built.',
          ),
        );
      }
    }
    driftIssues.sort();
    return List<PolygonAuthoringMigrationIssue>.unmodifiable(driftIssues);
  }

  /// Emits stable, reviewable JSON with exact areas encoded as decimal strings.
  String toCanonicalJson() {
    final report = <String, Object>{
      'reportVersion': reportVersion,
      'mode': 'check',
      'sourceFiles': sourceFiles
          .map((source) => source.toJson())
          .toList(growable: false),
      'summary': summary.toJson(),
      'prefabs': prefabs.map((entry) => entry.toJson()).toList(growable: false),
      'chunks': chunks.map((entry) => entry.toJson()).toList(growable: false),
      'blockers': issues.map((issue) => issue.toJson()).toList(growable: false),
    };
    return '${const JsonEncoder.withIndent('  ').convert(report)}\n';
  }
}

Map<String, PrefabDef> _uniquePrefabsByKey(
  Iterable<PrefabDef> prefabs, {
  required String sourcePath,
  required List<PolygonAuthoringMigrationIssue> issues,
}) {
  final grouped = <String, List<PrefabDef>>{};
  for (final prefab in prefabs) {
    grouped.putIfAbsent(prefab.prefabKey, () => <PrefabDef>[]).add(prefab);
  }
  final unique = <String, PrefabDef>{};
  for (final key in grouped.keys.toList()..sort()) {
    final matches = grouped[key]!;
    if (key.isEmpty || matches.length != 1) {
      issues.add(
        PolygonAuthoringMigrationIssue(
          sourcePath: sourcePath,
          ownerKey: key,
          elementIndex: 0,
          code: key.isEmpty
              ? 'migration_prefab_key_missing'
              : 'migration_prefab_key_duplicate',
          message: key.isEmpty
              ? 'Prefab migration requires a stable prefab key.'
              : 'Prefab migration requires unique prefab keys.',
        ),
      );
    } else {
      unique[key] = matches.single;
    }
  }
  return unique;
}

void _validateSourceSha256(
  String sha256, {
  required String sourcePath,
  required String ownerKey,
  required List<PolygonAuthoringMigrationIssue> issues,
}) {
  if (sha256.isEmpty) {
    issues.add(
      PolygonAuthoringMigrationIssue(
        sourcePath: sourcePath,
        ownerKey: ownerKey,
        elementIndex: 0,
        code: 'migration_source_sha256_missing',
        message: 'Migration source requires an exact SHA-256 signature.',
      ),
    );
  } else if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256)) {
    issues.add(
      PolygonAuthoringMigrationIssue(
        sourcePath: sourcePath,
        ownerKey: ownerKey,
        elementIndex: 0,
        code: 'migration_source_sha256_invalid',
        message: 'Migration source SHA-256 must be 64 lowercase hex digits.',
      ),
    );
  }
}

Map<String, LevelChunkDef> _uniqueChunksByKey(
  Iterable<LevelChunkDef> chunks, {
  required List<PolygonAuthoringMigrationIssue> issues,
}) {
  final grouped = <String, List<LevelChunkDef>>{};
  for (final chunk in chunks) {
    grouped.putIfAbsent(chunk.chunkKey, () => <LevelChunkDef>[]).add(chunk);
  }
  final unique = <String, LevelChunkDef>{};
  for (final key in grouped.keys.toList()..sort()) {
    final matches = grouped[key]!;
    if (key.isEmpty || matches.length != 1) {
      issues.add(
        PolygonAuthoringMigrationIssue(
          sourcePath: _canonicalPath(
            'assets/authoring/level/chunks/${key.isEmpty ? '_missing' : key}.json',
          ),
          ownerKey: key,
          elementIndex: 0,
          code: key.isEmpty
              ? 'migration_chunk_key_missing'
              : 'migration_chunk_key_duplicate',
          message: key.isEmpty
              ? 'Chunk migration requires a stable chunk key.'
              : 'Chunk migration requires unique chunk keys.',
        ),
      );
    } else {
      unique[key] = matches.single;
    }
  }
  return unique;
}

PrefabPolygonMigrationKind _classifyPrefab(
  PrefabDef prefab,
  LegacyPrefabColliderUnionResult result,
) {
  if (prefab.colliders.isEmpty) return PrefabPolygonMigrationKind.decoration;
  if (result.isReauthored) {
    return PrefabPolygonMigrationKind.reviewedReauthoring;
  }
  if (result.shapes.length > 1) {
    return PrefabPolygonMigrationKind.disconnected;
  }
  if (prefab.colliders.length > 1) return PrefabPolygonMigrationKind.union;
  return PrefabPolygonMigrationKind.isolated;
}

String _prefabKindJson(PrefabPolygonMigrationKind kind) => switch (kind) {
  PrefabPolygonMigrationKind.decoration => 'decoration',
  PrefabPolygonMigrationKind.isolated => 'isolated',
  PrefabPolygonMigrationKind.union => 'union',
  PrefabPolygonMigrationKind.disconnected => 'disconnected',
  PrefabPolygonMigrationKind.reviewedReauthoring => 'reviewedReauthoring',
};

String _canonicalPath(String path) => path.replaceAll('\\', '/');
