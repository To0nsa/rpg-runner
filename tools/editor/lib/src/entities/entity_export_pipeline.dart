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
import 'entity_document_pipeline.dart';
import 'entity_domain_models.dart';

part 'export/entity_export_artifacts.dart';
part 'export/entity_export_patch_planner.dart';
part 'export/entity_export_writer.dart';

/// Owns source-backed entity patch planning, diff rendering, and direct-write
/// application.
///
/// Pending diff previews and export both flow through the same internal plan so
/// source edit calculation stays single-sourced.
class EntityExportPipeline {
  EntityExportPipeline({EntityDocumentPipeline? documentPipeline})
    : _documentPipeline = documentPipeline ?? EntityDocumentPipeline();

  final EntityDocumentPipeline _documentPipeline;

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

  /// Applies the current document back to repo files using direct source edits.
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
      );
    }

    try {
      final plan = _buildPlan(_documentPipeline, workspace, document: document);
      if (!plan.hasChanges) {
        return plan.buildNoChangesResult();
      }

      final backupPaths = _applyDirectWriteWithBackups(
        workspace,
        plan.filePatches,
      );
      return plan.buildAppliedResult(backupPaths: backupPaths);
    } catch (error) {
      return _buildExportErrorResult('$error');
    }
  }
}
