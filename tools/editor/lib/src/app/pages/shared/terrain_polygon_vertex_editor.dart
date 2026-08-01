import 'package:flutter/material.dart';

import '../../../terrain_authoring/terrain_half_pixel_text.dart';
import '../../../terrain_authoring/terrain_source_models.dart';

/// Exact integer/half-pixel coordinate editor shared by polygon owner routes.
///
/// Parsing stays in integer half-pixel ticks. Invalid text remains local to the
/// fields and never reaches an owner controller or session history.
class TerrainPolygonVertexEditor extends StatefulWidget {
  const TerrainPolygonVertexEditor({
    super.key,
    required this.keyPrefix,
    required this.shapeId,
    required this.vertexIndex,
    required this.vertex,
    required this.onApply,
    this.controlGap = 8,
  });

  final String keyPrefix;
  final String shapeId;
  final int vertexIndex;
  final TerrainSourceVertexDef vertex;
  final void Function(int xHalfPixels, int yHalfPixels) onApply;
  final double controlGap;

  @override
  State<TerrainPolygonVertexEditor> createState() =>
      _TerrainPolygonVertexEditorState();
}

class _TerrainPolygonVertexEditorState
    extends State<TerrainPolygonVertexEditor> {
  late final TextEditingController _xController;
  late final TextEditingController _yController;
  String? _xError;
  String? _yError;

  @override
  void initState() {
    super.initState();
    _xController = TextEditingController(
      text: TerrainHalfPixelText.formatTicks(widget.vertex.xHalfPixels),
    );
    _yController = TextEditingController(
      text: TerrainHalfPixelText.formatTicks(widget.vertex.yHalfPixels),
    );
  }

  @override
  void dispose() {
    _xController.dispose();
    _yController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Edit ${widget.shapeId} v${widget.vertexIndex}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        SizedBox(height: widget.controlGap),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                key: ValueKey<String>('${widget.keyPrefix}_vertex_x_field'),
                controller: _xController,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'X (px)',
                  errorText: _xError,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _apply(),
              ),
            ),
            SizedBox(width: widget.controlGap),
            Expanded(
              child: TextField(
                key: ValueKey<String>('${widget.keyPrefix}_vertex_y_field'),
                controller: _yController,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Y (px)',
                  errorText: _yError,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _apply(),
              ),
            ),
          ],
        ),
        SizedBox(height: widget.controlGap),
        FilledButton.icon(
          key: ValueKey<String>('${widget.keyPrefix}_apply_vertex'),
          onPressed: _apply,
          icon: const Icon(Icons.check),
          label: const Text('Apply exact vertex'),
        ),
      ],
    );
  }

  void _apply() {
    final xHalfPixels = TerrainHalfPixelText.tryParseTicks(_xController.text);
    final yHalfPixels = TerrainHalfPixelText.tryParseTicks(_yController.text);
    setState(() {
      _xError = xHalfPixels == null ? 'Use an integer or .5 value.' : null;
      _yError = yHalfPixels == null ? 'Use an integer or .5 value.' : null;
    });
    if (xHalfPixels == null || yHalfPixels == null) return;
    widget.onApply(xHalfPixels, yHalfPixels);
  }
}
