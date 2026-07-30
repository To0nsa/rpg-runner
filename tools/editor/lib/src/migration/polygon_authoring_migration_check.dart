import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../chunks/chunk_store.dart';
import '../prefabs/models/models.dart';
import '../prefabs/store/prefab_store.dart';
import '../terrain_authoring/terrain_source_core_adapter.dart';
import '../terrain_authoring/terrain_source_models.dart';
import '../workspace/editor_workspace.dart';
import '../workspace/workspace_file_io.dart';
import 'polygon_authoring_legacy_codec.dart';
import 'polygon_authoring_migration_plan.dart';
import 'polygon_authoring_target_codec.dart';
import 'polygon_authoring_target_models.dart';
import 'strict_migration_json.dart';

/// One target file validated entirely in memory by a migration check.
final class PolygonAuthoringMigrationTargetFile {
  const PolygonAuthoringMigrationTargetFile({
    required this.sourceKind,
    required this.ownerKey,
    required this.sourcePath,
    required this.targetSchemaVersion,
    required this.beforeSha256,
    required this.afterSha256,
    required this.canonicalContents,
  });

  final String sourceKind;
  final String ownerKey;
  final String sourcePath;
  final int targetSchemaVersion;
  final String beforeSha256;
  final String afterSha256;

  /// Strictly round-tripped target text; no checker path writes this value.
  final String canonicalContents;

  bool get hasPendingChange => beforeSha256 != afterSha256;

  Map<String, Object> toJson() => <String, Object>{
    'sourceKind': sourceKind,
    'ownerKey': ownerKey,
    'sourcePath': sourcePath,
    'targetSchemaVersion': targetSchemaVersion,
    'beforeSha256': beforeSha256,
    'afterSha256': afterSha256,
    'pendingChange': hasPendingChange,
  };
}

/// Revision decision for one owner converted by the representation migration.
final class PolygonAuthoringMigrationRevisionRecord {
  const PolygonAuthoringMigrationRevisionRecord({
    required this.ownerKind,
    required this.ownerKey,
    required this.beforeRevision,
    required this.afterRevision,
  });

  final String ownerKind;
  final String ownerKey;
  final int beforeRevision;
  final int afterRevision;

  bool get changed => beforeRevision != afterRevision;

  Map<String, Object> toJson() => <String, Object>{
    'ownerKind': ownerKind,
    'ownerKey': ownerKey,
    'beforeRevision': beforeRevision,
    'afterRevision': afterRevision,
    'changed': changed,
    'decision': changed ? 'changed' : 'unchangedRepresentationOnly',
  };
}

/// Downstream chunk-placement impact of converting one prefab definition.
final class PolygonAuthoringMigrationImpactRecord {
  PolygonAuthoringMigrationImpactRecord({
    required this.prefabKey,
    required Iterable<String> referencingChunkKeys,
    required this.placementCount,
  }) : referencingChunkKeys = List<String>.unmodifiable(
         List<String>.of(referencingChunkKeys)..sort(),
       );

  final String prefabKey;
  final List<String> referencingChunkKeys;
  final int placementCount;

  Map<String, Object> toJson() => <String, Object>{
    'prefabKey': prefabKey,
    'referencingChunkKeys': referencingChunkKeys,
    'placementCount': placementCount,
  };
}

/// Authored-source generation recognized by the read-only migration check.
enum PolygonAuthoringMigrationSourceState {
  legacy('legacy'),
  current('current');

  const PolygonAuthoringMigrationSourceState(this.jsonValue);

  final String jsonValue;
}

/// Complete read-only migration readiness check for one repository snapshot.
///
/// Legacy construction computes a blocker-aware polygon plan and builds every
/// target in memory. Current construction strictly validates canonical source
/// and produces byte-identical no-op targets. Mixed generations fail closed.
/// Neither path writes authored source or changes normal stores.
final class PolygonAuthoringMigrationCheck {
  PolygonAuthoringMigrationCheck._({
    required this.sourceState,
    required this.summary,
    required Iterable<PolygonAuthoringMigrationSourceFile> sourceFiles,
    required this.legacyPlan,
    required Iterable<PolygonAuthoringMigrationTargetFile> targetFiles,
    required Iterable<PolygonAuthoringMigrationRevisionRecord> revisionRecords,
    required Iterable<PolygonAuthoringMigrationImpactRecord> impactRecords,
    required Iterable<PolygonAuthoringMigrationIssue> issues,
  }) : sourceFiles = List<PolygonAuthoringMigrationSourceFile>.unmodifiable(
         sourceFiles,
       ),
       targetFiles = List<PolygonAuthoringMigrationTargetFile>.unmodifiable(
         targetFiles,
       ),
       revisionRecords =
           List<PolygonAuthoringMigrationRevisionRecord>.unmodifiable(
             revisionRecords,
           ),
       impactRecords = List<PolygonAuthoringMigrationImpactRecord>.unmodifiable(
         impactRecords,
       ),
       issues = List<PolygonAuthoringMigrationIssue>.unmodifiable(issues);

  /// Version of the complete readiness report, independent of source schemas.
  static const int reportVersion = 2;

  final PolygonAuthoringMigrationSourceState sourceState;
  final PolygonAuthoringMigrationSummary summary;
  final List<PolygonAuthoringMigrationSourceFile> sourceFiles;

  /// Legacy conversion detail, absent after the repository reaches v3/v2.
  final PolygonAuthoringMigrationPlan? legacyPlan;
  final List<PolygonAuthoringMigrationTargetFile> targetFiles;
  final List<PolygonAuthoringMigrationRevisionRecord> revisionRecords;
  final List<PolygonAuthoringMigrationImpactRecord> impactRecords;

  /// Sorted union of plan and in-memory target-validation blockers.
  final List<PolygonAuthoringMigrationIssue> issues;

  bool get hasBlockers => issues.isNotEmpty;

  /// Rechecks freshly read source signatures against this exact snapshot.
  List<PolygonAuthoringMigrationIssue> auditSourceDigests(
    Map<String, String> currentSha256BySourcePath,
  ) => auditPolygonAuthoringSourceDigests(
    sourceFiles: sourceFiles,
    currentSha256BySourcePath: currentSha256BySourcePath,
  );

  /// Loads the fixed prefab/chunk migration scope rooted at [workspaceRoot].
  ///
  /// File reads and strict parsing are the only side effects. A source read or
  /// schema failure throws [PolygonAuthoringMigrationCheckException] before a
  /// plan can be mistaken for complete.
  factory PolygonAuthoringMigrationCheck.fromRepository(String workspaceRoot) {
    final workspace = EditorWorkspace(rootPath: workspaceRoot);
    final prefabPath = PrefabStore.prefabDefsPath;
    final prefabRaw = _readRequiredSource(workspace, prefabPath);
    final prefabSchemaVersion = _readSchemaVersion(
      prefabRaw,
      sourcePath: prefabPath,
      invalidCode: 'migration_prefab_source_invalid',
    );
    if (prefabSchemaVersion != 1 &&
        prefabSchemaVersion != 2 &&
        prefabSchemaVersion != polygonPrefabSchemaVersion) {
      throw PolygonAuthoringMigrationCheckException(
        code: 'migration_prefab_schema_unsupported',
        sourcePath: prefabPath,
        message:
            'Expected legacy prefab schema 1/2 or current schema '
            '$polygonPrefabSchemaVersion, found $prefabSchemaVersion.',
      );
    }

    final chunkDirectory = Directory(
      workspace.resolve(ChunkStore.chunksDirectoryPath),
    );
    if (!chunkDirectory.existsSync()) {
      throw const PolygonAuthoringMigrationCheckException(
        code: 'migration_chunk_directory_missing',
        sourcePath: ChunkStore.chunksDirectoryPath,
        message: 'Chunk source directory does not exist.',
      );
    }
    final chunkFiles =
        chunkDirectory
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .where((file) => p.extension(file.path).toLowerCase() == '.json')
            .toList(growable: false)
          ..sort((left, right) {
            final leftPath = _workspacePath(workspace, left.path);
            final rightPath = _workspacePath(workspace, right.path);
            return leftPath.compareTo(rightPath);
          });
    if (chunkFiles.isEmpty) {
      throw const PolygonAuthoringMigrationCheckException(
        code: 'migration_chunk_sources_missing',
        sourcePath: ChunkStore.chunksDirectoryPath,
        message: 'Migration check requires at least one chunk source file.',
      );
    }

    final rawChunkInputs = <_RawChunkInput>[];
    final caseInsensitivePaths = <String, String>{};
    for (final file in chunkFiles) {
      final sourcePath = _workspacePath(workspace, file.path);
      final pathIdentity = sourcePath.toLowerCase();
      final previousPath = caseInsensitivePaths[pathIdentity];
      if (previousPath != null) {
        throw PolygonAuthoringMigrationCheckException(
          code: 'migration_chunk_source_path_collision',
          sourcePath: sourcePath,
          message: 'Chunk source path collides with $previousPath.',
        );
      }
      caseInsensitivePaths[pathIdentity] = sourcePath;
      final raw = _readRequiredSource(workspace, sourcePath);
      final schemaVersion = _readSchemaVersion(
        raw,
        sourcePath: sourcePath,
        invalidCode: 'migration_chunk_source_invalid',
      );
      if (schemaVersion != 1 && schemaVersion != polygonChunkSchemaVersion) {
        throw PolygonAuthoringMigrationCheckException(
          code: 'migration_chunk_schema_unsupported',
          sourcePath: sourcePath,
          message:
              'Expected legacy chunk schema 1 or current schema '
              '$polygonChunkSchemaVersion, found $schemaVersion.',
        );
      }
      rawChunkInputs.add(
        _RawChunkInput(
          sourcePath: sourcePath,
          raw: raw,
          schemaVersion: schemaVersion,
        ),
      );
    }

    final prefabState = prefabSchemaVersion == polygonPrefabSchemaVersion
        ? PolygonAuthoringMigrationSourceState.current
        : PolygonAuthoringMigrationSourceState.legacy;
    final chunkStates = rawChunkInputs
        .map(
          (input) => input.schemaVersion == polygonChunkSchemaVersion
              ? PolygonAuthoringMigrationSourceState.current
              : PolygonAuthoringMigrationSourceState.legacy,
        )
        .toSet();
    if (chunkStates.length != 1 || chunkStates.single != prefabState) {
      final chunkVersions =
          rawChunkInputs.map((input) => input.schemaVersion).toSet().toList()
            ..sort();
      throw PolygonAuthoringMigrationCheckException(
        code: 'migration_mixed_schema_generation',
        sourcePath: ChunkStore.chunksDirectoryPath,
        message:
            'Prefab schema $prefabSchemaVersion and chunk schema(s) '
            '${chunkVersions.join(', ')} must be entirely legacy or entirely '
            'current.',
      );
    }

    if (prefabState == PolygonAuthoringMigrationSourceState.current) {
      return _buildCurrent(
        prefabSourcePath: prefabPath,
        prefabRaw: prefabRaw,
        chunkInputs: rawChunkInputs,
      );
    }

    final LegacyPrefabMigrationDocument prefabDocument;
    try {
      prefabDocument = PolygonAuthoringLegacyCodec.decodePrefab(
        prefabRaw,
        sourcePath: prefabPath,
      );
    } on FormatException catch (error) {
      throw PolygonAuthoringMigrationCheckException(
        code: 'migration_prefab_source_invalid',
        sourcePath: prefabPath,
        message: error.message,
      );
    }
    final legacyChunkInputs = <_LegacyChunkInput>[];
    for (final input in rawChunkInputs) {
      final LegacyChunkMigrationDocument document;
      try {
        document = PolygonAuthoringLegacyCodec.decodeChunkV1(
          input.raw,
          sourcePath: input.sourcePath,
        );
      } on FormatException catch (error) {
        throw PolygonAuthoringMigrationCheckException(
          code: 'migration_chunk_source_invalid',
          sourcePath: input.sourcePath,
          message: error.message,
        );
      }
      legacyChunkInputs.add(
        _LegacyChunkInput(sourcePath: input.sourcePath, document: document),
      );
    }
    return _buildLegacy(
      prefabSourcePath: prefabPath,
      prefabDocument: prefabDocument,
      chunkInputs: legacyChunkInputs,
    );
  }

  static PolygonAuthoringMigrationCheck _buildLegacy({
    required String prefabSourcePath,
    required LegacyPrefabMigrationDocument prefabDocument,
    required List<_LegacyChunkInput> chunkInputs,
  }) {
    final chunks = chunkInputs
        .map((input) => input.document.chunk)
        .toList(growable: false);
    final chunkSourcePaths = <String, String>{
      for (final input in chunkInputs)
        input.document.chunk.chunkKey: input.sourcePath,
    };
    final chunkSourceSha256 = <String, String>{
      for (final input in chunkInputs)
        input.document.chunk.chunkKey: input.document.sourceSha256,
    };
    final plan = PolygonAuthoringMigrationPlan.build(
      prefabData: prefabDocument.prefabData,
      prefabSourcePath: prefabSourcePath,
      prefabSourceSha256: prefabDocument.sourceSha256,
      chunks: chunks,
      chunkSourcePathByKey: chunkSourcePaths,
      chunkSourceSha256ByKey: chunkSourceSha256,
    );

    final issues = <PolygonAuthoringMigrationIssue>[...plan.issues];
    final prefabKeys = prefabDocument.prefabs
        .map((prefab) => prefab.prefabKey)
        .toSet();
    final placementsByPrefab = <String, List<String>>{};
    for (final input in chunkInputs) {
      for (
        var index = 0;
        index < input.document.chunk.prefabs.length;
        index++
      ) {
        final placement = input.document.chunk.prefabs[index];
        final prefabKey = placement.resolvedPrefabRef;
        if (!prefabKeys.contains(prefabKey)) {
          issues.add(
            PolygonAuthoringMigrationIssue(
              sourcePath: input.sourcePath,
              ownerKey: input.document.chunk.chunkKey,
              elementIndex: index,
              code: 'migration_unknown_prefab_reference',
              message: 'Chunk placement references unknown prefab $prefabKey.',
            ),
          );
          continue;
        }
        placementsByPrefab
            .putIfAbsent(prefabKey, () => <String>[])
            .add(input.document.chunk.chunkKey);
      }
    }

    final revisionRecords = <PolygonAuthoringMigrationRevisionRecord>[
      for (final prefab in prefabDocument.prefabs)
        PolygonAuthoringMigrationRevisionRecord(
          ownerKind: 'prefab',
          ownerKey: prefab.prefabKey,
          beforeRevision: prefab.revision,
          afterRevision: prefab.revision,
        ),
      for (final chunk in chunks)
        PolygonAuthoringMigrationRevisionRecord(
          ownerKind: 'chunk',
          ownerKey: chunk.chunkKey,
          beforeRevision: chunk.revision,
          afterRevision: chunk.revision,
        ),
    ]..sort(_compareRevisionRecords);
    final impactRecords = <PolygonAuthoringMigrationImpactRecord>[
      for (final prefabKey in prefabKeys.toList()..sort())
        PolygonAuthoringMigrationImpactRecord(
          prefabKey: prefabKey,
          referencingChunkKeys: (placementsByPrefab[prefabKey] ?? const [])
              .toSet(),
          placementCount: placementsByPrefab[prefabKey]?.length ?? 0,
        ),
    ];

    final targetFiles = <PolygonAuthoringMigrationTargetFile>[];
    if (issues.isEmpty) {
      _buildPrefabTarget(
        prefabSourcePath: prefabSourcePath,
        prefabDocument: prefabDocument,
        plan: plan,
        targetFiles: targetFiles,
        issues: issues,
      );
      _buildChunkTargets(
        chunkInputs: chunkInputs,
        plan: plan,
        targetFiles: targetFiles,
        issues: issues,
      );
    }
    targetFiles.sort(
      (left, right) => left.sourcePath.compareTo(right.sourcePath),
    );
    issues.sort();
    return PolygonAuthoringMigrationCheck._(
      sourceState: PolygonAuthoringMigrationSourceState.legacy,
      summary: plan.summary,
      sourceFiles: plan.sourceFiles,
      legacyPlan: plan,
      targetFiles: targetFiles,
      revisionRecords: revisionRecords,
      impactRecords: impactRecords,
      issues: issues,
    );
  }

  static PolygonAuthoringMigrationCheck _buildCurrent({
    required String prefabSourcePath,
    required String prefabRaw,
    required List<_RawChunkInput> chunkInputs,
  }) {
    final PrefabV3TargetDocument prefabDocument;
    final String canonicalPrefabSource;
    try {
      prefabDocument = PolygonAuthoringTargetCodec.decodePrefabV3(
        prefabRaw,
        sourcePath: prefabSourcePath,
      );
      canonicalPrefabSource = PolygonAuthoringTargetCodec.encodePrefabV3(
        prefabDocument,
      );
    } on Object catch (error) {
      throw PolygonAuthoringMigrationCheckException(
        code: 'migration_prefab_source_invalid',
        sourcePath: prefabSourcePath,
        message: '$error',
      );
    }
    _requireCanonicalCurrentSource(
      raw: prefabRaw,
      canonical: canonicalPrefabSource,
      sourcePath: prefabSourcePath,
    );

    final currentChunkInputs = <_CurrentChunkInput>[];
    for (final input in chunkInputs) {
      final ChunkV2TargetDocument document;
      final String canonicalSource;
      try {
        document = PolygonAuthoringTargetCodec.decodeChunkV2(
          input.raw,
          sourcePath: input.sourcePath,
        );
        canonicalSource = PolygonAuthoringTargetCodec.encodeChunkV2(document);
      } on Object catch (error) {
        throw PolygonAuthoringMigrationCheckException(
          code: 'migration_chunk_source_invalid',
          sourcePath: input.sourcePath,
          message: '$error',
        );
      }
      _requireCanonicalCurrentSource(
        raw: input.raw,
        canonical: canonicalSource,
        sourcePath: input.sourcePath,
      );
      currentChunkInputs.add(
        _CurrentChunkInput(
          sourcePath: input.sourcePath,
          raw: input.raw,
          document: document,
        ),
      );
    }

    final sourceFiles = <PolygonAuthoringMigrationSourceFile>[
      PolygonAuthoringMigrationSourceFile(
        sourceKind: 'prefabs',
        ownerKey: 'prefab_defs',
        sourcePath: prefabSourcePath,
        sha256: _sha256(prefabRaw),
      ),
      for (final input in currentChunkInputs)
        PolygonAuthoringMigrationSourceFile(
          sourceKind: 'chunk',
          ownerKey: input.document.chunkKey,
          sourcePath: input.sourcePath,
          sha256: _sha256(input.raw),
        ),
    ]..sort();
    final issues = <PolygonAuthoringMigrationIssue>[];
    final prefabKeys = prefabDocument.prefabs
        .map((prefab) => prefab.prefabKey)
        .toSet();
    final chunkKeys = <String>{};
    final placementsByPrefab = <String, List<String>>{};
    for (
      var chunkIndex = 0;
      chunkIndex < currentChunkInputs.length;
      chunkIndex++
    ) {
      final input = currentChunkInputs[chunkIndex];
      final chunk = input.document;
      if (!chunkKeys.add(chunk.chunkKey)) {
        issues.add(
          PolygonAuthoringMigrationIssue(
            sourcePath: input.sourcePath,
            ownerKey: chunk.chunkKey,
            elementIndex: 0,
            code: 'migration_chunk_key_duplicate',
            message: 'Migration check requires unique chunk keys.',
          ),
        );
      }
      _appendCurrentGeometryIssues(
        shapes: chunk.collisionShapes,
        sourcePath: input.sourcePath,
        ownerKey: chunk.chunkKey,
        chunkIndex: chunkIndex,
        issues: issues,
      );
      for (var index = 0; index < chunk.prefabs.length; index++) {
        final prefabKey = chunk.prefabs[index].resolvedPrefabRef;
        if (!prefabKeys.contains(prefabKey)) {
          issues.add(
            PolygonAuthoringMigrationIssue(
              sourcePath: input.sourcePath,
              ownerKey: chunk.chunkKey,
              elementIndex: index,
              code: 'migration_unknown_prefab_reference',
              message: 'Chunk placement references unknown prefab $prefabKey.',
            ),
          );
          continue;
        }
        placementsByPrefab
            .putIfAbsent(prefabKey, () => <String>[])
            .add(chunk.chunkKey);
      }
    }
    for (final prefab in prefabDocument.prefabs) {
      _appendCurrentGeometryIssues(
        shapes: prefab.collisionShapes,
        sourcePath: prefabSourcePath,
        ownerKey: prefab.prefabKey,
        chunkIndex: -1,
        issues: issues,
      );
    }

    final revisionRecords = <PolygonAuthoringMigrationRevisionRecord>[
      for (final prefab in prefabDocument.prefabs)
        PolygonAuthoringMigrationRevisionRecord(
          ownerKind: 'prefab',
          ownerKey: prefab.prefabKey,
          beforeRevision: prefab.revision,
          afterRevision: prefab.revision,
        ),
      for (final input in currentChunkInputs)
        PolygonAuthoringMigrationRevisionRecord(
          ownerKind: 'chunk',
          ownerKey: input.document.chunkKey,
          beforeRevision: input.document.revision,
          afterRevision: input.document.revision,
        ),
    ]..sort(_compareRevisionRecords);
    final impactRecords = <PolygonAuthoringMigrationImpactRecord>[
      for (final prefabKey in prefabKeys.toList()..sort())
        PolygonAuthoringMigrationImpactRecord(
          prefabKey: prefabKey,
          referencingChunkKeys: (placementsByPrefab[prefabKey] ?? const [])
              .toSet(),
          placementCount: placementsByPrefab[prefabKey]?.length ?? 0,
        ),
    ];

    final targetFiles = <PolygonAuthoringMigrationTargetFile>[];
    if (issues.isEmpty) {
      targetFiles.add(
        PolygonAuthoringMigrationTargetFile(
          sourceKind: 'prefabs',
          ownerKey: 'prefab_defs',
          sourcePath: prefabSourcePath,
          targetSchemaVersion: polygonPrefabSchemaVersion,
          beforeSha256: _sha256(prefabRaw),
          afterSha256: _sha256(canonicalPrefabSource),
          canonicalContents: canonicalPrefabSource,
        ),
      );
      for (final input in currentChunkInputs) {
        targetFiles.add(
          PolygonAuthoringMigrationTargetFile(
            sourceKind: 'chunk',
            ownerKey: input.document.chunkKey,
            sourcePath: input.sourcePath,
            targetSchemaVersion: polygonChunkSchemaVersion,
            beforeSha256: _sha256(input.raw),
            afterSha256: _sha256(input.raw),
            canonicalContents: input.raw,
          ),
        );
      }
    }
    targetFiles.sort(
      (left, right) => left.sourcePath.compareTo(right.sourcePath),
    );
    issues.sort();
    final summary = PolygonAuthoringMigrationSummary(
      prefabCount: prefabDocument.prefabs.length,
      collisionPrefabCount: prefabDocument.prefabs
          .where((prefab) => prefab.collisionShapes.isNotEmpty)
          .length,
      decorationPrefabCount: prefabDocument.prefabs
          .where((prefab) => prefab.kind.jsonValue == 'decoration')
          .length,
      multiColliderPrefabCount: prefabDocument.prefabs
          .where((prefab) => prefab.collisionShapes.length > 1)
          .length,
      reauthoredPrefabCount: 0,
      prefabShapeCount: prefabDocument.prefabs.fold<int>(
        0,
        (sum, prefab) => sum + prefab.collisionShapes.length,
      ),
      chunkCount: currentChunkInputs.length,
      legacyGapCount: 0,
      groundShapeCount: currentChunkInputs.fold<int>(
        0,
        (sum, input) => sum + input.document.collisionShapes.length,
      ),
      blockerCount: issues.length,
    );
    return PolygonAuthoringMigrationCheck._(
      sourceState: PolygonAuthoringMigrationSourceState.current,
      summary: summary,
      sourceFiles: sourceFiles,
      legacyPlan: null,
      targetFiles: targetFiles,
      revisionRecords: revisionRecords,
      impactRecords: impactRecords,
      issues: issues,
    );
  }

  /// Emits the canonical readiness report without embedding target file text.
  String toCanonicalJson() {
    final placementCount = impactRecords.fold<int>(
      0,
      (sum, record) => sum + record.placementCount,
    );
    final summary = <String, Object>{
      ...this.summary.toJson(),
      'sourceFileCount': sourceFiles.length,
      'targetFileCount': targetFiles.length,
      'pendingMigrationFileCount': targetFiles
          .where((target) => target.hasPendingChange)
          .length,
      'revisionRecordCount': revisionRecords.length,
      'revisionChangedCount': revisionRecords
          .where((record) => record.changed)
          .length,
      'impactRecordCount': impactRecords.length,
      'referencedPrefabCount': impactRecords
          .where((record) => record.placementCount > 0)
          .length,
      'downstreamPlacementCount': placementCount,
      'blockerCount': issues.length,
    };
    final report = <String, Object>{
      'reportVersion': reportVersion,
      'mode': 'check',
      'sourceState': sourceState.jsonValue,
      'status': hasBlockers ? 'blocked' : 'ready',
      'summary': summary,
      'sourceFiles': sourceFiles
          .map((source) => source.toJson())
          .toList(growable: false),
      'targetFiles': targetFiles
          .map((target) => target.toJson())
          .toList(growable: false),
      'revisionRecords': revisionRecords
          .map((record) => record.toJson())
          .toList(growable: false),
      'impactRecords': impactRecords
          .map((record) => record.toJson())
          .toList(growable: false),
      'prefabs': (legacyPlan?.prefabs ?? const <PrefabPolygonMigrationEntry>[])
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'chunks':
          (legacyPlan?.chunks ?? const <ChunkGroundPolygonMigrationEntry>[])
              .map((entry) => entry.toJson())
              .toList(growable: false),
      'blockers': issues.map((issue) => issue.toJson()).toList(growable: false),
    };
    return '${const JsonEncoder.withIndent('  ').convert(report)}\n';
  }
}

/// Stable source-loading failure that prevents a complete readiness check.
final class PolygonAuthoringMigrationCheckException implements Exception {
  const PolygonAuthoringMigrationCheckException({
    required this.code,
    required this.sourcePath,
    required this.message,
  });

  final String code;
  final String sourcePath;
  final String message;

  @override
  String toString() => '$code $sourcePath: $message';
}

void _buildPrefabTarget({
  required String prefabSourcePath,
  required LegacyPrefabMigrationDocument prefabDocument,
  required PolygonAuthoringMigrationPlan plan,
  required List<PolygonAuthoringMigrationTargetFile> targetFiles,
  required List<PolygonAuthoringMigrationIssue> issues,
}) {
  final entries = <String, PrefabPolygonMigrationEntry>{
    for (final entry in plan.prefabs) entry.prefabKey: entry,
  };
  try {
    final document = PrefabV3TargetDocument(
      slices: prefabDocument.slices,
      prefabs: prefabDocument.prefabs.map(
        (prefab) => PrefabV3TargetDef.fromLegacy(
          legacy: prefab,
          collisionShapes: entries[prefab.prefabKey]!.collisionShapes,
        ),
      ),
    );
    final source = PolygonAuthoringTargetCodec.encodePrefabV3(document);
    final roundTrip = PolygonAuthoringTargetCodec.encodePrefabV3(
      PolygonAuthoringTargetCodec.decodePrefabV3(
        source,
        sourcePath: prefabSourcePath,
      ),
    );
    if (roundTrip != source) {
      throw StateError('Strict target round-trip changed canonical bytes.');
    }
    targetFiles.add(
      PolygonAuthoringMigrationTargetFile(
        sourceKind: 'prefabs',
        ownerKey: 'prefab_defs',
        sourcePath: prefabSourcePath,
        targetSchemaVersion: polygonPrefabSchemaVersion,
        beforeSha256: prefabDocument.sourceSha256,
        afterSha256: _sha256(source),
        canonicalContents: source,
      ),
    );
  } on Object catch (error) {
    issues.add(
      PolygonAuthoringMigrationIssue(
        sourcePath: prefabSourcePath,
        ownerKey: 'prefab_defs',
        elementIndex: 0,
        code: 'migration_prefab_target_invalid',
        message: 'Strict prefab-v3 target validation failed: $error',
      ),
    );
  }
}

void _buildChunkTargets({
  required List<_LegacyChunkInput> chunkInputs,
  required PolygonAuthoringMigrationPlan plan,
  required List<PolygonAuthoringMigrationTargetFile> targetFiles,
  required List<PolygonAuthoringMigrationIssue> issues,
}) {
  final entries = <String, ChunkGroundPolygonMigrationEntry>{
    for (final entry in plan.chunks) entry.chunkKey: entry,
  };
  for (final input in chunkInputs) {
    final chunk = input.document.chunk;
    try {
      final source = PolygonAuthoringTargetCodec.encodeChunkV2(
        ChunkV2TargetDocument.fromLegacy(
          legacy: chunk,
          collisionShapes: entries[chunk.chunkKey]!.terrainShapes,
        ),
      );
      final roundTrip = PolygonAuthoringTargetCodec.encodeChunkV2(
        PolygonAuthoringTargetCodec.decodeChunkV2(
          source,
          sourcePath: input.sourcePath,
        ),
      );
      if (roundTrip != source) {
        throw StateError('Strict target round-trip changed canonical bytes.');
      }
      targetFiles.add(
        PolygonAuthoringMigrationTargetFile(
          sourceKind: 'chunk',
          ownerKey: chunk.chunkKey,
          sourcePath: input.sourcePath,
          targetSchemaVersion: polygonChunkSchemaVersion,
          beforeSha256: input.document.sourceSha256,
          afterSha256: _sha256(source),
          canonicalContents: source,
        ),
      );
    } on Object catch (error) {
      issues.add(
        PolygonAuthoringMigrationIssue(
          sourcePath: input.sourcePath,
          ownerKey: chunk.chunkKey,
          elementIndex: 0,
          code: 'migration_chunk_target_invalid',
          message: 'Strict chunk-v2 target validation failed: $error',
        ),
      );
    }
  }
}

int _readSchemaVersion(
  String raw, {
  required String sourcePath,
  required String invalidCode,
}) {
  try {
    final root = StrictMigrationJson.decodeRoot(raw, sourcePath: sourcePath);
    return StrictMigrationJson.integer(
      root['schemaVersion'],
      sourcePath: '$sourcePath.schemaVersion',
    );
  } on FormatException catch (error) {
    throw PolygonAuthoringMigrationCheckException(
      code: invalidCode,
      sourcePath: sourcePath,
      message: error.message,
    );
  }
}

void _requireCanonicalCurrentSource({
  required String raw,
  required String canonical,
  required String sourcePath,
}) {
  if (raw == canonical) return;
  throw PolygonAuthoringMigrationCheckException(
    code: 'migration_current_source_noncanonical',
    sourcePath: sourcePath,
    message:
        'Current-schema source must already match its canonical byte '
        'representation.',
  );
}

void _appendCurrentGeometryIssues({
  required Iterable<TerrainSourceShapeDef> shapes,
  required String sourcePath,
  required String ownerKey,
  required int chunkIndex,
  required List<PolygonAuthoringMigrationIssue> issues,
}) {
  var shapeIndex = 0;
  for (final shape in shapes) {
    final review = TerrainSourceCoreAdapter.review(
      shape: shape,
      sourcePath: '$sourcePath:$ownerKey:${shape.shapeId}',
      chunkIndex: chunkIndex,
      chunkKey: ownerKey,
      requireCanonical: true,
    );
    for (final diagnostic in review.diagnostics) {
      if (!review.hasBlockingDiagnostics && review.isCanonical) continue;
      issues.add(
        PolygonAuthoringMigrationIssue(
          sourcePath: sourcePath,
          ownerKey: ownerKey,
          elementIndex: diagnostic.elementIndex,
          code: 'migration_current_geometry_${diagnostic.code}',
          message:
              'Shape ${shape.shapeId} at index $shapeIndex: '
              '${diagnostic.message}',
        ),
      );
    }
    shapeIndex++;
  }
}

String _readRequiredSource(EditorWorkspace workspace, String sourcePath) {
  final file = File(workspace.resolve(p.normalize(sourcePath)));
  if (!file.existsSync()) {
    throw PolygonAuthoringMigrationCheckException(
      code: 'migration_source_missing',
      sourcePath: sourcePath,
      message: 'Required migration source does not exist.',
    );
  }
  try {
    return file.readAsStringSync();
  } on Object catch (error) {
    throw PolygonAuthoringMigrationCheckException(
      code: 'migration_source_read_failed',
      sourcePath: sourcePath,
      message: 'Unable to read migration source: $error',
    );
  }
}

String _workspacePath(EditorWorkspace workspace, String absolutePath) => p
    .relative(p.normalize(absolutePath), from: workspace.rootPath)
    .replaceAll(r'\', '/');

String _sha256(String source) => WorkspaceFileIo.sha256Digest(source);

int _compareRevisionRecords(
  PolygonAuthoringMigrationRevisionRecord left,
  PolygonAuthoringMigrationRevisionRecord right,
) {
  final kindOrder = left.ownerKind.compareTo(right.ownerKind);
  return kindOrder != 0 ? kindOrder : left.ownerKey.compareTo(right.ownerKey);
}

final class _LegacyChunkInput {
  const _LegacyChunkInput({required this.sourcePath, required this.document});

  final String sourcePath;
  final LegacyChunkMigrationDocument document;
}

final class _RawChunkInput {
  const _RawChunkInput({
    required this.sourcePath,
    required this.raw,
    required this.schemaVersion,
  });

  final String sourcePath;
  final String raw;
  final int schemaVersion;
}

final class _CurrentChunkInput {
  const _CurrentChunkInput({
    required this.sourcePath,
    required this.raw,
    required this.document,
  });

  final String sourcePath;
  final String raw;
  final ChunkV2TargetDocument document;
}
