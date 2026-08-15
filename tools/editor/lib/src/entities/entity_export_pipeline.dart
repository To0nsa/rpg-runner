// Source-backed export entrypoint for the entities workflow.
//
// This file is the single seam for pending-change previews and direct-write
// export. Planning, artifact rendering, and rollback-aware file writes live in
// part files so the plugin can delegate export without reimplementing safety
// logic.
import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;

import '../domain/authoring_types.dart';
import '../workspace/editor_workspace.dart';
import '../workspace/workspace_write_transaction.dart';
import 'entity_change_policy.dart';
import 'entity_document_pipeline.dart';
import 'entity_domain_models.dart';
import 'entity_source_parser.dart';

part 'export/entity_export_artifacts.dart';
part 'export/entity_export_patch_planner.dart';
part 'export/entity_export_writer.dart';

class _EntitySourceDriftException implements Exception {
  const _EntitySourceDriftException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Deterministic fault-injection seams for entity transaction tests.
///
/// Production construction leaves both callbacks null. Tests use them to
/// mutate staged state at the final drift boundary or reject installed output
/// while rollback is still possible.
class EntityExportHooks {
  const EntityExportHooks({this.beforeReplace, this.verifyReplacements});

  final void Function(EditorWorkspace workspace)? beforeReplace;
  final void Function(EditorWorkspace workspace)? verifyReplacements;
}

/// Applies one prepared entity transaction with its safety callbacks.
typedef EntityTransactionApply =
    void Function(
      WorkspaceWriteTransaction transaction,
      void Function() beforeReplace,
      void Function() verifyReplacements,
    );

/// Owns source-backed entity patch planning, diff rendering, and direct-write
/// application.
///
/// Pending diff previews and export both flow through the same internal plan so
/// source edit calculation stays single-sourced.
class EntityExportPipeline {
  EntityExportPipeline({
    EntityDocumentPipeline? documentPipeline,
    EntityExportHooks hooks = const EntityExportHooks(),
    EntityTransactionApply? transactionApply,
  }) : _documentPipeline = documentPipeline ?? EntityDocumentPipeline(),
       _hooks = hooks,
       _transactionApply = transactionApply ?? _applyEntityTransaction;

  final EntityDocumentPipeline _documentPipeline;
  final EntityExportHooks _hooks;
  final EntityTransactionApply _transactionApply;

  /// Builds the user-facing pending diff preview for the current document.
  ///
  /// This uses the same patch plan as real export so the UI never advertises
  /// writes the file writer would reject.
  PendingChanges describePendingChanges(
    EditorWorkspace workspace, {
    required EntityDocument document,
  }) {
    final plan = _buildPlan(_documentPipeline, workspace, document: document);
    return plan.hasChanges ? plan.toPendingChanges() : PendingChanges.empty;
  }

  /// Applies the current document through a verified repository transaction.
  ///
  /// Blocking validation errors fail fast before any file I/O. When writes do
  /// proceed, backup and rollback semantics are delegated to the writer.
  Future<ExportResult> exportToRepo(
    EditorWorkspace workspace, {
    required EntityDocument document,
    required List<ValidationIssue> validationIssues,
  }) async {
    final blockingIssues = validationIssues
        .where((issue) => issue.severity == ValidationSeverity.error)
        .toList(growable: false);
    if (blockingIssues.isNotEmpty) {
      return _buildExportErrorResult(
        'Cannot export entities while validation has '
        '${blockingIssues.length} blocking issue(s).',
        outcome: ExportOutcome.validationFailed,
      );
    }

    _EntityExportPlan? plan;
    try {
      plan = _buildPlan(_documentPipeline, workspace, document: document);
      if (!plan.hasChanges) {
        return plan.buildNoChangesResult();
      }

      final backupPaths = _applyTransactionalWriteWithBackups(
        workspace,
        plan,
        documentPipeline: _documentPipeline,
        hooks: _hooks,
        transactionApply: _transactionApply,
      );
      return plan.buildAppliedResult(backupPaths: backupPaths);
    } on WorkspaceWriteTransactionException catch (error) {
      if (error.outputsCommitted) {
        final committedPlan = plan;
        if (committedPlan == null) {
          return _buildExportErrorResult('$error');
        }
        final backupPaths = _backupPathsFor(committedPlan.filePatches);
        return committedPlan.buildAppliedResult(
          backupPaths: backupPaths,
          outcome: ExportOutcome.appliedWithCleanupRequired,
          recoveryPaths: error.recoveryPaths,
        );
      }
      if (error.rollbackFailures.isNotEmpty) {
        return _buildExportErrorResult(
          '$error',
          outcome: ExportOutcome.rollbackIncomplete,
          recoveryPaths: error.recoveryPaths,
        );
      }
      if (error.cause is _EntitySourceDriftException) {
        return _buildExportErrorResult(
          '${error.cause}',
          outcome: ExportOutcome.sourceDrift,
        );
      }
      return _buildExportErrorResult('$error');
    } on _EntitySourceDriftException catch (error) {
      return _buildExportErrorResult(
        '$error',
        outcome: ExportOutcome.sourceDrift,
      );
    } catch (error) {
      return _buildExportErrorResult('$error');
    }
  }
}

void _applyEntityTransaction(
  WorkspaceWriteTransaction transaction,
  void Function() beforeReplace,
  void Function() verifyReplacements,
) {
  transaction.apply(
    beforeReplace: beforeReplace,
    verifyReplacements: verifyReplacements,
  );
}
