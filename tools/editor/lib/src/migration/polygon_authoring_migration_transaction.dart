import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../workspace/editor_workspace.dart';
import '../workspace/workspace_file_io.dart';
import '../workspace/workspace_write_transaction.dart';
import 'polygon_authoring_migration_check.dart';

/// Outcome of applying one reviewed polygon-source migration snapshot.
enum PolygonAuthoringMigrationWriteStatus {
  committed('committed'),
  noOp('noOp');

  const PolygonAuthoringMigrationWriteStatus(this.jsonValue);

  final String jsonValue;
}

/// One deterministic before/after record in a migration write result.
final class PolygonAuthoringMigrationWrittenFile {
  const PolygonAuthoringMigrationWrittenFile({
    required this.sourcePath,
    required this.beforeSha256,
    required this.afterSha256,
    required this.changed,
  });

  final String sourcePath;
  final String beforeSha256;
  final String afterSha256;
  final bool changed;

  Map<String, Object> toJson() => <String, Object>{
    'sourcePath': sourcePath,
    'beforeSha256': beforeSha256,
    'afterSha256': afterSha256,
    'changed': changed,
  };
}

/// Deterministic machine-readable evidence for a completed or no-op write.
final class PolygonAuthoringMigrationWriteResult {
  PolygonAuthoringMigrationWriteResult({
    required this.status,
    required this.sourceStateBefore,
    required Iterable<PolygonAuthoringMigrationWrittenFile> files,
  }) : files = List<PolygonAuthoringMigrationWrittenFile>.unmodifiable(
         List<PolygonAuthoringMigrationWrittenFile>.of(files)
           ..sort((left, right) => left.sourcePath.compareTo(right.sourcePath)),
       );

  static const int reportVersion = 1;

  final PolygonAuthoringMigrationWriteStatus status;
  final PolygonAuthoringMigrationSourceState sourceStateBefore;
  final List<PolygonAuthoringMigrationWrittenFile> files;

  String toCanonicalJson() {
    final report = <String, Object>{
      'reportVersion': reportVersion,
      'mode': 'write',
      'status': status.jsonValue,
      'sourceStateBefore': sourceStateBefore.jsonValue,
      'sourceStateAfter':
          PolygonAuthoringMigrationSourceState.current.jsonValue,
      'summary': <String, Object>{
        'sourceFileCount': files.length,
        'changedFileCount': files.where((file) => file.changed).length,
      },
      'files': files.map((file) => file.toJson()).toList(growable: false),
    };
    return '${const JsonEncoder.withIndent('  ').convert(report)}\n';
  }
}

/// Stable failure from the guarded polygon migration write boundary.
final class PolygonAuthoringMigrationWriteException implements Exception {
  PolygonAuthoringMigrationWriteException({
    required this.code,
    required this.message,
    this.cause,
    this.rollbackComplete,
    this.outputsCommitted = false,
    Iterable<String> sourcePaths = const <String>[],
  }) : sourcePaths = List<String>.unmodifiable(
         sourcePaths.toSet().toList()..sort(),
       );

  static const int reportVersion = 1;

  final String code;
  final String message;
  final Object? cause;

  /// Null when replacement never began, otherwise the transaction result.
  final bool? rollbackComplete;
  final bool outputsCommitted;
  final List<String> sourcePaths;

  /// Emits stable failure evidence without filesystem-specific cause text.
  ///
  /// `blocked` means replacement never began. A transaction failure is
  /// classified separately as fully rolled back, incompletely rolled back, or
  /// committed with cleanup failure so automation cannot mistake those states.
  String toCanonicalJson() {
    final rollbackAttempted = rollbackComplete != null;
    final status = outputsCommitted
        ? 'committedCleanupFailed'
        : rollbackComplete == true
        ? 'rolledBack'
        : rollbackComplete == false
        ? 'rollbackFailed'
        : 'blocked';
    final report = <String, Object>{
      'reportVersion': reportVersion,
      'mode': 'write',
      'status': status,
      'failure': <String, Object>{
        'code': code,
        'message': message,
        'rollbackAttempted': rollbackAttempted,
        'rollbackComplete': rollbackComplete ?? false,
        'outputsCommitted': outputsCommitted,
      },
      'sourcePaths': sourcePaths,
    };
    return '${const JsonEncoder.withIndent('  ').convert(report)}\n';
  }

  @override
  String toString() {
    final detail = cause == null ? '' : ' Cause: $cause';
    return '$code: $message$detail';
  }
}

/// Applies an already reviewed migration check as one guarded source batch.
///
/// The reviewed SHA-256 set is re-read after every target has been staged but
/// immediately before replacement. Installed v3/v2 source is then parsed and
/// validated while all legacy backups still exist. Any drift, I/O, byte, or
/// post-write validation failure restores the complete legacy source set.
/// This API intentionally has no CLI caller until the normal editor cutover is
/// ready to consume current schemas.
abstract final class PolygonAuthoringMigrationTransaction {
  static PolygonAuthoringMigrationWriteResult apply({
    required String workspaceRoot,
    required PolygonAuthoringMigrationCheck check,
  }) {
    final workspace = EditorWorkspace(rootPath: workspaceRoot);
    final targets = _validateReviewedCheck(workspace, check);
    try {
      _requireFreshSources(workspace, check);
    } on _MigrationWriteAbort catch (error) {
      throw PolygonAuthoringMigrationWriteException(
        code: error.code,
        message: error.message,
      );
    }

    if (check.sourceState == PolygonAuthoringMigrationSourceState.current) {
      if (targets.any((target) => target.hasPendingChange)) {
        throw PolygonAuthoringMigrationWriteException(
          code: 'migration_write_current_pending',
          message:
              'Current-schema source cannot contain pending migration files.',
        );
      }
      return _result(
        status: PolygonAuthoringMigrationWriteStatus.noOp,
        sourceStateBefore: check.sourceState,
        targets: targets,
      );
    }

    if (targets.any((target) => !target.hasPendingChange)) {
      throw PolygonAuthoringMigrationWriteException(
        code: 'migration_write_legacy_target_not_pending',
        message:
            'Every legacy source must have a current-schema replacement in '
            'the reviewed batch.',
      );
    }

    final transaction = WorkspaceWriteTransaction(
      targets.map(
        (target) => WorkspaceWriteArtifact(
          path: workspace.resolve(p.normalize(target.sourcePath)),
          contents: target.canonicalContents,
        ),
      ),
    );
    try {
      transaction.apply(
        beforeReplace: () => _requireFreshSources(workspace, check),
        verifyReplacements: () => _requireCurrentReplacementSet(
          workspace: workspace,
          reviewedTargets: targets,
        ),
      );
    } on WorkspaceWriteTransactionException catch (error, stackTrace) {
      final abort = error.cause is _MigrationWriteAbort
          ? error.cause as _MigrationWriteAbort
          : null;
      Error.throwWithStackTrace(
        PolygonAuthoringMigrationWriteException(
          code: abort?.code ?? 'migration_write_transaction_failed',
          message:
              abort?.message ??
              'The source transaction failed and attempted recovery.',
          cause: error.cause,
          rollbackComplete: error.rollbackComplete,
          outputsCommitted: error.outputsCommitted,
          sourcePaths: targets.map((target) => target.sourcePath),
        ),
        stackTrace,
      );
    }

    return _result(
      status: PolygonAuthoringMigrationWriteStatus.committed,
      sourceStateBefore: check.sourceState,
      targets: targets,
    );
  }
}

List<PolygonAuthoringMigrationTargetFile> _validateReviewedCheck(
  EditorWorkspace workspace,
  PolygonAuthoringMigrationCheck check,
) {
  if (check.hasBlockers) {
    throw PolygonAuthoringMigrationWriteException(
      code: 'migration_write_check_blocked',
      message: 'A blocker-bearing migration check cannot authorize writes.',
    );
  }
  if (check.sourceFiles.isEmpty ||
      check.targetFiles.length != check.sourceFiles.length) {
    throw PolygonAuthoringMigrationWriteException(
      code: 'migration_write_plan_incomplete',
      message:
          'The reviewed source and target sets must be complete and equal.',
    );
  }

  final sourcesByPath = <String, String>{};
  for (final source in check.sourceFiles) {
    workspace.resolve(p.normalize(source.sourcePath));
    final key = _canonicalSourcePath(source.sourcePath);
    if (sourcesByPath.containsKey(key)) {
      throw PolygonAuthoringMigrationWriteException(
        code: 'migration_write_source_path_ambiguous',
        message: 'Reviewed source paths are not canonically unique.',
      );
    }
    sourcesByPath[key] = source.sha256;
  }

  final targets = List<PolygonAuthoringMigrationTargetFile>.of(
    check.targetFiles,
  )..sort((left, right) => left.sourcePath.compareTo(right.sourcePath));
  final targetPaths = <String>{};
  for (final target in targets) {
    workspace.resolve(p.normalize(target.sourcePath));
    final key = _canonicalSourcePath(target.sourcePath);
    if (!targetPaths.add(key) || sourcesByPath[key] != target.beforeSha256) {
      throw PolygonAuthoringMigrationWriteException(
        code: 'migration_write_target_unbound',
        message:
            'Every target must bind exactly one reviewed source path and digest.',
      );
    }
    if (WorkspaceFileIo.sha256Digest(target.canonicalContents) !=
        target.afterSha256) {
      throw PolygonAuthoringMigrationWriteException(
        code: 'migration_write_target_digest_invalid',
        message: 'Target bytes do not match ${target.sourcePath}.afterSha256.',
      );
    }
  }
  if (targetPaths.length != sourcesByPath.length ||
      !targetPaths.containsAll(sourcesByPath.keys)) {
    throw PolygonAuthoringMigrationWriteException(
      code: 'migration_write_target_set_incomplete',
      message: 'The target set does not cover every reviewed source path.',
    );
  }
  return List<PolygonAuthoringMigrationTargetFile>.unmodifiable(targets);
}

void _requireFreshSources(
  EditorWorkspace workspace,
  PolygonAuthoringMigrationCheck check,
) {
  final current = <String, String>{};
  for (final source in check.sourceFiles) {
    final file = File(workspace.resolve(p.normalize(source.sourcePath)));
    if (!file.existsSync()) continue;
    try {
      current[source.sourcePath] = WorkspaceFileIo.sha256Digest(
        file.readAsStringSync(),
      );
    } on Object {
      // The shared digest audit reports unreadable input as missing.
    }
  }
  final issues = check.auditSourceDigests(current);
  if (issues.isEmpty) return;
  final issue = issues.first;
  throw _MigrationWriteAbort(code: issue.code, message: issue.message);
}

void _requireCurrentReplacementSet({
  required EditorWorkspace workspace,
  required List<PolygonAuthoringMigrationTargetFile> reviewedTargets,
}) {
  final PolygonAuthoringMigrationCheck current;
  try {
    current = PolygonAuthoringMigrationCheck.fromRepository(workspace.rootPath);
  } on Object catch (error) {
    throw _MigrationWriteAbort(
      code: 'migration_write_post_validation_failed',
      message:
          'Installed source could not be loaded as one current generation: $error',
    );
  }
  if (current.sourceState != PolygonAuthoringMigrationSourceState.current ||
      current.hasBlockers ||
      current.targetFiles.any((target) => target.hasPendingChange)) {
    throw const _MigrationWriteAbort(
      code: 'migration_write_post_validation_failed',
      message:
          'Installed source did not produce a blocker-free current-schema no-op.',
    );
  }

  final currentDigests = <String, String>{
    for (final source in current.sourceFiles)
      _canonicalSourcePath(source.sourcePath): source.sha256,
  };
  for (final target in reviewedTargets) {
    if (currentDigests[_canonicalSourcePath(target.sourcePath)] !=
        target.afterSha256) {
      throw _MigrationWriteAbort(
        code: 'migration_write_post_digest_mismatch',
        message: 'Installed bytes changed for ${target.sourcePath}.',
      );
    }
  }
}

PolygonAuthoringMigrationWriteResult _result({
  required PolygonAuthoringMigrationWriteStatus status,
  required PolygonAuthoringMigrationSourceState sourceStateBefore,
  required List<PolygonAuthoringMigrationTargetFile> targets,
}) => PolygonAuthoringMigrationWriteResult(
  status: status,
  sourceStateBefore: sourceStateBefore,
  files: targets.map(
    (target) => PolygonAuthoringMigrationWrittenFile(
      sourcePath: target.sourcePath,
      beforeSha256: target.beforeSha256,
      afterSha256: target.afterSha256,
      changed: target.hasPendingChange,
    ),
  ),
);

String _canonicalSourcePath(String sourcePath) {
  final normalized = p.normalize(sourcePath).replaceAll('\\', '/');
  return Platform.isWindows ? normalized.toLowerCase() : normalized;
}

final class _MigrationWriteAbort implements Exception {
  const _MigrationWriteAbort({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => '$code: $message';
}
