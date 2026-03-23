import 'package:flutter/foundation.dart';

import '../domain/authoring_types.dart';

enum ColliderEntityType { player, enemy, projectile }

@immutable
class ColliderReferenceVisual {
  const ColliderReferenceVisual({
    required this.assetPath,
    this.frameWidth,
    this.frameHeight,
    this.anchorXPx,
    this.anchorYPx,
    this.anchorBinding,
    this.renderScale,
    this.renderScaleBinding,
    this.defaultRow = 0,
    this.defaultFrameStart = 0,
    this.defaultFrameCount,
    this.defaultGridColumns,
    this.defaultAnimKey,
    this.animViewsByKey = const <String, ColliderReferenceAnimView>{},
  });

  final String assetPath;
  final double? frameWidth;
  final double? frameHeight;
  final double? anchorXPx;
  final double? anchorYPx;
  final ColliderSourceBinding? anchorBinding;
  final double? renderScale;
  final ColliderSourceBinding? renderScaleBinding;
  final int defaultRow;
  final int defaultFrameStart;
  final int? defaultFrameCount;
  final int? defaultGridColumns;
  final String? defaultAnimKey;
  final Map<String, ColliderReferenceAnimView> animViewsByKey;

  ColliderReferenceVisual copyWith({
    double? anchorXPx,
    double? anchorYPx,
    double? renderScale,
  }) {
    return ColliderReferenceVisual(
      assetPath: assetPath,
      frameWidth: frameWidth,
      frameHeight: frameHeight,
      anchorXPx: anchorXPx ?? this.anchorXPx,
      anchorYPx: anchorYPx ?? this.anchorYPx,
      anchorBinding: anchorBinding,
      renderScale: renderScale ?? this.renderScale,
      renderScaleBinding: renderScaleBinding,
      defaultRow: defaultRow,
      defaultFrameStart: defaultFrameStart,
      defaultFrameCount: defaultFrameCount,
      defaultGridColumns: defaultGridColumns,
      defaultAnimKey: defaultAnimKey,
      animViewsByKey: animViewsByKey,
    );
  }
}

@immutable
class ColliderReferenceAnimView {
  const ColliderReferenceAnimView({
    required this.key,
    required this.assetPath,
    this.row = 0,
    this.frameStart = 0,
    this.frameCount,
    this.gridColumns,
  });

  final String key;
  final String assetPath;
  final int row;
  final int frameStart;
  final int? frameCount;
  final int? gridColumns;
}

@immutable
class ColliderEntry {
  const ColliderEntry({
    required this.id,
    required this.label,
    required this.entityType,
    required this.halfX,
    required this.halfY,
    required this.offsetX,
    required this.offsetY,
    required this.sourcePath,
    required this.sourceBinding,
    this.referenceVisual,
  });

  final String id;
  final String label;
  final ColliderEntityType entityType;
  final double halfX;
  final double halfY;
  final double offsetX;
  final double offsetY;
  final String sourcePath;
  final ColliderSourceBinding sourceBinding;
  final ColliderReferenceVisual? referenceVisual;

  ColliderEntry copyWith({
    double? halfX,
    double? halfY,
    double? offsetX,
    double? offsetY,
    ColliderReferenceVisual? referenceVisual,
  }) {
    return ColliderEntry(
      id: id,
      label: label,
      entityType: entityType,
      halfX: halfX ?? this.halfX,
      halfY: halfY ?? this.halfY,
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
      sourcePath: sourcePath,
      sourceBinding: sourceBinding,
      referenceVisual: referenceVisual ?? this.referenceVisual,
    );
  }
}

class ColliderDocument extends AuthoringDocument {
  const ColliderDocument({
    required this.entries,
    required this.baselineById,
    required this.runtimeGridCellSize,
    this.loadIssues = const <ValidationIssue>[],
  });

  final List<ColliderEntry> entries;
  final Map<String, ColliderEntry> baselineById;
  final double runtimeGridCellSize;
  final List<ValidationIssue> loadIssues;
}

class ColliderScene extends EditableScene {
  const ColliderScene({
    required this.entries,
    required this.runtimeGridCellSize,
  });

  final List<ColliderEntry> entries;
  final double runtimeGridCellSize;
}

enum ColliderSourceBindingKind {
  enemyColliderAabbExpression,
  playerColliderArgs,
  projectileColliderArgs,
  referenceAnchorVec2Expression,
  referenceRenderScaleScalar,
}

@immutable
class ColliderSourceBinding {
  const ColliderSourceBinding({
    required this.kind,
    required this.sourcePath,
    required this.startOffset,
    required this.endOffset,
    required this.sourceSnippet,
  });

  final ColliderSourceBindingKind kind;
  final String sourcePath;
  final int startOffset;
  final int endOffset;
  final String sourceSnippet;
}
