part of '../entities_editor_page.dart';

extension _SceneZoom on _EntitiesEditorPageState {
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
    _scheduleSceneViewportCentering();
  }
}
