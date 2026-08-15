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
    documentPipeline,
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
  EntityDocumentPipeline documentPipeline,
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
    final entryEdits = _buildEditsForEntry(documentPipeline, entry, baseline);
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
      throw _EntitySourceDriftException(
        'Source drift detected; source file is missing: $relativePath. '
        'Reload workspace and review pending changes.',
      );
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
      throw _EntitySourceDriftException(
        'Source drift detected for ${edit.entryId} in $relativePath; the '
        'loaded replacement range is now out of bounds. Reload workspace and '
        'review pending changes.',
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
      throw _EntitySourceDriftException(
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
  EntityDocumentPipeline documentPipeline,
  EntityEntry current,
  EntityEntry baseline,
) {
  final edits = <_EntitySourceEdit>[];
  final changes = documentPipeline.changeSet(current, baseline);
  final colliderBindings = baseline.colliderBindings;
  if (changes.halfXChanged) {
    edits.add(
      _buildColliderScalarEdit(
        entryId: current.id,
        fieldLabel: 'halfX',
        binding: colliderBindings.halfX,
        editorValue: current.halfX,
      ),
    );
  }
  if (changes.halfYChanged) {
    edits.add(
      _buildColliderScalarEdit(
        entryId: current.id,
        fieldLabel: 'halfY',
        binding: colliderBindings.halfY,
        editorValue: current.halfY,
      ),
    );
  }
  if (changes.offsetXChanged) {
    edits.add(
      _buildColliderScalarEdit(
        entryId: current.id,
        fieldLabel: 'offsetX',
        binding:
            colliderBindings.offsetX ??
            (throw StateError(
              'Entry ${current.id} offsetX changed but no writable source '
              'binding exists.',
            )),
        editorValue: current.offsetX,
      ),
    );
  }
  if (changes.offsetYChanged) {
    edits.add(
      _buildColliderScalarEdit(
        entryId: current.id,
        fieldLabel: 'offsetY',
        binding:
            colliderBindings.offsetY ??
            (throw StateError(
              'Entry ${current.id} offsetY changed but no writable source '
              'binding exists.',
            )),
        editorValue: current.offsetY,
      ),
    );
  }

  if (changes.castOriginOffsetChanged) {
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

  if (changes.renderScaleChanged) {
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

  if (changes.anchorChanged) {
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

_EntitySourceEdit _buildColliderScalarEdit({
  required String entryId,
  required String fieldLabel,
  required EntityColliderScalarBinding binding,
  required double editorValue,
}) {
  final sourceBinding = binding.sourceBinding;
  final sourceValue = binding.sourceValueFor(editorValue);
  if (!sourceValue.isFinite) {
    throw StateError(
      'Entry $entryId $fieldLabel resolves to a non-finite source value.',
    );
  }
  return _EntitySourceEdit(
    entryId: entryId,
    sourcePath: sourceBinding.sourcePath,
    startOffset: sourceBinding.startOffset,
    endOffset: sourceBinding.endOffset,
    beforeSnippet: sourceBinding.sourceSnippet,
    afterSnippet: _formatDoubleLiteral(sourceValue),
  );
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
  if (EntityNumericPolicy.isEffectivelyZero(basisValue)) {
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
  if (EntityNumericPolicy.isEffectivelyZero(nextValue)) {
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

String _formatDoubleLiteral(double value) {
  // Eight fractional digits keep expression-backed values within the shared
  // entity comparison tolerance after a write/reparse round trip.
  final fixed = value.toStringAsFixed(8);
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
