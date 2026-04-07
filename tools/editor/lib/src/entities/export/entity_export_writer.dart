// Direct-write application and rollback for entity export.
//
// This file is the only place that mutates workspace files for the entities
// domain. It writes backups first, then applies patches, and restores both
// sources and temporary backup artifacts if any later step fails.
part of '../entity_export_pipeline.dart';

// Backups are created for every touched file before source content changes so a
// mid-export failure can restore the pre-export workspace state.
List<String> _applyDirectWriteWithBackups(
  EditorWorkspace workspace,
  List<_EntityFilePatch> filePatches,
) {
  final backupPaths = <String>[];
  final writtenBackups = <_BackupRestoreState>[];
  final writtenSources = <_WrittenSourceRestore>[];
  try {
    for (final patch in filePatches) {
      final sourceRelativePath = p.normalize(patch.relativePath);
      final backupRelativePath = p.normalize('$sourceRelativePath.bak');
      final backupFile = File(workspace.resolve(backupRelativePath));
      writtenBackups.add(
        _captureBackupRestoreState(workspace, backupRelativePath),
      );
      final backupParentDir = backupFile.parent;
      if (!backupParentDir.existsSync()) {
        backupParentDir.createSync(recursive: true);
      }
      backupFile.writeAsStringSync(patch.originalContent);
      backupPaths.add(backupRelativePath);
    }

    for (final patch in filePatches) {
      final sourceRelativePath = p.normalize(patch.relativePath);
      final sourceFile = File(workspace.resolve(sourceRelativePath));
      sourceFile.writeAsStringSync(patch.patchedContent);
      writtenSources.add(
        _WrittenSourceRestore(
          relativePath: sourceRelativePath,
          originalContent: patch.originalContent,
        ),
      );
    }
    return backupPaths;
  } catch (error) {
    final rollbackFailures = <String>[];
    for (final write in writtenSources.reversed) {
      try {
        final sourceFile = File(workspace.resolve(write.relativePath));
        sourceFile.writeAsStringSync(write.originalContent);
      } catch (restoreError) {
        rollbackFailures.add('${write.relativePath}: $restoreError');
      }
    }
    for (final backup in writtenBackups.reversed) {
      try {
        _restoreBackupState(workspace, backup);
      } catch (restoreError) {
        rollbackFailures.add('${backup.relativePath}: $restoreError');
      }
    }

    final rollbackMessage = rollbackFailures.isEmpty
        ? 'Any files written before the failure were rolled back to their '
              'original content, including temporary backup artifacts.'
        : 'Rollback also failed for: ${rollbackFailures.join('; ')}';
    throw StateError('$error\n$rollbackMessage');
  }
}

_BackupRestoreState _captureBackupRestoreState(
  EditorWorkspace workspace,
  String relativePath,
) {
  final absolutePath = workspace.resolve(relativePath);
  final entityType = FileSystemEntity.typeSync(
    absolutePath,
    followLinks: false,
  );
  return switch (entityType) {
    FileSystemEntityType.file => _BackupRestoreState(
      relativePath: relativePath,
      existedAsFile: true,
      originalContent: File(absolutePath).readAsStringSync(),
    ),
    _ => _BackupRestoreState(relativePath: relativePath),
  };
}

void _restoreBackupState(
  EditorWorkspace workspace,
  _BackupRestoreState backupState,
) {
  final backupFile = File(workspace.resolve(backupState.relativePath));
  if (backupState.existedAsFile) {
    backupFile.writeAsStringSync(backupState.originalContent!);
    return;
  }
  if (backupFile.existsSync()) {
    backupFile.deleteSync();
  }
}

ExportResult _buildExportErrorResult(String message) {
  return ExportResult(
    applied: false,
    artifacts: [
      ExportArtifact(
        title: 'entity_export_error.md',
        content: '# Entity Export Error\n\n$message',
      ),
    ],
  );
}

/// Snapshot of the pre-export state for one `.bak` path.
///
/// Backup paths may already exist in user workspaces, so rollback must know
/// whether to restore prior content or delete the temporary file entirely.
class _BackupRestoreState {
  const _BackupRestoreState({
    required this.relativePath,
    this.existedAsFile = false,
    this.originalContent,
  });

  final String relativePath;
  final bool existedAsFile;
  final String? originalContent;
}
