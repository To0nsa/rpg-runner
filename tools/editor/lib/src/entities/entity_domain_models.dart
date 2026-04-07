// Shared immutable data contracts for the entities workflow.
//
// Parser, plugin, export, tests, and UI all depend on these types. This file
// therefore owns the source-of-truth model split between repo-backed document
// state, scene-facing projection state, and exact source bindings used for
// deterministic write-back.
import 'package:flutter/foundation.dart';

import '../domain/authoring_types.dart';

/// Immutable entity-domain snapshots shared by the parser, plugin, and UI.
///
/// The important split in this file is:
/// - [EntityDocument]: authoritative plugin-owned repo snapshot with baselines
///   and load issues used for validation/export
/// - [EntityScene]: UI-facing projection derived from the current document
/// - [EntitySourceBinding]: exact source ranges that make deterministic write-
///   back and source-drift detection possible

/// Broad entity bucket used by the editor for grouping and route UI.
enum EntityType { player, enemy, projectile }

/// Runtime-facing art direction metadata surfaced for editor preview only.
enum EntityArtFacingDirection { left, right }

/// Optional render/reference metadata associated with an [EntityEntry].
///
/// This data is not a second persistence authority. It is parsed from runtime
/// source so the editor can preview anchors, animation frames, and render
/// scale while still writing back through source bindings owned by the plugin.
@immutable
class EntityReferenceVisual {
  EntityReferenceVisual({
    required this.assetPath,
    this.frameWidth,
    this.frameHeight,
    this.anchorXPx,
    this.anchorYPx,
    this.anchorBinding,
    this.anchorXWriteBinding,
    this.anchorYWriteBinding,
    this.renderScale,
    this.renderScaleBinding,
    this.defaultRow = 0,
    this.defaultFrameStart = 0,
    this.defaultFrameCount,
    this.defaultGridColumns,
    this.defaultAnimKey,
    Map<String, EntityReferenceAnimView> animViewsByKey =
        const <String, EntityReferenceAnimView>{},
  }) : animViewsByKey = Map<String, EntityReferenceAnimView>.unmodifiable(
         animViewsByKey,
       );

  final String assetPath;
  final double? frameWidth;
  final double? frameHeight;
  final double? anchorXPx;
  final double? anchorYPx;
  final EntitySourceBinding? anchorBinding;
  final EntityExpressionRewriteBinding? anchorXWriteBinding;
  final EntityExpressionRewriteBinding? anchorYWriteBinding;
  final double? renderScale;
  final EntitySourceBinding? renderScaleBinding;
  final int defaultRow;
  final int defaultFrameStart;
  final int? defaultFrameCount;
  final int? defaultGridColumns;
  final String? defaultAnimKey;
  // The map key is the authoritative animation id for this view set. The
  // constructor snapshots the map so a loaded visual stays immutable.
  final Map<String, EntityReferenceAnimView> animViewsByKey;

  /// True when both anchor axes can be written back without flattening
  /// expression-backed source into ad-hoc literals.
  bool get hasWritableAnchorPoint =>
      anchorXWriteBinding != null && anchorYWriteBinding != null;

  /// Returns a new reference visual with the subset of fields the entities
  /// route currently edits in-session.
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
      anchorXWriteBinding: anchorXWriteBinding,
      anchorYWriteBinding: anchorYWriteBinding,
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

/// How the entity exporter should update one expression-backed numeric field.
///
/// The entities workflow prefers preserving the existing source shape when a
/// numeric value lives inside a simple expression such as `frameWidth * 0.5`.
/// These bindings let export rewrite the scalar component instead of replacing
/// the entire expression with a hard-coded literal.
enum EntityExpressionRewriteMode {
  replaceExpression,
  multiplyByScalar,
  divideByScalar,
  scalarDividedByValue,
}

/// Exact write-back metadata for one resolved numeric expression.
@immutable
class EntityExpressionRewriteBinding {
  const EntityExpressionRewriteBinding({
    required this.mode,
    required this.expressionBinding,
    this.scalarBinding,
    this.basisValue,
  });

  final EntityExpressionRewriteMode mode;
  final EntitySourceBinding expressionBinding;

  /// Range for the scalar literal/operator operand the exporter may rewrite.
  ///
  /// This is only present for rewrite modes that preserve the original
  /// expression shape instead of replacing the full expression.
  final EntitySourceBinding? scalarBinding;

  /// Resolved non-literal side of the expression used to derive a new scalar.
  ///
  /// Example: for `frameWidth * 0.5`, the basis is the resolved frame width.
  final double? basisValue;
}

/// One resolved animation view inside [EntityReferenceVisual.animViewsByKey].
///
/// The surrounding map key owns the animation id; this object only carries the
/// per-view frame/grid metadata needed to resolve preview frames.
@immutable
class EntityReferenceAnimView {
  const EntityReferenceAnimView({
    required this.assetPath,
    this.row = 0,
    this.frameStart = 0,
    this.frameCount,
    this.gridColumns,
  });

  final String assetPath;
  final int row;
  final int frameStart;
  final int? frameCount;
  final int? gridColumns;
}

/// One authorable entity record in the entities domain.
///
/// This combines editable collider data with optional render preview metadata
/// and the source bindings required to write deterministic source patches back
/// to the repo.
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
    this.artFacingDirection,
    this.isCaster = false,
    this.castOriginOffset,
    this.castOriginOffsetBinding,
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
  final EntityArtFacingDirection? artFacingDirection;
  final bool isCaster;
  final double? castOriginOffset;
  final EntitySourceBinding? castOriginOffsetBinding;

  /// Returns a new entry preserving identity/source ownership while replacing
  /// the subset of values the editor is allowed to mutate.
  EntityEntry copyWith({
    double? halfX,
    double? halfY,
    double? offsetX,
    double? offsetY,
    EntityReferenceVisual? referenceVisual,
    EntityArtFacingDirection? artFacingDirection,
    bool? isCaster,
    double? castOriginOffset,
    EntitySourceBinding? castOriginOffsetBinding,
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
      artFacingDirection: artFacingDirection ?? this.artFacingDirection,
      isCaster: isCaster ?? this.isCaster,
      castOriginOffset: castOriginOffset ?? this.castOriginOffset,
      castOriginOffsetBinding:
          castOriginOffsetBinding ?? this.castOriginOffsetBinding,
    );
  }
}

/// Authoritative parsed workspace snapshot for the entities plugin.
///
/// [entries] is the current editable state. [baselineById] is the original
/// load snapshot used for pending-diff calculation and export drift checks.
/// [loadIssues] captures parser/load warnings that should stay attached to the
/// document even before plugin validation runs.
@immutable
class EntityDocument extends AuthoringDocument {
  EntityDocument({
    required List<EntityEntry> entries,
    required Map<String, EntityEntry> baselineById,
    required this.runtimeGridCellSize,
    List<ValidationIssue> loadIssues = const <ValidationIssue>[],
  }) : entries = List<EntityEntry>.unmodifiable(entries),
       baselineById = Map<String, EntityEntry>.unmodifiable(baselineById),
       loadIssues = List<ValidationIssue>.unmodifiable(loadIssues);

  // Collections are snapped on construction so the document behaves like a
  // real immutable repo snapshot once loaded.
  final List<EntityEntry> entries;
  final Map<String, EntityEntry> baselineById;

  /// Runtime broadphase grid size in world pixels.
  ///
  /// The entities scene uses this for consistent grid overlay/debug context.
  final double runtimeGridCellSize;
  final List<ValidationIssue> loadIssues;
}

/// UI-facing scene projection built from an [EntityDocument].
///
/// This keeps only the data the route needs to render and inspect entities; it
/// intentionally does not carry baseline/export concerns.
@immutable
class EntityScene extends EditableScene {
  EntityScene({
    required List<EntityEntry> entries,
    required this.runtimeGridCellSize,
  }) : entries = List<EntityEntry>.unmodifiable(entries);

  final List<EntityEntry> entries;

  /// Runtime broadphase grid size in world pixels mirrored from the document.
  final double runtimeGridCellSize;
}

/// Shape of source range the entity exporter knows how to replace.
///
/// These kinds are intentionally concrete because entity export writes back to
/// a handful of specific runtime source patterns rather than a generic file
/// format.
enum EntitySourceBindingKind {
  enemyAabbExpression,
  playerArgs,
  projectileArgs,
  castOriginOffsetScalar,
  referenceAnchorVec2Expression,
  referenceRenderScaleScalar,
}

/// Exact source range captured during parsing for deterministic write-back.
///
/// The exporter uses this to verify the original snippet is still present
/// before replacing it, which is how the entities workflow stays drift-safe.
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

  /// Inclusive start offset in the original file content used during parse.
  final int startOffset;

  /// Exclusive end offset in the original file content used during parse.
  final int endOffset;

  /// Exact source slice captured at load time for drift-safe replacement.
  final String sourceSnippet;
}
