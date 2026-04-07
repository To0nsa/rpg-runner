part of '../entities_editor_page.dart';

/// Zoom controls/state transitions for the entities viewport.
///
/// Zoom values are snapped to a fixed step so ctrl-scroll, button controls, and
/// numeric updates always converge to the same deterministic values.
extension _EntitySceneZoom on _EntitiesEditorPageState {
  /// Editor-authoring zoom bounds; keep wide enough for pixel-level collider
  /// edits while still allowing broad context framing.
  static const double _zoomMin = 0.1;
  static const double _zoomMax = 12.0;
  static const double _zoomStep = 0.1;

  Widget _buildSceneZoomControls() => EditorZoomControls(
    value: _sceneZoom,
    min: _zoomMin,
    max: _zoomMax,
    step: _zoomStep,
    onChanged: _setZoom,
  );

  void _zoomIn() {
    _setZoom(_sceneZoom + _zoomStep);
  }

  void _zoomOut() {
    _setZoom(_sceneZoom - _zoomStep);
  }

  void _setZoom(double value) {
    final next = EditorSceneViewUtils.snapZoom(
      value: value,
      min: _zoomMin,
      max: _zoomMax,
      step: _zoomStep,
    );
    if (EditorSceneViewUtils.zoomValuesEqual(next, _sceneZoom)) {
      return;
    }
    _updateState(() {
      _sceneZoom = next;
    });
    // Recenter after zoom so the same world focal area remains visible.
    _scheduleSceneViewportCentering();
  }
}
