import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'prefab_determinism.dart';
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
