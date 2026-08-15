// Transactional repository application for entity export.
//
// Persistent user-visible `.bak` files and patched Dart sources are installed
// as one verified artifact set. Transaction-owned sibling backups are separate
// recovery state and are removed only after source reparse succeeds.
part of '../entity_export_pipeline.dart';

List<String> _applyTransactionalWriteWithBackups(
  EditorWorkspace workspace,
  _EntityExportPlan plan, {
  required EntityDocumentPipeline documentPipeline,
  required EntityExportHooks hooks,
  required EntityTransactionApply transactionApply,
}) {
  final backupPaths = _backupPathsFor(plan.filePatches);
  final artifacts = <WorkspaceWriteArtifact>[];
  for (var index = 0; index < plan.filePatches.length; index += 1) {
    final patch = plan.filePatches[index];
    final sourceRelativePath = p.normalize(patch.relativePath);
    artifacts.add(
      WorkspaceWriteArtifact(
        path: workspace.resolve(sourceRelativePath),
        contents: patch.patchedContent,
      ),
    );
    artifacts.add(
      WorkspaceWriteArtifact(
        path: workspace.resolve(backupPaths[index]),
        contents: patch.originalContent,
      ),
    );
  }

  final transaction = WorkspaceWriteTransaction(artifacts);
  transactionApply(
    transaction,
    () {
      hooks.beforeReplace?.call(workspace);
      _verifyEntitySourceBaselines(workspace, plan.filePatches);
    },
    () {
      _verifyInstalledEntitySources(
        workspace,
        plan,
        documentPipeline: documentPipeline,
      );
      hooks.verifyReplacements?.call(workspace);
    },
  );
  return backupPaths;
}

List<String> _backupPathsFor(List<_EntityFilePatch> filePatches) =>
    List<String>.unmodifiable(<String>[
      for (final patch in filePatches)
        p.normalize('${p.normalize(patch.relativePath)}.bak'),
    ]);

void _verifyEntitySourceBaselines(
  EditorWorkspace workspace,
  List<_EntityFilePatch> filePatches,
) {
  for (final patch in filePatches) {
    final relativePath = p.normalize(patch.relativePath);
    final file = File(workspace.resolve(relativePath));
    if (!file.existsSync()) {
      throw _EntitySourceDriftException(
        'Final source drift check failed; source file is missing: '
        '$relativePath. Reload workspace and review pending changes.',
      );
    }
    final installed = file.readAsStringSync();
    if (installed != patch.originalContent) {
      throw _EntitySourceDriftException(
        'Final source drift detected in $relativePath immediately before '
        'replacement. No entity files were committed. Reload workspace, '
        'review the external edit, and apply again.',
      );
    }
  }
}

void _verifyInstalledEntitySources(
  EditorWorkspace workspace,
  _EntityExportPlan plan, {
  required EntityDocumentPipeline documentPipeline,
}) {
  final reparsed = EntitySourceParser().parse(workspace);
  final blockingIssues = reparsed.issues
      .where((issue) => issue.severity == ValidationSeverity.error)
      .toList(growable: false);
  if (blockingIssues.isNotEmpty) {
    throw StateError(
      'Installed entity sources failed reparse validation: '
      '${blockingIssues.map((issue) => issue.code).join(', ')}.',
    );
  }

  final reparsedById = <String, EntityEntry>{
    for (final entry in reparsed.entries) entry.id: entry,
  };
  for (final expected in plan.changedEntries) {
    final actual = reparsedById[expected.id];
    if (actual == null) {
      throw StateError(
        'Installed entity sources no longer resolve ${expected.id}.',
      );
    }
    if (documentPipeline.changeSet(actual, expected).hasChanges) {
      throw StateError(
        'Installed entity source verification does not match the confirmed '
        'values for ${expected.id}.',
      );
    }
  }
}

ExportResult _buildExportErrorResult(
  String message, {
  ExportOutcome outcome = ExportOutcome.failed,
  List<String> recoveryPaths = const <String>[],
}) {
  return ExportResult(
    applied: false,
    outcome: outcome,
    message: message,
    artifacts: <ExportArtifact>[
      ExportArtifact(
        title: 'entity_export_error.md',
        content: '# Entity Export Error\n\n$message',
      ),
      if (recoveryPaths.isNotEmpty)
        ExportArtifact(
          title: 'entity_transaction_recovery.md',
          content: <String>[
            '# Entity Transaction Recovery',
            '',
            'Rollback did not restore every target. Preserve these paths and '
                'review the repository before another Apply:',
            '',
            ...recoveryPaths.map((path) => '- $path'),
          ].join('\n'),
        ),
    ],
  );
}
