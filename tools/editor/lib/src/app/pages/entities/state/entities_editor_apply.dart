part of '../entities_editor_page.dart';

/// Inspector draft parsing + command payload construction for entity updates.
///
/// This extension validates user-entered numbers and forwards normalized update
/// commands to the session controller. It does not perform direct file writes.
extension _EntitiesEditorApply on _EntitiesEditorPageState {
  bool _applyInspectorEdits(EntityEntry selectedEntry) {
    final halfX = _parseFiniteEntityNumber(_halfXController.text);
    final halfY = _parseFiniteEntityNumber(_halfYController.text);
    final offsetX = _parseFiniteEntityNumber(_offsetXController.text);
    final offsetY = _parseFiniteEntityNumber(_offsetYController.text);

    if (halfX == null || halfY == null || offsetX == null || offsetY == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'All entity size/offset fields must be finite numbers.',
          ),
        ),
      );
      return false;
    }

    final reference = selectedEntry.referenceVisual;
    double? renderScale;
    double? anchorXPx;
    double? anchorYPx;
    double? castOriginOffset;
    if (reference != null) {
      if (reference.renderScaleBinding != null) {
        renderScale = _parseFiniteEntityNumber(_renderScaleController.text);
        if (renderScale == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('renderScale must be a finite number.'),
            ),
          );
          return false;
        }
      }
      if (reference.hasWritableAnchorPoint) {
        anchorXPx = _parseFiniteEntityNumber(_anchorXPxController.text);
        anchorYPx = _parseFiniteEntityNumber(_anchorYPxController.text);
        if (anchorXPx == null || anchorYPx == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('anchorPoint.x/y must be finite numbers.'),
            ),
          );
          return false;
        }
      }
    }
    if (selectedEntry.castOriginOffsetBinding != null) {
      castOriginOffset = _parseFiniteEntityNumber(
        _castOriginOffsetController.text,
      );
      if (castOriginOffset == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('castOriginOffset must be a finite number.'),
          ),
        );
        return false;
      }
    }

    return _applyEntryValues(
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

  bool _applyEntryValues(
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
    return _dispatchEntityUpdate(update, coalesced: false);
  }

  bool _applyEntryValuesCoalesced(
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
    return _dispatchEntityUpdate(update, coalesced: true);
  }

  bool _dispatchEntityUpdate(EntityUpdate update, {required bool coalesced}) {
    try {
      if (coalesced) {
        widget.controller.applyCoalescedCommand(update.toCommand());
      } else {
        widget.controller.applyCommand(update.toCommand());
      }
    } on ArgumentError catch (error) {
      _showEntityUpdateRejected(error.message.toString());
      return false;
    } on StateError catch (error) {
      _showEntityUpdateRejected(error.message);
      return false;
    }
    final scene = widget.controller.scene;
    if (scene is EntityScene) {
      final entry = scene.entries
          .where((entry) => entry.id == update.entryId)
          .firstOrNull;
      if (entry != null && update.isAppliedTo(entry)) {
        _syncInspectorFromEntry(entry);
        return true;
      }
    }
    _showEntityUpdateRejected(
      'The current editor could not accept these values.',
    );
    return false;
  }

  void _showEntityUpdateRejected(String reason) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$reason Your entered values are retained.')),
    );
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

double? _parseFiniteEntityNumber(String text) {
  final value = double.tryParse(text.trim());
  return value != null && value.isFinite ? value : null;
}
