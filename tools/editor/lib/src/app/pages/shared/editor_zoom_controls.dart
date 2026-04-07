import 'package:flutter/material.dart';

import 'editor_scene_view_utils.dart';

/// Shared zoom input widget for editor scene pages.
///
/// Exposes zoom as world scale (`1.0 == 100%`) while displaying/accepting
/// percent values in the text field for authoring ergonomics.
class EditorZoomControls extends StatefulWidget {
  const EditorZoomControls({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0.1,
    this.max = 12.0,
    this.step = 0.1,
    this.label = 'Zoom',
    this.sliderWidth = 220,
    this.fieldWidth = 96,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final double step;
  final String label;
  final double sliderWidth;
  final double fieldWidth;

  @override
  State<EditorZoomControls> createState() => _EditorZoomControlsState();
}

class _EditorZoomControlsState extends State<EditorZoomControls> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _syncText();
  }

  @override
  void didUpdateWidget(covariant EditorZoomControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!EditorSceneViewUtils.zoomValuesEqual(oldWidget.value, widget.value)) {
      _syncText();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clampedValue = widget.value.clamp(widget.min, widget.max).toDouble();
    final divisions = ((widget.max - widget.min) / widget.step).round();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.fieldWidth,
          child: TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              isDense: true,
              labelText: widget.label,
              suffixText: '%',
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _commit(),
            onEditingComplete: _commit,
            onTapOutside: (_) => _commit(),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: widget.sliderWidth,
          child: Slider(
            min: widget.min,
            max: widget.max,
            divisions: divisions < 1 ? null : divisions,
            value: clampedValue,
            label: '${_formatPercent(clampedValue)}%',
            onChanged: (next) {
              widget.onChanged(_snapToStep(next));
            },
          ),
        ),
      ],
    );
  }

  void _commit() {
    // Text input is validated + snapped before dispatch so slider and text
    // paths produce identical zoom states.
    final parsed = _parsePercent(_controller.text);
    if (parsed == null) {
      _syncText();
      return;
    }
    widget.onChanged(_snapToStep(parsed));
  }

  double? _parsePercent(String raw) {
    final normalized = raw.trim().replaceAll('%', '').replaceAll(',', '.');
    if (normalized.isEmpty) {
      return null;
    }
    final percent = double.tryParse(normalized);
    if (percent == null || !percent.isFinite) {
      return null;
    }
    return (percent / 100.0).clamp(widget.min, widget.max).toDouble();
  }

  double _snapToStep(double value) {
    return EditorSceneViewUtils.snapZoom(
      value: value,
      min: widget.min,
      max: widget.max,
      step: widget.step,
    );
  }

  String _formatPercent(double value) {
    final percent = (value * 100).round();
    return percent.toString();
  }

  void _syncText() {
    final text = _formatPercent(widget.value);
    if (_controller.text == text) {
      return;
    }
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
