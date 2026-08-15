// In-memory document rules for the entities workflow.
//
// This file owns everything the editor can decide without touching repo files:
// validation, scene ordering, edit application, and dirty detection against
// the loaded baseline snapshot.
import '../domain/authoring_types.dart';
import 'entity_change_policy.dart';
import 'entity_domain_models.dart';
import 'entity_update.dart';

/// Owns immutable in-memory entity document behavior.
///
/// This keeps validation, scene projection, dirty detection, and committed edit
/// application together so the plugin can remain a thin orchestrator over the
/// entities workflow.
class EntityDocumentPipeline {
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
      if (entry.entityType != EntityType.projectile &&
          entry.halfX.isFinite &&
          entry.halfY.isFinite &&
          entry.halfX > 0 &&
          entry.halfY > 0 &&
          entry.halfY < entry.halfX) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'invalid_actor_capsule_dimensions',
            message:
                '${entry.id} requires halfY >= halfX so its upright capsule '
                'fits the authored bounds.',
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
      availableAssetPaths: document.availableAssetPaths,
    );
  }

  /// Applies one committed editor command to the immutable document snapshot.
  ///
  /// Unknown commands or no-op payloads return the original document so the
  /// session controller does not accumulate fake undo history.
  EntityDocument applyEdit(EntityDocument document, AuthoringCommand command) {
    final update = EntityUpdate.decode(command);
    if (update == null) return document;

    EntityEntry? currentEntry;
    for (final entry in document.entries) {
      if (entry.id == update.entryId) {
        currentEntry = entry;
        break;
      }
    }
    if (currentEntry == null) {
      throw ArgumentError.value(
        update.entryId,
        'update.entryId',
        'Entity update target does not exist in the loaded document.',
      );
    }
    update.validateFor(currentEntry);

    final currentReference = currentEntry.referenceVisual;
    final nextAnchorXPx = update.anchorXPx ?? currentReference?.anchorXPx;
    final nextAnchorYPx = update.anchorYPx ?? currentReference?.anchorYPx;
    final nextRenderScale = update.renderScale ?? currentReference?.renderScale;
    final nextCastOriginOffset =
        update.castOriginOffset ?? currentEntry.castOriginOffset;
    final nextReference = currentReference?.copyWith(
      anchorXPx: nextAnchorXPx,
      anchorYPx: nextAnchorYPx,
      renderScale: nextRenderScale,
    );
    final updatedEntry = currentEntry.copyWith(
      halfX: update.halfX,
      halfY: update.halfY,
      offsetX: update.offsetX,
      offsetY: update.offsetY,
      castOriginOffset: nextCastOriginOffset,
      referenceVisual: nextReference,
    );

    if (!changeSet(updatedEntry, currentEntry).hasChanges) {
      return document;
    }

    final updatedEntries = document.entries
        .map((entry) {
          if (entry.id != update.entryId) {
            return entry;
          }
          return updatedEntry;
        })
        .toList(growable: false);

    return EntityDocument(
      entries: updatedEntries,
      baselineById: document.baselineById,
      runtimeGridCellSize: document.runtimeGridCellSize,
      availableAssetPaths: document.availableAssetPaths,
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
      if (baseline == null || changeSet(entry, baseline).hasChanges) {
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

  /// Returns the canonical editable-field delta for two matching entries.
  EntityChangeSet changeSet(EntityEntry current, EntityEntry baseline) =>
      EntityChangePolicy.between(current, baseline);
}
