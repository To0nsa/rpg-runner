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
    final payload = _buildUpdateEntryPayload(
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
    widget.controller.applyCommand(
      AuthoringCommand(kind: 'update_entry', payload: payload),
    );
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
    final payload = _buildUpdateEntryPayload(
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
    widget.controller.applyCoalescedCommand(
      AuthoringCommand(kind: 'update_entry', payload: payload),
    );
  }

  Map<String, Object?> _buildUpdateEntryPayload({
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
    // Keep payload shape consistent between normal and coalesced paths.
    final payload = <String, Object?>{
      'id': entryId,
      'halfX': halfX,
      'halfY': halfY,
      'offsetX': offsetX,
      'offsetY': offsetY,
    };
    if (renderScale != null) {
      payload['renderScale'] = renderScale;
    }
    if (anchorXPx != null) {
      payload['anchorXPx'] = anchorXPx;
    }
    if (anchorYPx != null) {
      payload['anchorYPx'] = anchorYPx;
    }
    if (castOriginOffset != null) {
      payload['castOriginOffset'] = castOriginOffset;
    }
    return payload;
  }
}
