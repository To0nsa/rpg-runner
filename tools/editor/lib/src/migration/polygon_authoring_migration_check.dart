import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../chunks/chunk_store.dart';
import '../prefabs/store/prefab_store.dart';
import '../workspace/editor_workspace.dart';
import '../workspace/workspace_file_io.dart';
import 'polygon_authoring_legacy_codec.dart';
import 'polygon_authoring_migration_plan.dart';
import 'polygon_authoring_target_codec.dart';
import 'polygon_authoring_target_models.dart';

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

/// Complete read-only migration readiness check for one repository snapshot.
///
/// Construction reads legacy source, computes a blocker-aware polygon plan,
/// builds every target file in memory, and requires strict byte-stable target
/// round trips. It never writes authored source or changes normal stores.
final class PolygonAuthoringMigrationCheck {
  PolygonAuthoringMigrationCheck._({
    required this.plan,
    required Iterable<PolygonAuthoringMigrationTargetFile> targetFiles,
    required Iterable<PolygonAuthoringMigrationRevisionRecord> revisionRecords,
    required Iterable<PolygonAuthoringMigrationImpactRecord> impactRecords,
    required Iterable<PolygonAuthoringMigrationIssue> issues,
  }) : targetFiles = List<PolygonAuthoringMigrationTargetFile>.unmodifiable(
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
  static const int reportVersion = 1;

  final PolygonAuthoringMigrationPlan plan;
  final List<PolygonAuthoringMigrationTargetFile> targetFiles;
  final List<PolygonAuthoringMigrationRevisionRecord> revisionRecords;
  final List<PolygonAuthoringMigrationImpactRecord> impactRecords;

  /// Sorted union of plan and in-memory target-validation blockers.
  final List<PolygonAuthoringMigrationIssue> issues;

  bool get hasBlockers => issues.isNotEmpty;

  /// Loads the fixed prefab/chunk migration scope rooted at [workspaceRoot].
  ///
  /// File reads and strict parsing are the only side effects. A source read or
  /// schema failure throws [PolygonAuthoringMigrationCheckException] before a
  /// plan can be mistaken for complete.
  factory PolygonAuthoringMigrationCheck.fromRepository(String workspaceRoot) {
    final workspace = EditorWorkspace(rootPath: workspaceRoot);
    final prefabPath = PrefabStore.prefabDefsPath;
    final prefabRaw = _readRequiredSource(workspace, prefabPath);
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

    final chunkDirectory = Directory(
      workspace.resolve(ChunkStore.chunksDirectoryPath),
    );
    if (!chunkDirectory.existsSync()) {
      throw const PolygonAuthoringMigrationCheckException(
        code: 'migration_chunk_directory_missing',
        sourcePath: ChunkStore.chunksDirectoryPath,
        message: 'Legacy chunk source directory does not exist.',
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
        message: 'Legacy migration requires at least one chunk source file.',
      );
    }

    final chunkInputs = <_LegacyChunkInput>[];
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
      final LegacyChunkMigrationDocument document;
      try {
        document = PolygonAuthoringLegacyCodec.decodeChunkV1(
          raw,
          sourcePath: sourcePath,
        );
      } on FormatException catch (error) {
        throw PolygonAuthoringMigrationCheckException(
          code: 'migration_chunk_source_invalid',
          sourcePath: sourcePath,
          message: error.message,
        );
      }
      chunkInputs.add(
        _LegacyChunkInput(sourcePath: sourcePath, document: document),
      );
    }

    return _build(
      prefabSourcePath: prefabPath,
      prefabDocument: prefabDocument,
      chunkInputs: chunkInputs,
    );
  }

  static PolygonAuthoringMigrationCheck _build({
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
      plan: plan,
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
      ...plan.summary.toJson(),
      'sourceFileCount': plan.sourceFiles.length,
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
      'status': hasBlockers ? 'blocked' : 'ready',
      'summary': summary,
      'sourceFiles': plan.sourceFiles
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
      'prefabs': plan.prefabs
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'chunks': plan.chunks
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'blockers': issues.map((issue) => issue.toJson()).toList(growable: false),
    };
    return '${const JsonEncoder.withIndent('  ').convert(report)}\n';
  }
}

/// Stable source-loading failure that prevents a complete readiness plan.
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

String _readRequiredSource(EditorWorkspace workspace, String sourcePath) {
  final file = File(workspace.resolve(p.normalize(sourcePath)));
  if (!file.existsSync()) {
    throw PolygonAuthoringMigrationCheckException(
      code: 'migration_source_missing',
      sourcePath: sourcePath,
      message: 'Required legacy migration source does not exist.',
    );
  }
  try {
    return file.readAsStringSync();
  } on Object catch (error) {
    throw PolygonAuthoringMigrationCheckException(
      code: 'migration_source_read_failed',
      sourcePath: sourcePath,
      message: 'Unable to read legacy migration source: $error',
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
