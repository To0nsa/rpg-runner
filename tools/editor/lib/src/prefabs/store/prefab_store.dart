import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../workspace/workspace_write_transaction.dart';
import 'prefab_determinism.dart';
import 'prefab_tile_file_codec.dart';
import 'prefab_v3_file_codec.dart';
import '../models/models.dart';
import '../models/shared/model_json_utils.dart';

/// Result of loading prefab authoring files, including migration notices.
class PrefabLoadResult {
  const PrefabLoadResult({
    required this.data,
    this.migrationHints = const <String>[],
  });

  final PrefabData data;
  final List<String> migrationHints;
}

/// Canonically serialized prefab and tile authoring file contents.
class PrefabSerializedFiles {
  const PrefabSerializedFiles({
    required this.prefabContents,
    required this.tileContents,
  });

  final String prefabContents;
  final String tileContents;
}

/// Strict read-only prefab-v3 plus retained tile-v2 staging payload.
class PrefabV3StagingLoadResult {
  const PrefabV3StagingLoadResult({
    required this.prefabData,
    required this.tileData,
  });

  final PrefabV3FileData prefabData;
  final PrefabTileFileData tileData;
}

/// One canonical fixed-path replacement in a prefab-v3 staging save plan.
final class PrefabV3StagingSaveFile {
  const PrefabV3StagingSaveFile({
    required this.relativePath,
    required this.beforeContents,
    required this.afterContents,
  });

  final String relativePath;
  final String beforeContents;
  final String afterContents;

  bool get hasChanges => beforeContents != afterContents;
}

/// Immutable paired prefab-v3/tile-v2 save plan.
///
/// Both load-time baselines remain present even when only one file changes so
/// the apply boundary can reject drift across the logical source pair.
final class PrefabV3StagingSavePlan {
  PrefabV3StagingSavePlan(Iterable<PrefabV3StagingSaveFile> files)
    : files = List<PrefabV3StagingSaveFile>.unmodifiable(
        List<PrefabV3StagingSaveFile>.of(files)..sort(
          (left, right) => left.relativePath.compareTo(right.relativePath),
        ),
      );

  final List<PrefabV3StagingSaveFile> files;

  bool get hasChanges => files.any((file) => file.hasChanges);
}

/// Stable failure from the explicit prefab-v3 staging write proof.
final class PrefabV3StagingSaveException implements Exception {
  const PrefabV3StagingSaveException({
    required this.code,
    required this.message,
    this.cause,
    this.rollbackComplete,
    this.outputsCommitted = false,
  });

  final String code;
  final String message;
  final Object? cause;
  final bool? rollbackComplete;
  final bool outputsCommitted;

  @override
  String toString() => '$code: $message';
}

/// Repository file adapter for prefab authoring data.
///
/// Owns parsing, schema migration, canonical ordering, and paired writes for:
/// - `assets/authoring/level/prefab_defs.json`
/// - `assets/authoring/level/tile_defs.json`
class PrefabStore {
  /// Workspace-relative path to prefab slice/prefab definitions.
  static const String prefabDefsPath =
      'assets/authoring/level/prefab_defs.json';

  /// Workspace-relative path to tile slice/platform module definitions.
  static const String tileDefsPath = 'assets/authoring/level/tile_defs.json';

  const PrefabStore();

  /// Strictly loads prefab-v3 and retained tile-v2 source without enabling the
  /// normal loader or any repository write path.
  Future<PrefabV3StagingLoadResult> loadV3Staging(
    String workspaceRootPath,
  ) async {
    final prefabFile = File(
      p.normalize(p.join(workspaceRootPath, prefabDefsPath)),
    );
    final tileFile = File(p.normalize(p.join(workspaceRootPath, tileDefsPath)));
    if (!prefabFile.existsSync()) {
      throw StateError(
        'prefab_v3_source_missing: expected ${prefabFile.path}.',
      );
    }
    if (!tileFile.existsSync()) {
      throw StateError(
        'prefab_tile_source_missing: expected ${tileFile.path}.',
      );
    }
    return PrefabV3StagingLoadResult(
      prefabData: PrefabV3FileCodec.decode(
        prefabFile.readAsStringSync(),
        sourcePath: prefabFile.path,
      ),
      tileData: PrefabTileFileCodec.decode(
        tileFile.readAsStringSync(),
        sourcePath: tileFile.path,
      ),
    );
  }

  /// Builds the exact paired current-schema save plan without filesystem I/O.
  ///
  /// Baselines must be strict prefab-v3/tile-v2 source loaded by the staging
  /// path. This method canonicalizes only the proposed outputs; it never writes.
  PrefabV3StagingSavePlan buildV3StagingSavePlan({
    required PrefabV3FileData prefabData,
    required PrefabTileFileData tileData,
    required String? prefabBaselineContents,
    required String? tileBaselineContents,
  }) {
    if (prefabBaselineContents == null || tileBaselineContents == null) {
      throw const PrefabV3StagingSaveException(
        code: 'prefab_v3_save_baseline_missing',
        message:
            'Prefab-v3 save planning requires both load-time source baselines.',
      );
    }
    try {
      PrefabV3FileCodec.decode(
        prefabBaselineContents,
        sourcePath: prefabDefsPath,
      );
      PrefabTileFileCodec.decode(
        tileBaselineContents,
        sourcePath: tileDefsPath,
      );
    } on Object catch (error) {
      throw PrefabV3StagingSaveException(
        code: 'prefab_v3_save_baseline_invalid',
        message:
            'Prefab-v3 save baselines must be strict current-schema source.',
        cause: error,
      );
    }
    return PrefabV3StagingSavePlan(<PrefabV3StagingSaveFile>[
      PrefabV3StagingSaveFile(
        relativePath: prefabDefsPath,
        beforeContents: prefabBaselineContents,
        afterContents: PrefabV3FileCodec.encode(prefabData),
      ),
      PrefabV3StagingSaveFile(
        relativePath: tileDefsPath,
        beforeContents: tileBaselineContents,
        afterContents: PrefabTileFileCodec.encode(tileData),
      ),
    ]);
  }

  /// Applies one reviewed current-schema plan as a rollback-safe transaction.
  ///
  /// The checked-in editor plugin never calls this method while the Phase 4
  /// write lock is active. It exists to prove exact save/reload behavior in
  /// isolated all-current workspaces. Both baselines are rechecked after files
  /// are staged and installed bytes are strictly decoded before backups are
  /// removed.
  void applyV3StagingSavePlan(
    String workspaceRootPath, {
    required PrefabV3StagingSavePlan plan,
  }) {
    _requireV3PlanShape(plan);
    try {
      _requireV3PlanFresh(workspaceRootPath, plan);
    } on _PrefabV3SaveAbort catch (error) {
      throw PrefabV3StagingSaveException(
        code: error.code,
        message: error.message,
      );
    }
    if (!plan.hasChanges) return;

    final transaction = WorkspaceWriteTransaction(
      plan.files
          .where((file) => file.hasChanges)
          .map(
            (file) => WorkspaceWriteArtifact(
              path: p.normalize(p.join(workspaceRootPath, file.relativePath)),
              contents: file.afterContents,
            ),
          ),
    );
    try {
      transaction.apply(
        beforeReplace: () => _requireV3PlanFresh(workspaceRootPath, plan),
        verifyReplacements: () =>
            _requireV3PlanInstalled(workspaceRootPath, plan),
      );
    } on WorkspaceWriteTransactionException catch (error, stackTrace) {
      final abort = error.cause is _PrefabV3SaveAbort
          ? error.cause as _PrefabV3SaveAbort
          : null;
      Error.throwWithStackTrace(
        PrefabV3StagingSaveException(
          code: abort?.code ?? 'prefab_v3_save_transaction_failed',
          message:
              abort?.message ??
              'The prefab-v3 source transaction failed and attempted recovery.',
          cause: error.cause,
          rollbackComplete: error.rollbackComplete,
          outputsCommitted: error.outputsCommitted,
        ),
        stackTrace,
      );
    }
  }

  /// Loads and normalizes prefab authoring data.
  ///
  /// Use [loadWithReport] when migration hints need to be surfaced to the UI.
  Future<PrefabData> load(String workspaceRootPath) async {
    final result = await loadWithReport(workspaceRootPath);
    return result.data;
  }

  /// Loads prefab/tile authoring files and returns migration diagnostics.
  Future<PrefabLoadResult> loadWithReport(String workspaceRootPath) async {
    final prefabFile = File(
      p.normalize(p.join(workspaceRootPath, prefabDefsPath)),
    );
    final tileFile = File(p.normalize(p.join(workspaceRootPath, tileDefsPath)));

    final prefabSlices = <AtlasSliceDef>[];
    final prefabs = <PrefabDef>[];
    final tileSlices = <AtlasSliceDef>[];
    final platformModules = <TileModuleDef>[];
    var prefabSchemaVersion = currentPrefabSchemaVersion;
    final migrationStats = _PrefabMigrationStats();

    if (prefabFile.existsSync()) {
      final parsed = _parseJsonMap(
        prefabFile.readAsStringSync(),
        sourcePath: prefabFile.path,
      );
      prefabSchemaVersion = _intOrDefault(
        parsed['schemaVersion'],
        fallback: currentPrefabSchemaVersion,
      );

      final rawPrefabSlices = parsed['slices'];
      if (rawPrefabSlices is List<Object?>) {
        prefabSlices.addAll(_parseSlices(rawPrefabSlices));
      }

      final rawPrefabs = parsed['prefabs'];
      if (rawPrefabs is List<Object?>) {
        prefabs.addAll(_parsePrefabs(rawPrefabs));
      }
    }

    if (tileFile.existsSync()) {
      final parsed = _parseJsonMap(
        tileFile.readAsStringSync(),
        sourcePath: tileFile.path,
      );
      final rawTileSlices = parsed['tileSlices'];
      if (rawTileSlices is List<Object?>) {
        tileSlices.addAll(_parseSlices(rawTileSlices));
      }

      final rawModules = parsed['platformModules'];
      if (rawModules is List<Object?>) {
        for (final value in rawModules) {
          final moduleJson = PrefabModelJson.asObjectMap(value);
          if (moduleJson == null) {
            continue;
          }
          platformModules.add(TileModuleDef.fromJson(moduleJson));
        }
      }
    }

    final isLegacyV1 = prefabSchemaVersion < currentPrefabSchemaVersion;
    final normalizedData = PrefabData(
      schemaVersion: _canonicalSchemaVersion(prefabSchemaVersion),
      prefabSlices: _sortedSlices(prefabSlices),
      tileSlices: _sortedSlices(tileSlices),
      prefabs: _sortedPrefabs(
        prefabs,
        migrateLegacyDefaults: isLegacyV1,
        migrationStats: migrationStats,
      ),
      platformModules: _sortedModules(platformModules),
    );
    final migrationHints = <String>[];
    if (isLegacyV1) {
      migrationHints.add(
        'Legacy prefab schema detected (v$prefabSchemaVersion); '
        'migrated in memory to v$currentPrefabSchemaVersion.',
      );
      migrationHints.add(
        'Migration summary: prefabs=${migrationStats.migratedPrefabs}, '
        'allocatedKeys=${migrationStats.allocatedPrefabKeys}, '
        'defaultedStatus=${migrationStats.defaultedStatuses}, '
        'defaultedKind=${migrationStats.defaultedKinds}, '
        'promotedVisualSources=${migrationStats.promotedVisualSources}, '
        'defaultedRevision=${migrationStats.defaultedRevisions}.',
      );
    }
    return PrefabLoadResult(
      data: normalizedData,
      migrationHints: migrationHints,
    );
  }

  /// Persists [data] to prefab/tile files using canonical serialization.
  ///
  /// Writes are staged and committed atomically as a pair so the two files do
  /// not drift on partial failures.
  Future<void> save(
    String workspaceRootPath, {
    required PrefabData data,
  }) async {
    final prefabFile = File(
      p.normalize(p.join(workspaceRootPath, prefabDefsPath)),
    );
    final tileFile = File(p.normalize(p.join(workspaceRootPath, tileDefsPath)));

    if (!prefabFile.parent.existsSync()) {
      prefabFile.parent.createSync(recursive: true);
    }
    if (!tileFile.parent.existsSync()) {
      tileFile.parent.createSync(recursive: true);
    }

    final serialized = serializeCanonicalFiles(data);
    _writePrefabAndTileAtomically(
      prefabFile: prefabFile,
      prefabContents: serialized.prefabContents,
      tileFile: tileFile,
      tileContents: serialized.tileContents,
    );
  }

  /// Produces canonical JSON text for prefab and tile authoring files.
  ///
  /// Deterministic ordering from this method is used for both file output and
  /// semantic equality checks in the domain plugin.
  PrefabSerializedFiles serializeCanonicalFiles(PrefabData data) {
    final sortedPrefabSlices = _sortedSlices(data.prefabSlices);
    final sortedTileSlices = _sortedSlices(data.tileSlices);
    final sortedPrefabs = _sortedPrefabs(
      data.prefabs,
      migrateLegacyDefaults: false,
    );
    final sortedModules = _sortedModules(data.platformModules);
    final schemaVersion = _canonicalSchemaVersion(data.schemaVersion);

    final prefabJson = <String, Object?>{
      'schemaVersion': schemaVersion,
      'slices': sortedPrefabSlices
          .map((slice) => slice.toJson())
          .toList(growable: false),
      'prefabs': sortedPrefabs
          .map((prefab) => prefab.toJson())
          .toList(growable: false),
    };
    final tileJson = <String, Object?>{
      'schemaVersion': schemaVersion,
      'tileSlices': sortedTileSlices
          .map((slice) => slice.toJson())
          .toList(growable: false),
      'platformModules': sortedModules
          .map((module) => module.toJson())
          .toList(growable: false),
    };

    const encoder = JsonEncoder.withIndent('  ');
    return PrefabSerializedFiles(
      prefabContents: '${encoder.convert(prefabJson)}\n',
      tileContents: '${encoder.convert(tileJson)}\n',
    );
  }

  List<PrefabDef> _parsePrefabs(List<Object?> raw) {
    final prefabs = <PrefabDef>[];
    for (final value in raw) {
      final prefabJson = PrefabModelJson.asObjectMap(value);
      if (prefabJson == null) {
        continue;
      }
      prefabs.add(PrefabDef.fromJson(prefabJson));
    }
    return prefabs;
  }

  List<AtlasSliceDef> _parseSlices(List<Object?> raw) {
    final slices = <AtlasSliceDef>[];
    for (final value in raw) {
      final sliceJson = PrefabModelJson.asObjectMap(value);
      if (sliceJson == null) {
        continue;
      }
      slices.add(AtlasSliceDef.fromJson(sliceJson));
    }
    return slices;
  }

  /// Parses and validates top-level JSON object shape.
  Map<String, Object?> _parseJsonMap(String raw, {required String sourcePath}) {
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (error) {
      throw FormatException('Malformed JSON in $sourcePath: ${error.message}');
    }
    final mapped = PrefabModelJson.asObjectMap(decoded);
    if (mapped == null) {
      throw FormatException(
        'Malformed JSON in $sourcePath: top-level JSON value must be an object.',
      );
    }
    return mapped;
  }

  int _intOrDefault(Object? raw, {required int fallback}) {
    if (raw is num) {
      return raw.toInt();
    }
    return fallback;
  }

  /// Keeps stored schema at least at the currently writable version.
  int _canonicalSchemaVersion(int rawSchemaVersion) {
    if (rawSchemaVersion < currentPrefabSchemaVersion) {
      return currentPrefabSchemaVersion;
    }
    return rawSchemaVersion;
  }

  /// Canonical slice ordering for deterministic serialization.
  List<AtlasSliceDef> _sortedSlices(List<AtlasSliceDef> slices) {
    return PrefabDeterminism.sortSlicesByIdThenSourceRect(
      slices.map(
        (slice) =>
            slice.copyWith(tags: PrefabDeterminism.normalizeTags(slice.tags)),
      ),
    );
  }

  /// Canonical prefab normalization + optional legacy migration defaults.
  List<PrefabDef> _sortedPrefabs(
    List<PrefabDef> prefabs, {
    required bool migrateLegacyDefaults,
    _PrefabMigrationStats? migrationStats,
  }) {
    final usedPrefabKeys = <String>{};
    final normalized = <PrefabDef>[];

    for (final prefab in prefabs) {
      var next = prefab;

      if (migrateLegacyDefaults) {
        migrationStats?.migratedPrefabs += 1;
        final existingPrefabKey = next.prefabKey.trim();
        final nextPrefabKey = existingPrefabKey.isNotEmpty
            ? existingPrefabKey
            : PrefabDeterminism.allocatePrefabKey(
                id: next.id,
                usedPrefabKeys: usedPrefabKeys,
              );
        if (existingPrefabKey.isEmpty) {
          migrationStats?.allocatedPrefabKeys += 1;
        }
        usedPrefabKeys.add(nextPrefabKey);

        final nextStatus = next.status == PrefabStatus.unknown
            ? PrefabStatus.active
            : next.status;
        if (next.status == PrefabStatus.unknown) {
          migrationStats?.defaultedStatuses += 1;
        }
        final nextKind = next.kind == PrefabKind.unknown
            ? PrefabKind.obstacle
            : next.kind;
        if (next.kind == PrefabKind.unknown) {
          migrationStats?.defaultedKinds += 1;
        }
        final nextVisualSource = _migrateLegacyVisualSource(next.visualSource);
        if (next.visualSource.type == PrefabVisualSourceType.unknown &&
            nextVisualSource.type != PrefabVisualSourceType.unknown) {
          migrationStats?.promotedVisualSources += 1;
        }
        final nextRevision = next.revision <= 0 ? 1 : next.revision;
        if (next.revision <= 0) {
          migrationStats?.defaultedRevisions += 1;
        }

        next = next.copyWith(
          prefabKey: nextPrefabKey,
          revision: nextRevision,
          status: nextStatus,
          kind: nextKind,
          visualSource: nextVisualSource,
        );
      }

      next = next.copyWith(
        tags: PrefabDeterminism.normalizeTags(next.tags),
        colliders: PrefabDeterminism.sortColliders(next.colliders),
      );
      normalized.add(next);
    }

    return PrefabDeterminism.sortPrefabsByIdThenKey(normalized);
  }

  /// Promotes legacy unknown visual source data where a legacy slice id exists.
  PrefabVisualSource _migrateLegacyVisualSource(PrefabVisualSource source) {
    if (source.type != PrefabVisualSourceType.unknown) {
      return source;
    }
    if (source.sliceId.isNotEmpty) {
      return PrefabVisualSource.atlasSlice(source.sliceId);
    }
    return source;
  }

  /// Canonical module normalization and ordering.
  List<TileModuleDef> _sortedModules(List<TileModuleDef> modules) {
    final normalized = modules
        .map((module) {
          final nextRevision = module.revision <= 0 ? 1 : module.revision;
          final nextStatus = PrefabDeterminism.normalizeModuleStatus(
            module.status,
          );
          final sortedCells = PrefabDeterminism.sortModuleCellsByGridThenSlice(
            module.cells,
          );
          return module.copyWith(
            revision: nextRevision,
            status: nextStatus,
            cells: sortedCells,
          );
        })
        .toList(growable: false);

    return PrefabDeterminism.sortModulesByStatusIdRevision(normalized);
  }

  /// Writes prefab and tile files as one logical transaction.
  ///
  /// Uses staged temp files and per-file backups to guarantee rollback when the
  /// second rename or cleanup fails.
  void _writePrefabAndTileAtomically({
    required File prefabFile,
    required String prefabContents,
    required File tileFile,
    required String tileContents,
  }) {
    final stagedId = DateTime.now().microsecondsSinceEpoch.toString();
    final prefabTemp = _stagedSiblingFile(
      target: prefabFile,
      stagedId: stagedId,
      suffix: 'tmp',
    );
    final tileTemp = _stagedSiblingFile(
      target: tileFile,
      stagedId: stagedId,
      suffix: 'tmp',
    );
    final prefabBackup = _stagedSiblingFile(
      target: prefabFile,
      stagedId: stagedId,
      suffix: 'bak',
    );
    final tileBackup = _stagedSiblingFile(
      target: tileFile,
      stagedId: stagedId,
      suffix: 'bak',
    );

    final prefabHadOriginal = prefabFile.existsSync();
    final tileHadOriginal = tileFile.existsSync();
    var prefabCommitted = false;
    var tileCommitted = false;

    prefabTemp.writeAsStringSync(prefabContents, flush: true);
    tileTemp.writeAsStringSync(tileContents, flush: true);

    try {
      if (prefabHadOriginal) {
        prefabFile.renameSync(prefabBackup.path);
      }
      if (tileHadOriginal) {
        tileFile.renameSync(tileBackup.path);
      }

      prefabTemp.renameSync(prefabFile.path);
      prefabCommitted = true;
      tileTemp.renameSync(tileFile.path);
      tileCommitted = true;

      if (prefabBackup.existsSync()) {
        prefabBackup.deleteSync();
      }
      if (tileBackup.existsSync()) {
        tileBackup.deleteSync();
      }
    } catch (_) {
      if (prefabCommitted && prefabBackup.existsSync()) {
        if (prefabFile.existsSync()) {
          prefabFile.deleteSync();
        }
        prefabBackup.renameSync(prefabFile.path);
      } else if (prefabCommitted && !prefabBackup.existsSync()) {
        if (prefabFile.existsSync()) {
          prefabFile.deleteSync();
        }
      } else if (!prefabCommitted &&
          !prefabFile.existsSync() &&
          prefabBackup.existsSync()) {
        prefabBackup.renameSync(prefabFile.path);
      }

      if (tileCommitted && tileBackup.existsSync()) {
        if (tileFile.existsSync()) {
          tileFile.deleteSync();
        }
        tileBackup.renameSync(tileFile.path);
      } else if (tileCommitted && !tileBackup.existsSync()) {
        if (tileFile.existsSync()) {
          tileFile.deleteSync();
        }
      } else if (!tileCommitted &&
          !tileFile.existsSync() &&
          tileBackup.existsSync()) {
        tileBackup.renameSync(tileFile.path);
      }
      rethrow;
    } finally {
      if (prefabTemp.existsSync()) {
        prefabTemp.deleteSync();
      }
      if (tileTemp.existsSync()) {
        tileTemp.deleteSync();
      }
      if (prefabBackup.existsSync() && prefabFile.existsSync()) {
        prefabBackup.deleteSync();
      }
      if (tileBackup.existsSync() && tileFile.existsSync()) {
        tileBackup.deleteSync();
      }
    }
  }

  /// Builds a temp/backup sibling path for [target].
  File _stagedSiblingFile({
    required File target,
    required String stagedId,
    required String suffix,
  }) {
    final baseName = p.basename(target.path);
    final stagedName = '.$baseName.$stagedId.$suffix';
    return File(p.join(target.parent.path, stagedName));
  }
}

void _requireV3PlanShape(PrefabV3StagingSavePlan plan) {
  final byPath = <String, PrefabV3StagingSaveFile>{
    for (final file in plan.files) file.relativePath: file,
  };
  const requiredPaths = <String>{
    PrefabStore.prefabDefsPath,
    PrefabStore.tileDefsPath,
  };
  if (plan.files.length != requiredPaths.length ||
      !byPath.keys.toSet().containsAll(requiredPaths)) {
    throw const PrefabV3StagingSaveException(
      code: 'prefab_v3_save_plan_invalid',
      message:
          'Prefab-v3 save plan must contain exactly the fixed prefab/tile pair.',
    );
  }
  try {
    final prefabData = PrefabV3FileCodec.decode(
      byPath[PrefabStore.prefabDefsPath]!.afterContents,
      sourcePath: PrefabStore.prefabDefsPath,
    );
    final tileData = PrefabTileFileCodec.decode(
      byPath[PrefabStore.tileDefsPath]!.afterContents,
      sourcePath: PrefabStore.tileDefsPath,
    );
    if (PrefabV3FileCodec.encode(prefabData) !=
            byPath[PrefabStore.prefabDefsPath]!.afterContents ||
        PrefabTileFileCodec.encode(tileData) !=
            byPath[PrefabStore.tileDefsPath]!.afterContents) {
      throw const FormatException('Save-plan outputs are not canonical.');
    }
  } on Object catch (error) {
    throw PrefabV3StagingSaveException(
      code: 'prefab_v3_save_plan_output_invalid',
      message: 'Prefab-v3 save plan outputs must decode as current schemas.',
      cause: error,
    );
  }
}

void _requireV3PlanFresh(
  String workspaceRootPath,
  PrefabV3StagingSavePlan plan,
) {
  for (final planned in plan.files) {
    final file = File(
      p.normalize(p.join(workspaceRootPath, planned.relativePath)),
    );
    if (!file.existsSync() ||
        file.readAsStringSync() != planned.beforeContents) {
      throw _PrefabV3SaveAbort(
        code: 'prefab_v3_save_source_drift',
        message:
            'Source changed after load for ${planned.relativePath}; reload '
            'before applying the save plan.',
      );
    }
  }
}

void _requireV3PlanInstalled(
  String workspaceRootPath,
  PrefabV3StagingSavePlan plan,
) {
  final actualByPath = <String, String>{};
  for (final planned in plan.files) {
    final file = File(
      p.normalize(p.join(workspaceRootPath, planned.relativePath)),
    );
    if (!file.existsSync()) {
      throw _PrefabV3SaveAbort(
        code: 'prefab_v3_save_post_validation_failed',
        message: 'Installed source is missing ${planned.relativePath}.',
      );
    }
    final actual = file.readAsStringSync();
    if (actual != planned.afterContents) {
      throw _PrefabV3SaveAbort(
        code: 'prefab_v3_save_post_validation_failed',
        message: 'Installed bytes differ for ${planned.relativePath}.',
      );
    }
    actualByPath[planned.relativePath] = actual;
  }
  try {
    PrefabV3FileCodec.decode(
      actualByPath[PrefabStore.prefabDefsPath]!,
      sourcePath: PrefabStore.prefabDefsPath,
    );
    PrefabTileFileCodec.decode(
      actualByPath[PrefabStore.tileDefsPath]!,
      sourcePath: PrefabStore.tileDefsPath,
    );
  } on Object catch (error) {
    throw _PrefabV3SaveAbort(
      code: 'prefab_v3_save_post_validation_failed',
      message: 'Installed source did not pass strict current-schema decoding.',
      cause: error,
    );
  }
}

final class _PrefabV3SaveAbort implements Exception {
  const _PrefabV3SaveAbort({
    required this.code,
    required this.message,
    this.cause,
  });

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => '$code: $message';
}

/// Counters used to build user-facing migration summaries for legacy schema
/// loads.
class _PrefabMigrationStats {
  int migratedPrefabs = 0;
  int allocatedPrefabKeys = 0;
  int defaultedStatuses = 0;
  int defaultedKinds = 0;
  int promotedVisualSources = 0;
  int defaultedRevisions = 0;
}
