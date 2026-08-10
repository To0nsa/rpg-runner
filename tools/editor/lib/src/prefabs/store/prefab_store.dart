import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../workspace/workspace_write_transaction.dart';
import '../../workspace/repository_authoring_paths.dart';
import 'prefab_tile_file_codec.dart';
import 'prefab_v3_file_codec.dart';
import '../models/models.dart';

/// Strict prefab-v3 plus retained tile-v2 load payload.
class PrefabV3LoadResult {
  const PrefabV3LoadResult({required this.prefabData, required this.tileData});

  final PrefabV3FileData prefabData;
  final PrefabTileFileData tileData;
}

/// Schema family selected from the authoritative prefab source version.
enum PrefabSourceGeneration { missing, legacyV2, currentV3 }

/// One canonical fixed-path replacement in a prefab-v3 save plan.
final class PrefabV3SaveFile {
  const PrefabV3SaveFile({
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
final class PrefabV3SavePlan {
  PrefabV3SavePlan(Iterable<PrefabV3SaveFile> files)
    : files = List<PrefabV3SaveFile>.unmodifiable(
        List<PrefabV3SaveFile>.of(files)..sort(
          (left, right) => left.relativePath.compareTo(right.relativePath),
        ),
      );

  final List<PrefabV3SaveFile> files;

  bool get hasChanges => files.any((file) => file.hasChanges);
}

/// Stable failure from the explicit prefab-v3 write proof.
final class PrefabV3SaveException implements Exception {
  const PrefabV3SaveException({
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
      RepositoryAuthoringPaths.prefabDefinitions;

  /// Workspace-relative path to tile slice/platform module definitions.
  static const String tileDefsPath = 'assets/authoring/level/tile_defs.json';

  const PrefabStore();

  /// Selects the normal prefab document family without decoding either model.
  ///
  /// Missing source is distinct from legacy source so the normal plugin can
  /// report an accurate blocked initialization state. Existing source must
  /// declare an exact supported integer version; malformed or future versions
  /// fail instead of falling back to rectangle authoring.
  PrefabSourceGeneration detectSourceGeneration(String workspaceRootPath) {
    final prefabFile = File(
      p.normalize(p.join(workspaceRootPath, prefabDefsPath)),
    );
    if (!prefabFile.existsSync()) {
      return PrefabSourceGeneration.missing;
    }
    final parsed = _parseJsonMap(
      prefabFile.readAsStringSync(),
      sourcePath: prefabFile.path,
    );
    final schemaVersion = parsed['schemaVersion'];
    if (schemaVersion is! int) {
      throw FormatException(
        'Malformed schemaVersion in ${prefabFile.path}: expected an integer.',
      );
    }
    return switch (schemaVersion) {
      prefabSchemaVersionV1 ||
      prefabSchemaVersionV2 => PrefabSourceGeneration.legacyV2,
      prefabSchemaVersionV3 => PrefabSourceGeneration.currentV3,
      _ => throw FormatException(
        'Unsupported prefab schemaVersion $schemaVersion in '
        '${prefabFile.path}.',
      ),
    };
  }

  /// Strictly loads prefab-v3 and retained tile-v2 source.
  ///
  /// This remains the explicit loader used by cross-route owner navigation;
  /// normal loading also selects it when [detectSourceGeneration] reports v3.
  /// Repository write authority is unaffected by selection.
  Future<PrefabV3LoadResult> loadV3(String workspaceRootPath) async {
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
    return PrefabV3LoadResult(
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
  /// Baselines must be strict prefab-v3/tile-v2 source loaded by the current
  /// path. This method canonicalizes only the proposed outputs; it never writes.
  PrefabV3SavePlan buildV3SavePlan({
    required PrefabV3FileData prefabData,
    required PrefabTileFileData tileData,
    required String? prefabBaselineContents,
    required String? tileBaselineContents,
  }) {
    if (prefabBaselineContents == null || tileBaselineContents == null) {
      throw const PrefabV3SaveException(
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
      throw PrefabV3SaveException(
        code: 'prefab_v3_save_baseline_invalid',
        message:
            'Prefab-v3 save baselines must be strict current-schema source.',
        cause: error,
      );
    }
    return PrefabV3SavePlan(<PrefabV3SaveFile>[
      PrefabV3SaveFile(
        relativePath: prefabDefsPath,
        beforeContents: prefabBaselineContents,
        afterContents: PrefabV3FileCodec.encode(prefabData),
      ),
      PrefabV3SaveFile(
        relativePath: tileDefsPath,
        beforeContents: tileBaselineContents,
        afterContents: PrefabTileFileCodec.encode(tileData),
      ),
    ]);
  }

  /// Applies one reviewed current-schema plan as a rollback-safe transaction.
  ///
  /// Normal plugin export calls this only for an already-current v3/tile-v2
  /// document; it cannot migrate legacy source. Both baselines are rechecked
  /// after files are staged and installed bytes are strictly decoded before
  /// backups are removed.
  void applyV3SavePlan(
    String workspaceRootPath, {
    required PrefabV3SavePlan plan,
  }) {
    _requireV3PlanShape(plan);
    try {
      _requireV3PlanFresh(workspaceRootPath, plan);
    } on _PrefabV3SaveAbort catch (error) {
      throw PrefabV3SaveException(code: error.code, message: error.message);
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
        PrefabV3SaveException(
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

  /// Parses and validates top-level JSON object shape.
  Map<String, Object?> _parseJsonMap(String raw, {required String sourcePath}) {
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (error) {
      throw FormatException('Malformed JSON in $sourcePath: ${error.message}');
    }
    if (decoded is! Map<String, Object?>) {
      throw FormatException(
        'Malformed JSON in $sourcePath: top-level JSON value must be an object.',
      );
    }
    return decoded;
  }
}

void _requireV3PlanShape(PrefabV3SavePlan plan) {
  final byPath = <String, PrefabV3SaveFile>{
    for (final file in plan.files) file.relativePath: file,
  };
  const requiredPaths = <String>{
    PrefabStore.prefabDefsPath,
    PrefabStore.tileDefsPath,
  };
  if (plan.files.length != requiredPaths.length ||
      !byPath.keys.toSet().containsAll(requiredPaths)) {
    throw const PrefabV3SaveException(
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
    throw PrefabV3SaveException(
      code: 'prefab_v3_save_plan_output_invalid',
      message: 'Prefab-v3 save plan outputs must decode as current schemas.',
      cause: error,
    );
  }
}

void _requireV3PlanFresh(String workspaceRootPath, PrefabV3SavePlan plan) {
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

void _requireV3PlanInstalled(String workspaceRootPath, PrefabV3SavePlan plan) {
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
