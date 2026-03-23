part of '../../home/editor_home_page.dart';

extension _SceneZoom on _EditorHomePageState {
  static const double _zoomMin = 0.1;
  static const double _zoomMax = 12.0;
  static const double _zoomStep = 0.1;
  static const double _zoomEpsilon = 0.000001;

  Widget _buildSceneZoomControls() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 96,
          child: TextField(
            controller: _sceneZoomController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'Zoom',
              suffixText: '%',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) {
              _commitSceneZoomInput();
            },
            onEditingComplete: _commitSceneZoomInput,
            onTapOutside: (_) {
              _commitSceneZoomInput();
            },
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: _zoomOut,
          icon: const Icon(Icons.zoom_out, size: 18),
          label: const Text('Zoom Out'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: _zoomIn,
          icon: const Icon(Icons.zoom_in, size: 18),
          label: const Text('Zoom In'),
        ),
      ],
    );
  }

  void _zoomIn() {
    _setZoom(_sceneZoom + _zoomStep);
  }

  void _zoomOut() {
    _setZoom(_sceneZoom - _zoomStep);
  }

  void _commitSceneZoomInput() {
    final parsedZoom = _parseZoomFromPercentText(_sceneZoomController.text);
    if (parsedZoom == null) {
      _syncSceneZoomText();
      return;
    }
    _setZoom(parsedZoom);
  }

  void _setZoom(double value) {
    final snapped = _snapZoomToStep(value);
    final next = snapped.clamp(_zoomMin, _zoomMax).toDouble();
    if ((next - _sceneZoom).abs() <= _zoomEpsilon) {
      _syncSceneZoomText();
      return;
    }
    _updateState(() {
      _sceneZoom = next;
    });
    _syncSceneZoomText();
  }

  void _syncSceneZoomText() {
    final text = _formatZoomPercent(_sceneZoom);
    if (_sceneZoomController.text == text) {
      return;
    }
    _sceneZoomController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  double _snapZoomToStep(double value) {
    return (value / _zoomStep).roundToDouble() * _zoomStep;
  }

  double? _parseZoomFromPercentText(String raw) {
    final normalized = raw
        .trim()
        .replaceAll('%', '')
        .replaceAll(',', '.');
    if (normalized.isEmpty) {
      return null;
    }
    final percent = double.tryParse(normalized);
    if (percent == null || !percent.isFinite) {
      return null;
    }
    return percent / 100.0;
  }

  String _formatZoomPercent(double zoom) {
    final percent = (zoom * 100).round();
    return percent.toString();
  }
}
