import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;

import '../domain/authoring_types.dart';
import '../workspace/editor_workspace.dart';
import 'collider_domain_models.dart';
import 'collider_source_parser.dart';

class ColliderDomainPlugin implements AuthoringDomainPlugin {
  static const String pluginId = 'collider';
  static const double _changeEpsilon = 0.000001;

  @override
  String get id => pluginId;

  @override
  String get displayName => 'Entity Colliders';

  @override
  Future<AuthoringDocument> loadFromRepo(EditorWorkspace workspace) async {
    final parseResult = ColliderSourceParser().parse(workspace);
    final baseline = <String, ColliderEntry>{
      for (final entry in parseResult.entries) entry.id: entry,
    };
    return ColliderDocument(
      entries: parseResult.entries,
      baselineById: baseline,
      runtimeGridCellSize: parseResult.runtimeGridCellSize,
      loadIssues: parseResult.issues,
    );
  }

  @override
  List<ValidationIssue> validate(AuthoringDocument document) {
    final colliderDocument = _asColliderDocument(document);
    final issues = <ValidationIssue>[...colliderDocument.loadIssues];

    for (final entry in colliderDocument.entries) {
      if (!entry.halfX.isFinite || entry.halfX <= 0) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'invalid_half_x',
            message: '${entry.id} has invalid halfX (${entry.halfX})',
            sourcePath: entry.sourcePath,
          ),
        );
      }
      if (!entry.halfY.isFinite || entry.halfY <= 0) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'invalid_half_y',
            message: '${entry.id} has invalid halfY (${entry.halfY})',
            sourcePath: entry.sourcePath,
          ),
        );
      }
      if (!entry.offsetX.isFinite || !entry.offsetY.isFinite) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'invalid_offset',
            message:
                '${entry.id} has invalid offsets '
                '(offsetX=${entry.offsetX}, offsetY=${entry.offsetY})',
            sourcePath: entry.sourcePath,
          ),
        );
      }
      final reference = entry.referenceVisual;
      if (reference != null) {
        final renderScale = reference.renderScale;
        if (renderScale != null &&
            (!renderScale.isFinite || renderScale <= 0)) {
          issues.add(
            ValidationIssue(
              severity: ValidationSeverity.error,
              code: 'invalid_render_scale',
              message: '${entry.id} has invalid renderScale ($renderScale)',
              sourcePath: reference.renderScaleBinding?.sourcePath,
            ),
          );
        }
        final anchorX = reference.anchorXPx;
        final anchorY = reference.anchorYPx;
        if ((anchorX != null && !anchorX.isFinite) ||
            (anchorY != null && !anchorY.isFinite)) {
          issues.add(
            ValidationIssue(
              severity: ValidationSeverity.error,
              code: 'invalid_anchor',
              message:
                  '${entry.id} has invalid anchorInFramePx ($anchorX, $anchorY)',
              sourcePath: reference.anchorBinding?.sourcePath,
            ),
          );
        }
      }
    }

    return issues;
  }

  @override
  EditableScene buildEditableScene(AuthoringDocument document) {
    final colliderDocument = _asColliderDocument(document);
    final sorted = List<ColliderEntry>.from(colliderDocument.entries)
      ..sort((a, b) {
        final typeCompare = a.entityType.index.compareTo(b.entityType.index);
        if (typeCompare != 0) {
          return typeCompare;
        }
        return a.id.compareTo(b.id);
      });
    return ColliderScene(
      entries: sorted,
      runtimeGridCellSize: colliderDocument.runtimeGridCellSize,
    );
  }

  @override
  AuthoringDocument applyEdit(
    AuthoringDocument document,
    AuthoringCommand command,
  ) {
    final colliderDocument = _asColliderDocument(document);
    if (command.kind != 'update_entry') {
      return colliderDocument;
    }

    final targetId = command.payload['id'];
    final halfX = command.payload['halfX'];
    final halfY = command.payload['halfY'];
    final offsetX = command.payload['offsetX'];
    final offsetY = command.payload['offsetY'];
    final anchorXPx = command.payload['anchorXPx'];
    final anchorYPx = command.payload['anchorYPx'];
    final renderScale = command.payload['renderScale'];
    if (targetId is! String) {
      return colliderDocument;
    }

    ColliderEntry? targetEntry;
    for (final entry in colliderDocument.entries) {
      if (entry.id == targetId) {
        targetEntry = entry;
        break;
      }
    }
    final currentEntry = targetEntry;
    if (currentEntry == null) {
      return colliderDocument;
    }

    final nextHalfX = halfX is num ? halfX.toDouble() : currentEntry.halfX;
    final nextHalfY = halfY is num ? halfY.toDouble() : currentEntry.halfY;
    final nextOffsetX = offsetX is num
        ? offsetX.toDouble()
        : currentEntry.offsetX;
    final nextOffsetY = offsetY is num
        ? offsetY.toDouble()
        : currentEntry.offsetY;
    final currentReference = currentEntry.referenceVisual;
    final nextAnchorXPx = anchorXPx is num
        ? anchorXPx.toDouble()
        : currentReference?.anchorXPx;
    final nextAnchorYPx = anchorYPx is num
        ? anchorYPx.toDouble()
        : currentReference?.anchorYPx;
    final nextRenderScale = renderScale is num
        ? renderScale.toDouble()
        : currentReference?.renderScale;
    final nextReference = currentReference?.copyWith(
      anchorXPx: nextAnchorXPx,
      anchorYPx: nextAnchorYPx,
      renderScale: nextRenderScale,
    );

    if (_almostEqual(nextHalfX, currentEntry.halfX) &&
        _almostEqual(nextHalfY, currentEntry.halfY) &&
        _almostEqual(nextOffsetX, currentEntry.offsetX) &&
        _almostEqual(nextOffsetY, currentEntry.offsetY) &&
        !_referenceChanged(nextReference, currentReference)) {
      return colliderDocument;
    }

    final updatedEntries = colliderDocument.entries
        .map((entry) {
          if (entry.id != targetId) {
            return entry;
          }
          return entry.copyWith(
            halfX: nextHalfX,
            halfY: nextHalfY,
            offsetX: nextOffsetX,
            offsetY: nextOffsetY,
            referenceVisual: nextReference,
          );
        })
        .toList(growable: false);

    return ColliderDocument(
      entries: updatedEntries,
      baselineById: colliderDocument.baselineById,
      runtimeGridCellSize: colliderDocument.runtimeGridCellSize,
      loadIssues: colliderDocument.loadIssues,
    );
  }

  @override
  Future<ExportResult> exportToRepo(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
    required ExportMode mode,
  }) async {
    final colliderDocument = _asColliderDocument(document);
    final changedEntries = _changedEntries(colliderDocument);

    if (changedEntries.isEmpty) {
      return ExportResult(
        mode: mode,
        applied: false,
        artifacts: const <ExportArtifact>[
          ExportArtifact(
            title: 'collider_summary.md',
            content:
                '# Collider Export\n\nchangedEntries: 0\n\nNo collider edits detected.',
          ),
        ],
      );
    }

    try {
      final filePatches = _resolveFilePatches(
        workspace,
        document: colliderDocument,
        changedEntries: changedEntries,
      );
      final unifiedPatch = _buildUnifiedDiffArtifact(filePatches);
      var backupPaths = const <String>[];

      if (mode == ExportMode.directWrite) {
        backupPaths = _applyDirectWriteWithBackups(workspace, filePatches);
      }

      final artifacts = <ExportArtifact>[
        ExportArtifact(
          title: 'collider_summary.md',
          content: _buildSummary(
            mode: mode,
            changedEntries: changedEntries,
            filePatches: filePatches,
          ),
        ),
        ExportArtifact(title: 'collider_changes.patch', content: unifiedPatch),
        if (backupPaths.isNotEmpty)
          ExportArtifact(
            title: 'collider_backups.md',
            content: _buildBackupsArtifact(backupPaths),
          ),
        for (final patch in filePatches)
          ExportArtifact(
            title: 'patch_${_sanitizeTitle(patch.relativePath)}.md',
            content: _buildPatchArtifact(patch),
          ),
      ];

      return ExportResult(
        mode: mode,
        applied: mode == ExportMode.directWrite,
        artifacts: artifacts,
      );
    } catch (error) {
      return ExportResult(
        mode: mode,
        applied: false,
        artifacts: [
          ExportArtifact(
            title: 'collider_export_error.md',
            content: '# Collider Export Error\n\n$error',
          ),
        ],
      );
    }
  }

  @override
  PendingChanges describePendingChanges(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) {
    final colliderDocument = _asColliderDocument(document);
    final changedEntries = _changedEntries(colliderDocument);
    if (changedEntries.isEmpty) {
      return const PendingChanges();
    }

    final filePatches = _resolveFilePatches(
      workspace,
      document: colliderDocument,
      changedEntries: changedEntries,
    );

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
      changedEntryIds: changedEntries.map((entry) => entry.id).toList(),
      fileDiffs: fileDiffs,
    );
  }

  List<ColliderEntry> _changedEntries(ColliderDocument document) {
    final changed = <ColliderEntry>[];
    for (final entry in document.entries) {
      final baseline = document.baselineById[entry.id];
      if (baseline == null || _isChanged(entry, baseline)) {
        changed.add(entry);
      }
    }
    return changed;
  }

  List<_ResolvedFilePatch> _resolveFilePatches(
    EditorWorkspace workspace, {
    required ColliderDocument document,
    required List<ColliderEntry> changedEntries,
  }) {
    final editsByPath = <String, List<_ResolvedEdit>>{};

    for (final entry in changedEntries) {
      final baseline = document.baselineById[entry.id];
      if (baseline == null) {
        throw StateError('Missing baseline entry for ${entry.id}.');
      }
      final entryEdits = _buildEditsForEntry(entry, baseline);
      if (entryEdits.isEmpty) {
        throw StateError(
          'Entry ${entry.id} is marked dirty but no source edits were produced.',
        );
      }
      for (final edit in entryEdits) {
        final bucket = editsByPath.putIfAbsent(
          edit.sourcePath,
          () => <_ResolvedEdit>[],
        );
        _addEditOrFail(bucket, edit);
      }
    }

    final patches = <_ResolvedFilePatch>[];
    for (final entry in editsByPath.entries) {
      final relativePath = p.normalize(entry.key);
      final file = File(workspace.resolve(relativePath));
      if (!file.existsSync()) {
        throw StateError('Cannot export; source file missing: $relativePath');
      }

      final original = file.readAsStringSync();
      final edits = List<_ResolvedEdit>.from(entry.value)
        ..sort((a, b) => a.startOffset.compareTo(b.startOffset));

      _validateEditsAgainstSource(relativePath, original, edits);

      var patched = original;
      final descending = edits.reversed.toList(growable: false);
      for (final edit in descending) {
        patched = patched.replaceRange(
          edit.startOffset,
          edit.endOffset,
          edit.afterSnippet,
        );
      }

      patches.add(
        _ResolvedFilePatch(
          relativePath: relativePath,
          originalContent: original,
          patchedContent: patched,
          edits: edits,
        ),
      );
    }

    patches.sort((a, b) => a.relativePath.compareTo(b.relativePath));
    return patches;
  }

  void _addEditOrFail(List<_ResolvedEdit> edits, _ResolvedEdit candidate) {
    for (final existing in edits) {
      if (existing.startOffset != candidate.startOffset ||
          existing.endOffset != candidate.endOffset) {
        continue;
      }
      if (existing.afterSnippet == candidate.afterSnippet &&
          existing.beforeSnippet == candidate.beforeSnippet) {
        return;
      }
      throw StateError(
        'Conflicting edits for ${candidate.sourcePath} at '
        '${candidate.startOffset}-${candidate.endOffset} '
        '(${existing.entryId} vs ${candidate.entryId}).',
      );
    }
    edits.add(candidate);
  }

  List<String> _applyDirectWriteWithBackups(
    EditorWorkspace workspace,
    List<_ResolvedFilePatch> filePatches,
  ) {
    final backupPaths = <String>[];
    for (final patch in filePatches) {
      final sourceRelativePath = p.normalize(patch.relativePath);
      final backupRelativePath = p.normalize('$sourceRelativePath.bak');
      final sourceFile = File(workspace.resolve(sourceRelativePath));
      final backupFile = File(workspace.resolve(backupRelativePath));
      final backupParentDir = backupFile.parent;
      if (!backupParentDir.existsSync()) {
        backupParentDir.createSync(recursive: true);
      }
      backupFile.writeAsStringSync(patch.originalContent);
      sourceFile.writeAsStringSync(patch.patchedContent);
      backupPaths.add(backupRelativePath);
    }
    return backupPaths;
  }

  void _validateEditsAgainstSource(
    String relativePath,
    String content,
    List<_ResolvedEdit> edits,
  ) {
    var previousEnd = -1;
    for (final edit in edits) {
      if (edit.startOffset < 0 || edit.endOffset < 0) {
        throw StateError(
          'Invalid replacement range in $relativePath for ${edit.entryId}.',
        );
      }
      if (edit.startOffset >= edit.endOffset) {
        throw StateError(
          'Empty replacement range in $relativePath for ${edit.entryId}.',
        );
      }
      if (edit.endOffset > content.length) {
        throw StateError(
          'Replacement range out of bounds in $relativePath for ${edit.entryId}.',
        );
      }
      if (previousEnd > edit.startOffset) {
        throw StateError(
          'Overlapping replacement ranges detected in $relativePath.',
        );
      }

      final actual = content.substring(edit.startOffset, edit.endOffset);
      if (actual != edit.beforeSnippet) {
        final expectedPreview = _previewForError(edit.beforeSnippet);
        final actualPreview = _previewForError(actual);
        throw StateError(
          'Source drift detected for ${edit.entryId} in $relativePath at '
          '${edit.startOffset}-${edit.endOffset}. Expected snippet no longer '
          'matches current file content. Reload workspace, review diff, and '
          're-apply edits before exporting.\n'
          'Expected: "$expectedPreview"\n'
          'Actual:   "$actualPreview"',
        );
      }

      previousEnd = edit.endOffset;
    }
  }

  String _previewForError(String value) {
    final singleLine = value.replaceAll('\r\n', '\n').replaceAll('\n', r'\n');
    const maxLength = 120;
    if (singleLine.length <= maxLength) {
      return singleLine;
    }
    return '${singleLine.substring(0, maxLength)}...';
  }

  List<_ResolvedEdit> _buildEditsForEntry(
    ColliderEntry current,
    ColliderEntry baseline,
  ) {
    final edits = <_ResolvedEdit>[];
    if (_colliderChanged(current, baseline)) {
      edits.add(
        _ResolvedEdit(
          entryId: current.id,
          sourcePath: baseline.sourceBinding.sourcePath,
          startOffset: baseline.sourceBinding.startOffset,
          endOffset: baseline.sourceBinding.endOffset,
          beforeSnippet: baseline.sourceBinding.sourceSnippet,
          afterSnippet: _buildReplacementSnippet(current),
        ),
      );
    }

    final currentReference = current.referenceVisual;
    final baselineReference = baseline.referenceVisual;
    if (currentReference == null || baselineReference == null) {
      return edits;
    }

    if (!_nullableAlmostEqual(
      currentReference.renderScale,
      baselineReference.renderScale,
    )) {
      final binding = baselineReference.renderScaleBinding;
      final value = currentReference.renderScale;
      if (binding == null || value == null) {
        throw StateError(
          'Entry ${current.id} renderScale changed but no writable source binding exists.',
        );
      }
      edits.add(
        _ResolvedEdit(
          entryId: current.id,
          sourcePath: binding.sourcePath,
          startOffset: binding.startOffset,
          endOffset: binding.endOffset,
          beforeSnippet: binding.sourceSnippet,
          afterSnippet: _formatDoubleLiteral(value),
        ),
      );
    }

    if (!_nullableAlmostEqual(
          currentReference.anchorXPx,
          baselineReference.anchorXPx,
        ) ||
        !_nullableAlmostEqual(
          currentReference.anchorYPx,
          baselineReference.anchorYPx,
        )) {
      final binding = baselineReference.anchorBinding;
      final anchorX = currentReference.anchorXPx;
      final anchorY = currentReference.anchorYPx;
      if (binding == null || anchorX == null || anchorY == null) {
        throw StateError(
          'Entry ${current.id} anchorInFramePx changed but no writable source binding exists.',
        );
      }
      edits.add(
        _ResolvedEdit(
          entryId: current.id,
          sourcePath: binding.sourcePath,
          startOffset: binding.startOffset,
          endOffset: binding.endOffset,
          beforeSnippet: binding.sourceSnippet,
          afterSnippet:
              'Vec2(${_formatDoubleLiteral(anchorX)}, ${_formatDoubleLiteral(anchorY)})',
        ),
      );
    }

    return edits;
  }

  bool _colliderChanged(ColliderEntry current, ColliderEntry baseline) {
    return !_almostEqual(current.halfX, baseline.halfX) ||
        !_almostEqual(current.halfY, baseline.halfY) ||
        !_almostEqual(current.offsetX, baseline.offsetX) ||
        !_almostEqual(current.offsetY, baseline.offsetY);
  }

  bool _isChanged(ColliderEntry current, ColliderEntry baseline) {
    return _colliderChanged(current, baseline) ||
        _referenceChanged(current.referenceVisual, baseline.referenceVisual);
  }

  bool _referenceChanged(
    ColliderReferenceVisual? current,
    ColliderReferenceVisual? baseline,
  ) {
    if (current == null && baseline == null) {
      return false;
    }
    if (current == null || baseline == null) {
      return true;
    }
    return !_nullableAlmostEqual(current.anchorXPx, baseline.anchorXPx) ||
        !_nullableAlmostEqual(current.anchorYPx, baseline.anchorYPx) ||
        !_nullableAlmostEqual(current.renderScale, baseline.renderScale);
  }

  bool _nullableAlmostEqual(double? a, double? b) {
    if (a == null || b == null) {
      return a == b;
    }
    return _almostEqual(a, b);
  }

  bool _almostEqual(double a, double b) => (a - b).abs() <= _changeEpsilon;

  String _buildReplacementSnippet(ColliderEntry entry) {
    switch (entry.sourceBinding.kind) {
      case ColliderSourceBindingKind.enemyColliderAabbExpression:
        return _enemyColliderSnippet(entry);
      case ColliderSourceBindingKind.playerColliderArgs:
        return _playerColliderSnippet(entry);
      case ColliderSourceBindingKind.projectileColliderArgs:
        return _projectileColliderSnippet(entry);
      case ColliderSourceBindingKind.referenceAnchorVec2Expression:
      case ColliderSourceBindingKind.referenceRenderScaleScalar:
        throw StateError(
          'Unsupported collider snippet binding kind: ${entry.sourceBinding.kind}',
        );
    }
  }

  String _enemyColliderSnippet(ColliderEntry entry) {
    return 'ColliderAabbDef('
        'halfX: ${_formatDoubleLiteral(entry.halfX)}, '
        'halfY: ${_formatDoubleLiteral(entry.halfY)}, '
        'offsetX: ${_formatDoubleLiteral(entry.offsetX)}, '
        'offsetY: ${_formatDoubleLiteral(entry.offsetY)})';
  }

  String _playerColliderSnippet(ColliderEntry entry) {
    final width = entry.halfX * 2;
    final height = entry.halfY * 2;
    return 'colliderWidth: ${_formatDoubleLiteral(width)},\n'
        '  colliderHeight: ${_formatDoubleLiteral(height)},\n'
        '  colliderOffsetX: ${_formatDoubleLiteral(entry.offsetX)},\n'
        '  colliderOffsetY: ${_formatDoubleLiteral(entry.offsetY)},';
  }

  String _projectileColliderSnippet(ColliderEntry entry) {
    final sizeX = entry.halfX * 2;
    final sizeY = entry.halfY * 2;
    return 'colliderSizeX: ${_formatDoubleLiteral(sizeX)},\n'
        '          colliderSizeY: ${_formatDoubleLiteral(sizeY)},';
  }

  String _formatDoubleLiteral(double value) {
    final fixed = value.toStringAsFixed(4);
    var trimmed = fixed.replaceFirst(RegExp(r'0+$'), '');
    trimmed = trimmed.replaceFirst(RegExp(r'\.$'), '');
    if (!trimmed.contains('.')) {
      return '$trimmed.0';
    }
    return trimmed;
  }

  String _buildSummary({
    required ExportMode mode,
    required List<ColliderEntry> changedEntries,
    required List<_ResolvedFilePatch> filePatches,
  }) {
    final lines = <String>[
      '# Collider Export',
      '',
      'mode: ${mode.name}',
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
      '# Collider Backup Files',
      '',
      'Backup files were written before direct write apply.',
      '',
      ...backupPaths.map((path) => '- $path'),
    ];
    return lines.join('\n');
  }

  String _buildPatchArtifact(_ResolvedFilePatch patch) {
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

  String _buildUnifiedDiffArtifact(List<_ResolvedFilePatch> filePatches) {
    final sections = filePatches.map(_buildUnifiedDiffForFile).toList();
    return sections.join('\n');
  }

  String _buildUnifiedDiffForFile(_ResolvedFilePatch patch) {
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

  String _toPatchPath(String relativePath) =>
      relativePath.replaceAll('\\', '/');

  List<String> _splitLinesForDiff(String content) {
    final normalized = content.replaceAll('\r\n', '\n');
    final lines = normalized.split('\n');
    if (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }
    return lines;
  }

  List<_DiffLineOp> _buildLineDiff(
    List<String> oldLines,
    List<String> newLines,
  ) {
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

  ColliderDocument _asColliderDocument(AuthoringDocument document) {
    if (document is! ColliderDocument) {
      throw StateError(
        'ColliderDomainPlugin expected ColliderDocument but got '
        '${document.runtimeType}.',
      );
    }
    return document;
  }
}

class _ResolvedEdit {
  const _ResolvedEdit({
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

class _ResolvedFilePatch {
  const _ResolvedFilePatch({
    required this.relativePath,
    required this.originalContent,
    required this.patchedContent,
    required this.edits,
  });

  final String relativePath;
  final String originalContent;
  final String patchedContent;
  final List<_ResolvedEdit> edits;
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
