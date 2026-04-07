// In-memory document rules for the entities workflow.
//
// This file owns everything the editor can decide without touching repo files:
// validation, scene ordering, edit application, and dirty detection against
// the loaded baseline snapshot.
import '../domain/authoring_types.dart';
import 'entity_domain_models.dart';

/// Owns immutable in-memory entity document behavior.
///
/// This keeps validation, scene projection, dirty detection, and committed edit
/// application together so the plugin can remain a thin orchestrator over the
/// entities workflow.
class EntityDocumentPipeline {
  /// Numeric tolerance used when comparing editor-authored doubles.
  ///
  /// Text fields, round-tripped literals, and simple derived values should not
  /// cause noisy dirty-state churn when they differ only by formatting-scale
  /// precision.
  static const double changeEpsilon = 0.000001;

  /// Validates one loaded entity document without mutating it.
  ///
  /// Parser/load issues are preserved and returned alongside editor-side
  /// numeric validation so export gating stays strict even when a document is
  /// only partially readable.
  List<ValidationIssue> validate(EntityDocument document) {
    final issues = <ValidationIssue>[...document.loadIssues];

    for (final entry in document.entries) {
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

      final castOriginOffset = entry.castOriginOffset;
      if (castOriginOffset != null && !castOriginOffset.isFinite) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'invalid_cast_origin_offset',
            message:
                '${entry.id} has invalid castOriginOffset ($castOriginOffset)',
            sourcePath:
                entry.castOriginOffsetBinding?.sourcePath ?? entry.sourcePath,
          ),
        );
      }

      final reference = entry.referenceVisual;
      if (reference == null) {
        continue;
      }

      final renderScale = reference.renderScale;
      if (renderScale != null && (!renderScale.isFinite || renderScale <= 0)) {
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
            message: '${entry.id} has invalid anchorPoint ($anchorX, $anchorY)',
            sourcePath: reference.anchorBinding?.sourcePath,
          ),
        );
      }
    }

    return issues;
  }

  /// Projects the current document into stable scene order for the route UI.
  ///
  /// Entries are sorted by type then id so selection lists, inspectors, and
  /// scene overlays stay deterministic across reloads.
  EntityScene buildScene(EntityDocument document) {
    final sorted = List<EntityEntry>.from(document.entries)
      ..sort((a, b) {
        final typeCompare = a.entityType.index.compareTo(b.entityType.index);
        if (typeCompare != 0) {
          return typeCompare;
        }
        return a.id.compareTo(b.id);
      });
    return EntityScene(
      entries: sorted,
      runtimeGridCellSize: document.runtimeGridCellSize,
    );
  }

  /// Applies one committed editor command to the immutable document snapshot.
  ///
  /// Unknown commands or no-op payloads return the original document so the
  /// session controller does not accumulate fake undo history.
  EntityDocument applyEdit(EntityDocument document, AuthoringCommand command) {
    if (command.kind != 'update_entry') {
      return document;
    }

    final targetId = command.payload['id'];
    if (targetId is! String) {
      return document;
    }

    EntityEntry? currentEntry;
    for (final entry in document.entries) {
      if (entry.id == targetId) {
        currentEntry = entry;
        break;
      }
    }
    if (currentEntry == null) {
      return document;
    }

    final halfX = command.payload['halfX'];
    final halfY = command.payload['halfY'];
    final offsetX = command.payload['offsetX'];
    final offsetY = command.payload['offsetY'];
    final anchorXPx = command.payload['anchorXPx'];
    final anchorYPx = command.payload['anchorYPx'];
    final renderScale = command.payload['renderScale'];
    final castOriginOffset = command.payload['castOriginOffset'];

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
    final nextCastOriginOffset = castOriginOffset is num
        ? castOriginOffset.toDouble()
        : currentEntry.castOriginOffset;
    final nextReference = currentReference?.copyWith(
      anchorXPx: nextAnchorXPx,
      anchorYPx: nextAnchorYPx,
      renderScale: nextRenderScale,
    );

    if (_almostEqual(nextHalfX, currentEntry.halfX) &&
        _almostEqual(nextHalfY, currentEntry.halfY) &&
        _almostEqual(nextOffsetX, currentEntry.offsetX) &&
        _almostEqual(nextOffsetY, currentEntry.offsetY) &&
        _nullableAlmostEqual(
          nextCastOriginOffset,
          currentEntry.castOriginOffset,
        ) &&
        !_referenceChanged(nextReference, currentReference)) {
      return document;
    }

    final updatedEntries = document.entries
        .map((entry) {
          if (entry.id != targetId) {
            return entry;
          }
          return entry.copyWith(
            halfX: nextHalfX,
            halfY: nextHalfY,
            offsetX: nextOffsetX,
            offsetY: nextOffsetY,
            castOriginOffset: nextCastOriginOffset,
            referenceVisual: nextReference,
          );
        })
        .toList(growable: false);

    return EntityDocument(
      entries: updatedEntries,
      baselineById: document.baselineById,
      runtimeGridCellSize: document.runtimeGridCellSize,
      loadIssues: document.loadIssues,
    );
  }

  /// Returns every entry whose current state differs from the loaded baseline.
  ///
  /// The result is type/id sorted so pending previews and export summaries do
  /// not depend on source discovery order.
  List<EntityEntry> changedEntries(EntityDocument document) {
    final changed = <EntityEntry>[];
    for (final entry in document.entries) {
      final baseline = document.baselineById[entry.id];
      if (baseline == null || _isChanged(entry, baseline)) {
        changed.add(entry);
      }
    }
    changed.sort((a, b) {
      final typeCompare = a.entityType.index.compareTo(b.entityType.index);
      if (typeCompare != 0) {
        return typeCompare;
      }
      return a.id.compareTo(b.id);
    });
    return changed;
  }

  bool _entityBoundsChanged(EntityEntry current, EntityEntry baseline) {
    return !_almostEqual(current.halfX, baseline.halfX) ||
        !_almostEqual(current.halfY, baseline.halfY) ||
        !_almostEqual(current.offsetX, baseline.offsetX) ||
        !_almostEqual(current.offsetY, baseline.offsetY);
  }

  bool _isChanged(EntityEntry current, EntityEntry baseline) {
    return _entityBoundsChanged(current, baseline) ||
        !_nullableAlmostEqual(
          current.castOriginOffset,
          baseline.castOriginOffset,
        ) ||
        _referenceChanged(current.referenceVisual, baseline.referenceVisual);
  }

  bool _referenceChanged(
    EntityReferenceVisual? current,
    EntityReferenceVisual? baseline,
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

  bool _almostEqual(double a, double b) => (a - b).abs() <= changeEpsilon;
}
