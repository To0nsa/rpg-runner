part of '../entities_editor_page.dart';

/// Inspector draft parsing + command payload construction for entity updates.
///
/// This extension validates user-entered numbers and forwards normalized update
/// commands to the session controller. It does not perform direct file writes.
extension _EntitiesEditorApply on _EntitiesEditorPageState {
  void _applyInspectorEdits(EntityEntry selectedEntry) {
    final halfX = double.tryParse(_halfXController.text.trim());
    final halfY = double.tryParse(_halfYController.text.trim());
    final offsetX = double.tryParse(_offsetXController.text.trim());
    final offsetY = double.tryParse(_offsetYController.text.trim());

    if (halfX == null || halfY == null || offsetX == null || offsetY == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All entity size/offset fields must be valid numbers.'),
        ),
      );
      return;
    }

    final reference = selectedEntry.referenceVisual;
    double? renderScale;
    double? anchorXPx;
    double? anchorYPx;
    double? castOriginOffset;
    if (reference != null) {
      if (reference.renderScaleBinding != null) {
        renderScale = double.tryParse(_renderScaleController.text.trim());
        if (renderScale == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('renderScale must be a valid number.'),
            ),
          );
          return;
        }
      }
      if (reference.hasWritableAnchorPoint) {
        anchorXPx = double.tryParse(_anchorXPxController.text.trim());
        anchorYPx = double.tryParse(_anchorYPxController.text.trim());
        if (anchorXPx == null || anchorYPx == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('anchorPoint.x/y must be valid numbers.'),
            ),
          );
          return;
        }
      }
    }
    if (selectedEntry.castOriginOffsetBinding != null) {
      castOriginOffset = double.tryParse(
        _castOriginOffsetController.text.trim(),
      );
      if (castOriginOffset == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('castOriginOffset must be a valid number.'),
          ),
        );
        return;
      }
    }

    _applyEntryValues(
      selectedEntry.id,
      halfX: halfX,
      halfY: halfY,
      offsetX: offsetX,
      offsetY: offsetY,
      renderScale: renderScale,
      anchorXPx: anchorXPx,
      anchorYPx: anchorYPx,
      castOriginOffset: castOriginOffset,
    );
  }

  void _applyEntryValues(
    String entryId, {
    required double halfX,
    required double halfY,
    required double offsetX,
    required double offsetY,
    double? renderScale,
    double? anchorXPx,
    double? anchorYPx,
    double? castOriginOffset,
  }) {
    final update = _buildEntityUpdate(
      entryId: entryId,
      halfX: halfX,
      halfY: halfY,
      offsetX: offsetX,
      offsetY: offsetY,
      renderScale: renderScale,
      anchorXPx: anchorXPx,
      anchorYPx: anchorYPx,
      castOriginOffset: castOriginOffset,
    );
    widget.controller.applyCommand(update.toCommand());
    _rebaseInspectorFromCurrentEntry(entryId);
  }

  void _applyEntryValuesCoalesced(
    String entryId, {
    required double halfX,
    required double halfY,
    required double offsetX,
    required double offsetY,
    double? renderScale,
    double? anchorXPx,
    double? anchorYPx,
    double? castOriginOffset,
  }) {
    final update = _buildEntityUpdate(
      entryId: entryId,
      halfX: halfX,
      halfY: halfY,
      offsetX: offsetX,
      offsetY: offsetY,
      renderScale: renderScale,
      anchorXPx: anchorXPx,
      anchorYPx: anchorYPx,
      castOriginOffset: castOriginOffset,
    );
    widget.controller.applyCoalescedCommand(update.toCommand());
    _rebaseInspectorFromCurrentEntry(entryId);
  }

  void _rebaseInspectorFromCurrentEntry(String entryId) {
    final scene = widget.controller.scene;
    if (scene is! EntityScene) return;
    for (final entry in scene.entries) {
      if (entry.id == entryId) {
        _syncInspectorFromEntry(entry);
        return;
      }
    }
  }

  EntityUpdate _buildEntityUpdate({
    required String entryId,
    required double halfX,
    required double halfY,
    required double offsetX,
    required double offsetY,
    double? renderScale,
    double? anchorXPx,
    double? anchorYPx,
    double? castOriginOffset,
  }) {
    // Both normal and coalesced paths carry the same immutable domain value.
    return EntityUpdate(
      entryId: entryId,
      halfX: halfX,
      halfY: halfY,
      offsetX: offsetX,
      offsetY: offsetY,
      renderScale: renderScale,
      anchorXPx: anchorXPx,
      anchorYPx: anchorYPx,
      castOriginOffset: castOriginOffset,
    );
  }
}
