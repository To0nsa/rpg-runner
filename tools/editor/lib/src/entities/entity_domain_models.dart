import 'package:flutter/foundation.dart';

import '../domain/authoring_types.dart';

enum EntityType { player, enemy, projectile }

@immutable
class EntityReferenceVisual {
  const EntityReferenceVisual({
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
    this.animViewsByKey = const <String, EntityReferenceAnimView>{},
  });

  final String assetPath;
  final double? frameWidth;
  final double? frameHeight;
  final double? anchorXPx;
  final double? anchorYPx;
  final EntitySourceBinding? anchorBinding;
  final double? renderScale;
  final EntitySourceBinding? renderScaleBinding;
  final int defaultRow;
  final int defaultFrameStart;
  final int? defaultFrameCount;
  final int? defaultGridColumns;
  final String? defaultAnimKey;
  final Map<String, EntityReferenceAnimView> animViewsByKey;

  EntityReferenceVisual copyWith({
    double? anchorXPx,
    double? anchorYPx,
    double? renderScale,
  }) {
    return EntityReferenceVisual(
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
class EntityReferenceAnimView {
  const EntityReferenceAnimView({
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
class EntityEntry {
  const EntityEntry({
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
  final EntityType entityType;
  final double halfX;
  final double halfY;
  final double offsetX;
  final double offsetY;
  final String sourcePath;
  final EntitySourceBinding sourceBinding;
  final EntityReferenceVisual? referenceVisual;

  EntityEntry copyWith({
    double? halfX,
    double? halfY,
    double? offsetX,
    double? offsetY,
    EntityReferenceVisual? referenceVisual,
  }) {
    return EntityEntry(
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

class EntityDocument extends AuthoringDocument {
  const EntityDocument({
    required this.entries,
    required this.baselineById,
    required this.runtimeGridCellSize,
    this.loadIssues = const <ValidationIssue>[],
  });

  final List<EntityEntry> entries;
  final Map<String, EntityEntry> baselineById;
  final double runtimeGridCellSize;
  final List<ValidationIssue> loadIssues;
}

class EntityScene extends EditableScene {
  const EntityScene({
    required this.entries,
    required this.runtimeGridCellSize,
  });

  final List<EntityEntry> entries;
  final double runtimeGridCellSize;
}

enum EntitySourceBindingKind {
  enemyAabbExpression,
  playerArgs,
  projectileArgs,
  referenceAnchorVec2Expression,
  referenceRenderScaleScalar,
}

@immutable
class EntitySourceBinding {
  const EntitySourceBinding({
    required this.kind,
    required this.sourcePath,
    required this.startOffset,
    required this.endOffset,
    required this.sourceSnippet,
  });

  final EntitySourceBindingKind kind;
  final String sourcePath;
  final int startOffset;
  final int endOffset;
  final String sourceSnippet;
}




