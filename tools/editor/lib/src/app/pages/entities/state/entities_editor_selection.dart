part of '../entities_editor_page.dart';

/// Selection/filter/reconciliation logic for the entities page.
///
/// This extension owns how controller snapshots map to local UI selection and
/// inspector draft projection. It does not export/write data directly.
extension _EntitiesEditorSelection on _EntitiesEditorPageState {
  /// Applies the active list filters in a deterministic order:
  /// type -> dirty -> text query.
  List<EntityEntry> _filteredEntries(List<EntityEntry> entries) {
    final query = _searchQuery;
    return entries
        .where((entry) {
          if (_entityTypeFilter != null &&
              entry.entityType != _entityTypeFilter) {
            return false;
          }
          if (_showDirtyOnly &&
              !widget.controller.dirtyItemIds.contains(entry.id)) {
            return false;
          }
          if (query.isEmpty) {
            return true;
          }
          final haystack = '${entry.id} ${entry.label} ${entry.sourcePath}'
              .toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  void _handleControllerChanged() {
    if (!mounted) {
      return;
    }
    if (!_reconcileSelectionsFromCurrentState()) {
      return;
    }
    _updateState(() {});
  }

  bool _reconcileSelectionsFromCurrentState() {
    // Keep all visible selection surfaces coherent with the latest controller
    // snapshot in one pass (entry, diff, artifact).
    final scene = widget.controller.scene;
    final entityScene = scene is EntityScene ? scene : null;
    final visibleEntries = entityScene == null
        ? const <EntityEntry>[]
        : _filteredEntries(entityScene.entries);
    final selectionChanged = _ensureSelection(entityScene, visibleEntries);
    final diffSelectionChanged = _ensureDiffSelection(
      widget.controller.pendingChanges,
    );
    final artifactSelectionChanged = _ensureArtifactSelection(
      widget.controller.lastExportResult,
    );
    _ensureCurrentReferenceImageLoaded();
    return selectionChanged || diffSelectionChanged || artifactSelectionChanged;
  }

  void _selectEntryById(EntityScene scene, String entryId) {
    EntityEntry? entry;
    for (final candidate in scene.entries) {
      if (candidate.id == entryId) {
        entry = candidate;
        break;
      }
    }
    if (entry == null) {
      return;
    }
    final selectedEntry = entry;

    _updateState(() {
      _resetViewportSelectionState();
      _selectedEntryId = selectedEntry.id;
      _syncInspectorFromEntry(selectedEntry);
    });
    _ensureCurrentReferenceImageLoaded();
  }

  void _resetViewportSelectionState() {
    // Selection change resets viewport-local interaction state so new entries
    // start from a predictable scene view and drag state.
    _sceneAnimKey = null;
    _sceneAnimFrameIndex = 0;
    _sceneCtrlPanActive = false;
    _sceneHandleDrag = null;
    _scheduleSceneViewportCentering();
  }

  bool _ensureSelection(EntityScene? scene, List<EntityEntry> visibleEntries) {
    if (scene == null || visibleEntries.isEmpty) {
      final hadSelection = _selectedEntryId != null;
      if (hadSelection) {
        _resetViewportSelectionState();
      }
      _selectedEntryId = null;
      _syncInspectorFromEntry(null);
      return hadSelection;
    }

    EntityEntry? selectedEntry;
    final selectedStillValid = visibleEntries.any((entry) {
      if (entry.id != _selectedEntryId) {
        return false;
      }
      selectedEntry = entry;
      return true;
    });
    if (selectedStillValid) {
      final resolvedSelectedEntry = selectedEntry;
      // Preserve in-progress text edits: controller notifications should not
      // overwrite local draft fields while the user is editing.
      if (resolvedSelectedEntry != null && !hasLocalDraftChanges) {
        _syncInspectorFromEntry(resolvedSelectedEntry);
      }
      return false;
    }

    _resetViewportSelectionState();
    _selectedEntryId = visibleEntries.first.id;
    _syncInspectorFromEntry(visibleEntries.first);
    return true;
  }

  bool _ensureDiffSelection(PendingChanges pendingChanges) {
    final previousSelection = _selectedDiffPath;
    if (pendingChanges.fileDiffs.isEmpty) {
      _selectedDiffPath = null;
      return previousSelection != _selectedDiffPath;
    }

    final selectedStillValid = pendingChanges.fileDiffs.any(
      (diff) => diff.relativePath == _selectedDiffPath,
    );
    if (selectedStillValid) {
      return previousSelection != _selectedDiffPath;
    }
    _selectedDiffPath = pendingChanges.fileDiffs.first.relativePath;
    return previousSelection != _selectedDiffPath;
  }

  PendingFileDiff? _selectedDiff(PendingChanges pendingChanges) {
    final selectedPath = _selectedDiffPath;
    if (selectedPath == null) {
      return pendingChanges.fileDiffs.isEmpty
          ? null
          : pendingChanges.fileDiffs.first;
    }
    for (final diff in pendingChanges.fileDiffs) {
      if (diff.relativePath == selectedPath) {
        return diff;
      }
    }
    return pendingChanges.fileDiffs.isEmpty
        ? null
        : pendingChanges.fileDiffs.first;
  }

  bool _ensureArtifactSelection(ExportResult? exportResult) {
    final previousSelection = _selectedArtifactTitle;
    final artifacts = exportResult?.artifacts;
    if (artifacts == null || artifacts.isEmpty) {
      _selectedArtifactTitle = null;
      return previousSelection != _selectedArtifactTitle;
    }

    final selectedStillValid = artifacts.any(
      (artifact) => artifact.title == _selectedArtifactTitle,
    );
    if (selectedStillValid) {
      return previousSelection != _selectedArtifactTitle;
    }
    _selectedArtifactTitle = artifacts.first.title;
    return previousSelection != _selectedArtifactTitle;
  }

  ExportArtifact? _selectedArtifact(ExportResult? exportResult) {
    final artifacts = exportResult?.artifacts;
    if (artifacts == null || artifacts.isEmpty) {
      return null;
    }
    final selectedTitle = _selectedArtifactTitle;
    if (selectedTitle == null) {
      return artifacts.first;
    }
    for (final artifact in artifacts) {
      if (artifact.title == selectedTitle) {
        return artifact;
      }
    }
    return artifacts.first;
  }

  EntityEntry? _selectedEntry(EntityScene scene) {
    final selectedId = _selectedEntryId;
    if (selectedId == null) {
      return null;
    }
    for (final entry in scene.entries) {
      if (entry.id == selectedId) {
        return entry;
      }
    }
    return null;
  }

  void _syncInspectorFromEntry(EntityEntry? entry) {
    if (entry == null) {
      _halfXController.text = '';
      _halfYController.text = '';
      _offsetXController.text = '';
      _offsetYController.text = '';
      _renderScaleController.text = '';
      _anchorXPxController.text = '';
      _anchorYPxController.text = '';
      _frameWidthController.text = '';
      _frameHeightController.text = '';
      _castOriginOffsetController.text = '';
      return;
    }

    _syncInspectorFromValues(
      halfX: entry.halfX,
      halfY: entry.halfY,
      offsetX: entry.offsetX,
      offsetY: entry.offsetY,
    );
    final reference = entry.referenceVisual;
    _renderScaleController.text =
        reference?.renderScale?.toStringAsFixed(3) ?? '';
    _anchorXPxController.text = reference?.anchorXPx?.toStringAsFixed(3) ?? '';
    _anchorYPxController.text = reference?.anchorYPx?.toStringAsFixed(3) ?? '';
    _frameWidthController.text =
        reference?.frameWidth?.toStringAsFixed(3) ?? '';
    _frameHeightController.text =
        reference?.frameHeight?.toStringAsFixed(3) ?? '';
    _castOriginOffsetController.text =
        entry.castOriginOffset?.toStringAsFixed(3) ?? '';
  }

  String _formatOptionalDouble(double? value) {
    return value?.toStringAsFixed(3) ?? '';
  }
}
