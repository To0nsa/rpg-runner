import 'package:flutter/material.dart';
import 'package:runner_content_pipeline/runner_content_pipeline.dart'
    show normalizePrefabRotationDegrees;

/// Numeric clockwise degrees and a center-rotation slider for decorations.
/// Finite author input wraps to [0, 360); invalid input never changes the value.
class ChunkPrefabRotationControl extends StatefulWidget {
  const ChunkPrefabRotationControl({
    super.key,
    required this.fieldKeyPrefix,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });
  final String fieldKeyPrefix;
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  State<ChunkPrefabRotationControl> createState() =>
      _ChunkPrefabRotationControlState();
}

class _ChunkPrefabRotationControlState
    extends State<ChunkPrefabRotationControl> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _format(widget.value));
  }

  @override
  void didUpdateWidget(covariant ChunkPrefabRotationControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.text = _format(widget.value);
      _error = null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 112,
        child: TextFormField(
          key: ValueKey<String>('${widget.fieldKeyPrefix}_rotation_field'),
          controller: _controller,
          enabled: widget.enabled,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          textAlign: TextAlign.right,
          decoration: InputDecoration(
            isDense: true,
            labelText: 'Rotation (°)',
            helperText: 'Around center',
            errorText: _error,
            border: const OutlineInputBorder(),
          ),
          validator: (_) =>
              _validValue() == null ? 'Enter a finite angle.' : null,
          onFieldSubmitted: (_) => _commit(),
          onEditingComplete: _commit,
          onTapOutside: (_) => _commit(),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Slider(
          key: ValueKey<String>('${widget.fieldKeyPrefix}_rotation_slider'),
          min: 0,
          max: 360,
          divisions: 360,
          value: widget.value,
          label: '${_format(widget.value)}°',
          onChanged: widget.enabled ? (value) => _setValue(value) : null,
        ),
      ),
    ],
  );

  double? _validValue() {
    final value = double.tryParse(_controller.text.trim());
    return value != null && value.isFinite ? value : null;
  }

  void _commit() {
    if (!widget.enabled) return;
    final value = _validValue();
    if (value == null) {
      setState(() => _error = 'Enter a finite angle.');
      return;
    }
    _setValue(value);
  }

  void _setValue(double value) {
    final degrees = normalizePrefabRotationDegrees(value);
    setState(() {
      _error = null;
      _controller.text = _format(degrees);
    });
    widget.onChanged(degrees);
  }

  String _format(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}
