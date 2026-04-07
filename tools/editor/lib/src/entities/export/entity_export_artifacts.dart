// Artifact builders for the entities export plan.
//
// This file stays pure on purpose: it turns already-resolved patches into
// pending previews, diff text, and export artifacts without reading or writing
// workspace files.
part of '../entity_export_pipeline.dart';

/// Immutable export plan shared by pending-preview and apply flows.
///
/// Keeping both paths on the same plan prevents the UI from showing diffs that
/// direct-write export would compute differently.
class _EntityExportPlan {
  const _EntityExportPlan({
    required this.changedEntries,
    required this.filePatches,
  });

  const _EntityExportPlan.empty()
    : changedEntries = const <EntityEntry>[],
      filePatches = const <_EntityFilePatch>[];

  final List<EntityEntry> changedEntries;
  final List<_EntityFilePatch> filePatches;

  bool get hasChanges => changedEntries.isNotEmpty;

  PendingChanges toPendingChanges() {
    final fileDiffs = filePatches
        .map(
          (patch) => PendingFileDiff(
            relativePath: patch.relativePath,
            editCount: patch.edits.length,
            unifiedDiff: _buildUnifiedDiffForFile(patch),
          ),
        )
        .toList(growable: false);

    return PendingChanges(
      changedItemIds: changedEntries.map((entry) => entry.id).toList(),
      fileDiffs: fileDiffs,
    );
  }

  ExportResult buildNoChangesResult() {
    return ExportResult(
      applied: false,
      artifacts: const <ExportArtifact>[
        ExportArtifact(
          title: 'entity_summary.md',
          content:
              '# Entity Export\n\nchangedEntries: 0\n\nNo entity edits detected.',
        ),
      ],
    );
  }

  ExportResult buildAppliedResult({required List<String> backupPaths}) {
    final unifiedPatch = _buildUnifiedDiffArtifact(filePatches);
    final artifacts = <ExportArtifact>[
      ExportArtifact(
        title: 'entity_summary.md',
        content: _buildSummary(
          changedEntries: changedEntries,
          filePatches: filePatches,
        ),
      ),
      ExportArtifact(title: 'entity_changes.patch', content: unifiedPatch),
      if (backupPaths.isNotEmpty)
        ExportArtifact(
          title: 'entity_backups.md',
          content: _buildBackupsArtifact(backupPaths),
        ),
      for (final patch in filePatches)
        ExportArtifact(
          title: 'patch_${_sanitizeTitle(patch.relativePath)}.md',
          content: _buildPatchArtifact(patch),
        ),
    ];

    return ExportResult(applied: true, artifacts: artifacts);
  }

  String _buildSummary({
    required List<EntityEntry> changedEntries,
    required List<_EntityFilePatch> filePatches,
  }) {
    final lines = <String>[
      '# Entity Export',
      '',
      'changedEntries: ${changedEntries.length}',
      'files: ${filePatches.length}',
      '',
      '## Entries',
      ...changedEntries.map((entry) => '- ${entry.id} (${entry.sourcePath})'),
      '',
      '## Files',
      ...filePatches.map(
        (patch) => '- ${patch.relativePath} (${patch.edits.length} edit(s))',
      ),
    ];
    return lines.join('\n');
  }

  String _buildBackupsArtifact(List<String> backupPaths) {
    final lines = <String>[
      '# Entity Backup Files',
      '',
      'Backup files were written before direct write apply.',
      '',
      ...backupPaths.map((path) => '- $path'),
    ];
    return lines.join('\n');
  }

  String _buildPatchArtifact(_EntityFilePatch patch) {
    final lines = <String>[
      '# File Patch',
      '',
      'file: ${patch.relativePath}',
      'edits: ${patch.edits.length}',
      '',
    ];

    for (final edit in patch.edits) {
      lines.add('## ${edit.entryId}');
      lines.add('range: ${edit.startOffset}-${edit.endOffset}');
      lines.add('');
      lines.add('### Before');
      lines.add('```dart');
      lines.add(edit.beforeSnippet);
      lines.add('```');
      lines.add('');
      lines.add('### After');
      lines.add('```dart');
      lines.add(edit.afterSnippet);
      lines.add('```');
      lines.add('');
    }

    return lines.join('\n');
  }

  String _sanitizeTitle(String relativePath) {
    return relativePath.replaceAll(RegExp(r'[\\/:]'), '_');
  }
}

String _buildUnifiedDiffArtifact(List<_EntityFilePatch> filePatches) {
  final sections = filePatches.map(_buildUnifiedDiffForFile).toList();
  return sections.join('\n');
}

String _buildUnifiedDiffForFile(_EntityFilePatch patch) {
  final patchPath = _toPatchPath(patch.relativePath);
  final oldLines = _splitLinesForDiff(patch.originalContent);
  final newLines = _splitLinesForDiff(patch.patchedContent);
  final operations = _buildLineDiff(oldLines, newLines);
  final hunks = _buildHunks(operations, contextLines: 3);

  final lines = <String>[
    'diff --git a/$patchPath b/$patchPath',
    '--- a/$patchPath',
    '+++ b/$patchPath',
  ];
  if (hunks.isEmpty) {
    return lines.join('\n');
  }
  for (final hunk in hunks) {
    lines.add(
      '@@ -${hunk.oldStart},${hunk.oldCount} +${hunk.newStart},'
      '${hunk.newCount} @@',
    );
    lines.addAll(hunk.lines);
  }
  return lines.join('\n');
}

String _toPatchPath(String relativePath) => relativePath.replaceAll('\\', '/');

List<String> _splitLinesForDiff(String content) {
  final normalized = content.replaceAll('\r\n', '\n');
  final lines = normalized.split('\n');
  if (lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }
  return lines;
}

// Use an in-process LCS diff so artifact generation stays deterministic and
// does not depend on shelling out to `git diff`.
List<_DiffLineOp> _buildLineDiff(List<String> oldLines, List<String> newLines) {
  final oldLength = oldLines.length;
  final newLength = newLines.length;
  final lcs = List<List<int>>.generate(
    oldLength + 1,
    (_) => List<int>.filled(newLength + 1, 0),
    growable: false,
  );

  for (var i = oldLength - 1; i >= 0; i -= 1) {
    for (var j = newLength - 1; j >= 0; j -= 1) {
      if (oldLines[i] == newLines[j]) {
        lcs[i][j] = lcs[i + 1][j + 1] + 1;
      } else {
        lcs[i][j] = math.max(lcs[i + 1][j], lcs[i][j + 1]);
      }
    }
  }

  final ops = <_DiffLineOp>[];
  var i = 0;
  var j = 0;
  while (i < oldLength || j < newLength) {
    if (i < oldLength && j < newLength && oldLines[i] == newLines[j]) {
      ops.add(_DiffLineOp(_DiffLineOpKind.equal, oldLines[i]));
      i += 1;
      j += 1;
      continue;
    }
    if (j < newLength && (i == oldLength || lcs[i][j + 1] >= lcs[i + 1][j])) {
      ops.add(_DiffLineOp(_DiffLineOpKind.added, newLines[j]));
      j += 1;
    } else {
      ops.add(_DiffLineOp(_DiffLineOpKind.removed, oldLines[i]));
      i += 1;
    }
  }
  return ops;
}

List<_UnifiedDiffHunk> _buildHunks(
  List<_DiffLineOp> operations, {
  required int contextLines,
}) {
  final changedIndexes = <int>[];
  for (var index = 0; index < operations.length; index += 1) {
    if (operations[index].kind != _DiffLineOpKind.equal) {
      changedIndexes.add(index);
    }
  }
  if (changedIndexes.isEmpty) {
    return const <_UnifiedDiffHunk>[];
  }

  final oldBefore = List<int>.filled(operations.length + 1, 0);
  final newBefore = List<int>.filled(operations.length + 1, 0);
  for (var index = 0; index < operations.length; index += 1) {
    final op = operations[index];
    oldBefore[index + 1] =
        oldBefore[index] + (op.kind == _DiffLineOpKind.added ? 0 : 1);
    newBefore[index + 1] =
        newBefore[index] + (op.kind == _DiffLineOpKind.removed ? 0 : 1);
  }

  final hunks = <_UnifiedDiffHunk>[];
  var cursor = 0;
  while (cursor < changedIndexes.length) {
    final firstChange = changedIndexes[cursor];
    var lastChange = firstChange;
    cursor += 1;
    while (cursor < changedIndexes.length) {
      final nextChange = changedIndexes[cursor];
      if (nextChange - lastChange > contextLines * 2 + 1) {
        break;
      }
      lastChange = nextChange;
      cursor += 1;
    }

    final start = math.max(0, firstChange - contextLines);
    final end = math.min(operations.length - 1, lastChange + contextLines);

    var oldCount = 0;
    var newCount = 0;
    final lines = <String>[];
    for (var index = start; index <= end; index += 1) {
      final op = operations[index];
      switch (op.kind) {
        case _DiffLineOpKind.equal:
          oldCount += 1;
          newCount += 1;
          lines.add(' ${op.line}');
          break;
        case _DiffLineOpKind.removed:
          oldCount += 1;
          lines.add('-${op.line}');
          break;
        case _DiffLineOpKind.added:
          newCount += 1;
          lines.add('+${op.line}');
          break;
      }
    }

    hunks.add(
      _UnifiedDiffHunk(
        oldStart: oldBefore[start] + 1,
        oldCount: oldCount,
        newStart: newBefore[start] + 1,
        newCount: newCount,
        lines: lines,
      ),
    );
  }

  return hunks;
}

class _EntitySourceEdit {
  const _EntitySourceEdit({
    required this.entryId,
    required this.sourcePath,
    required this.startOffset,
    required this.endOffset,
    required this.beforeSnippet,
    required this.afterSnippet,
  });

  final String entryId;
  final String sourcePath;
  final int startOffset;
  final int endOffset;
  final String beforeSnippet;
  final String afterSnippet;
}

class _EntityFilePatch {
  const _EntityFilePatch({
    required this.relativePath,
    required this.originalContent,
    required this.patchedContent,
    required this.edits,
  });

  final String relativePath;
  final String originalContent;
  final String patchedContent;
  final List<_EntitySourceEdit> edits;
}

class _WrittenSourceRestore {
  const _WrittenSourceRestore({
    required this.relativePath,
    required this.originalContent,
  });

  final String relativePath;
  final String originalContent;
}

enum _DiffLineOpKind { equal, added, removed }

class _DiffLineOp {
  const _DiffLineOp(this.kind, this.line);

  final _DiffLineOpKind kind;
  final String line;
}

class _UnifiedDiffHunk {
  const _UnifiedDiffHunk({
    required this.oldStart,
    required this.oldCount,
    required this.newStart,
    required this.newCount,
    required this.lines,
  });

  final int oldStart;
  final int oldCount;
  final int newStart;
  final int newCount;
  final List<String> lines;
}
