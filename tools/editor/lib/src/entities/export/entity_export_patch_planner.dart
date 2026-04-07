// Patch planning for source-backed entity export.
//
// This file converts dirty document entries into exact text replacements and
// fails fast when export would require guessing, conflicting edits, or writing
// against drifted source.
part of '../entity_export_pipeline.dart';

// Pending preview and direct export must share one planner so the session does
// not surface "safe" changes that the writer cannot actually apply.
_EntityExportPlan _buildPlan(
  EntityDocumentPipeline documentPipeline,
  EditorWorkspace workspace, {
  required EntityDocument document,
}) {
  final changedEntries = documentPipeline.changedEntries(document);
  if (changedEntries.isEmpty) {
    return const _EntityExportPlan.empty();
  }

  final filePatches = _resolveFilePatches(
    workspace,
    document: document,
    changedEntries: changedEntries,
  );
  return _EntityExportPlan(
    changedEntries: changedEntries,
    filePatches: filePatches,
  );
}

List<_EntityFilePatch> _resolveFilePatches(
  EditorWorkspace workspace, {
  required EntityDocument document,
  required List<EntityEntry> changedEntries,
}) {
  final editsByPath = <String, List<_EntitySourceEdit>>{};

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
        () => <_EntitySourceEdit>[],
      );
      _addEditOrFail(bucket, edit);
    }
  }

  final patches = <_EntityFilePatch>[];
  for (final entry in editsByPath.entries) {
    final relativePath = p.normalize(entry.key);
    final file = File(workspace.resolve(relativePath));
    if (!file.existsSync()) {
      throw StateError('Cannot export; source file missing: $relativePath');
    }

    final original = file.readAsStringSync();
    final edits = List<_EntitySourceEdit>.from(entry.value)
      ..sort((a, b) => a.startOffset.compareTo(b.startOffset));

    _validateEditsAgainstSource(relativePath, original, edits);

    var patched = original;
    // Apply from the end of the file toward the start so earlier offsets stay
    // valid for the remaining replacements.
    final descending = edits.reversed.toList(growable: false);
    for (final edit in descending) {
      patched = patched.replaceRange(
        edit.startOffset,
        edit.endOffset,
        edit.afterSnippet,
      );
    }

    patches.add(
      _EntityFilePatch(
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

void _addEditOrFail(
  List<_EntitySourceEdit> edits,
  _EntitySourceEdit candidate,
) {
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

void _validateEditsAgainstSource(
  String relativePath,
  String content,
  List<_EntitySourceEdit> edits,
) {
  // Export never rewrites "best effort" ranges. Every planned edit must still
  // match the exact snippet captured at load time.
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

List<_EntitySourceEdit> _buildEditsForEntry(
  EntityEntry current,
  EntityEntry baseline,
) {
  final edits = <_EntitySourceEdit>[];
  if (_entityBoundsChanged(current, baseline)) {
    edits.add(
      _EntitySourceEdit(
        entryId: current.id,
        sourcePath: baseline.sourceBinding.sourcePath,
        startOffset: baseline.sourceBinding.startOffset,
        endOffset: baseline.sourceBinding.endOffset,
        beforeSnippet: baseline.sourceBinding.sourceSnippet,
        afterSnippet: _buildReplacementSnippet(current),
      ),
    );
  }

  if (!_nullableAlmostEqual(
    current.castOriginOffset,
    baseline.castOriginOffset,
  )) {
    final binding = baseline.castOriginOffsetBinding;
    final value = current.castOriginOffset;
    if (binding == null || value == null) {
      throw StateError(
        'Entry ${current.id} castOriginOffset changed but no writable '
        'source binding exists.',
      );
    }
    edits.add(
      _EntitySourceEdit(
        entryId: current.id,
        sourcePath: binding.sourcePath,
        startOffset: binding.startOffset,
        endOffset: binding.endOffset,
        beforeSnippet: binding.sourceSnippet,
        afterSnippet: _formatDoubleLiteral(value),
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
        'Entry ${current.id} renderScale changed but no writable source '
        'binding exists.',
      );
    }
    edits.add(
      _EntitySourceEdit(
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
    final anchorX = currentReference.anchorXPx;
    final anchorY = currentReference.anchorYPx;
    final anchorXBinding = baselineReference.anchorXWriteBinding;
    final anchorYBinding = baselineReference.anchorYWriteBinding;
    if (anchorXBinding == null ||
        anchorYBinding == null ||
        anchorX == null ||
        anchorY == null) {
      throw StateError(
        'Entry ${current.id} anchorPoint changed but no writable source '
        'binding exists.',
      );
    }
    edits.add(
      _buildExpressionRewriteEdit(
        entryId: current.id,
        fieldLabel: 'anchorPoint.x',
        binding: anchorXBinding,
        nextValue: anchorX,
      ),
    );
    edits.add(
      _buildExpressionRewriteEdit(
        entryId: current.id,
        fieldLabel: 'anchorPoint.y',
        binding: anchorYBinding,
        nextValue: anchorY,
      ),
    );
  }

  return edits;
}

_EntitySourceEdit _buildExpressionRewriteEdit({
  required String entryId,
  required String fieldLabel,
  required EntityExpressionRewriteBinding binding,
  required double nextValue,
}) {
  // Expression-preserving edits only touch the scalar operand when the parser
  // proved that doing so keeps the original source shape meaningful.
  final targetBinding = switch (binding.mode) {
    EntityExpressionRewriteMode.replaceExpression => binding.expressionBinding,
    EntityExpressionRewriteMode.multiplyByScalar ||
    EntityExpressionRewriteMode.divideByScalar ||
    EntityExpressionRewriteMode.scalarDividedByValue =>
      binding.scalarBinding ??
          (throw StateError(
            'Entry $entryId $fieldLabel is missing its scalar source binding.',
          )),
  };

  final replacement = switch (binding.mode) {
    EntityExpressionRewriteMode.replaceExpression => _formatDoubleLiteral(
      nextValue,
    ),
    EntityExpressionRewriteMode.multiplyByScalar => _rewriteMultiplierScalar(
      entryId: entryId,
      fieldLabel: fieldLabel,
      nextValue: nextValue,
      binding: binding,
    ),
    EntityExpressionRewriteMode.divideByScalar => _rewriteDivisorScalar(
      entryId: entryId,
      fieldLabel: fieldLabel,
      nextValue: nextValue,
      binding: binding,
    ),
    EntityExpressionRewriteMode.scalarDividedByValue => _rewriteDividendScalar(
      entryId: entryId,
      fieldLabel: fieldLabel,
      nextValue: nextValue,
      binding: binding,
    ),
  };

  return _EntitySourceEdit(
    entryId: entryId,
    sourcePath: targetBinding.sourcePath,
    startOffset: targetBinding.startOffset,
    endOffset: targetBinding.endOffset,
    beforeSnippet: targetBinding.sourceSnippet,
    afterSnippet: replacement,
  );
}

String _rewriteMultiplierScalar({
  required String entryId,
  required String fieldLabel,
  required double nextValue,
  required EntityExpressionRewriteBinding binding,
}) {
  final basisValue = _requireRewriteBasis(
    entryId: entryId,
    fieldLabel: fieldLabel,
    binding: binding,
  );
  if (basisValue.abs() <= EntityDocumentPipeline.changeEpsilon) {
    throw StateError(
      'Entry $entryId $fieldLabel cannot preserve its expression because the '
      'multiplicative basis resolves to zero.',
    );
  }
  return _formatFiniteDoubleLiteral(nextValue / basisValue);
}

String _rewriteDivisorScalar({
  required String entryId,
  required String fieldLabel,
  required double nextValue,
  required EntityExpressionRewriteBinding binding,
}) {
  final basisValue = _requireRewriteBasis(
    entryId: entryId,
    fieldLabel: fieldLabel,
    binding: binding,
  );
  if (nextValue.abs() <= EntityDocumentPipeline.changeEpsilon) {
    throw StateError(
      'Entry $entryId $fieldLabel cannot preserve a division-based '
      'expression when the edited value is zero.',
    );
  }
  return _formatFiniteDoubleLiteral(basisValue / nextValue);
}

String _rewriteDividendScalar({
  required String entryId,
  required String fieldLabel,
  required double nextValue,
  required EntityExpressionRewriteBinding binding,
}) {
  final basisValue = _requireRewriteBasis(
    entryId: entryId,
    fieldLabel: fieldLabel,
    binding: binding,
  );
  return _formatFiniteDoubleLiteral(nextValue * basisValue);
}

double _requireRewriteBasis({
  required String entryId,
  required String fieldLabel,
  required EntityExpressionRewriteBinding binding,
}) {
  final basisValue = binding.basisValue;
  if (basisValue == null || !basisValue.isFinite) {
    throw StateError(
      'Entry $entryId $fieldLabel is missing a finite rewrite basis value.',
    );
  }
  return basisValue;
}

bool _entityBoundsChanged(EntityEntry current, EntityEntry baseline) {
  return !_almostEqual(current.halfX, baseline.halfX) ||
      !_almostEqual(current.halfY, baseline.halfY) ||
      !_almostEqual(current.offsetX, baseline.offsetX) ||
      !_almostEqual(current.offsetY, baseline.offsetY);
}

bool _nullableAlmostEqual(double? a, double? b) {
  if (a == null || b == null) {
    return a == b;
  }
  return _almostEqual(a, b);
}

bool _almostEqual(double a, double b) =>
    (a - b).abs() <= EntityDocumentPipeline.changeEpsilon;

String _buildReplacementSnippet(EntityEntry entry) {
  switch (entry.sourceBinding.kind) {
    case EntitySourceBindingKind.enemyAabbExpression:
      return _enemyEntitySnippet(entry);
    case EntitySourceBindingKind.playerArgs:
      return _playerEntitySnippet(entry);
    case EntitySourceBindingKind.projectileArgs:
      return _projectileEntitySnippet(entry);
    case EntitySourceBindingKind.castOriginOffsetScalar:
    case EntitySourceBindingKind.referenceAnchorVec2Expression:
    case EntitySourceBindingKind.referenceRenderScaleScalar:
      throw StateError(
        'Unsupported entity snippet binding kind: ${entry.sourceBinding.kind}',
      );
  }
}

String _enemyEntitySnippet(EntityEntry entry) {
  return 'ColliderAabbDef('
      'halfX: ${_formatDoubleLiteral(entry.halfX)}, '
      'halfY: ${_formatDoubleLiteral(entry.halfY)}, '
      'offsetX: ${_formatDoubleLiteral(entry.offsetX)}, '
      'offsetY: ${_formatDoubleLiteral(entry.offsetY)})';
}

String _playerEntitySnippet(EntityEntry entry) {
  final width = entry.halfX * 2;
  final height = entry.halfY * 2;
  return 'colliderWidth: ${_formatDoubleLiteral(width)},\n'
      '  colliderHeight: ${_formatDoubleLiteral(height)},\n'
      '  colliderOffsetX: ${_formatDoubleLiteral(entry.offsetX)},\n'
      '  colliderOffsetY: ${_formatDoubleLiteral(entry.offsetY)}';
}

String _projectileEntitySnippet(EntityEntry entry) {
  final sizeX = entry.halfX * 2;
  final sizeY = entry.halfY * 2;
  return 'colliderSizeX: ${_formatDoubleLiteral(sizeX)},\n'
      '          colliderSizeY: ${_formatDoubleLiteral(sizeY)}';
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

String _formatFiniteDoubleLiteral(double value) {
  if (!value.isFinite) {
    throw StateError('Cannot write a non-finite numeric literal ($value).');
  }
  return _formatDoubleLiteral(value);
}
