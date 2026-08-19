import 'package:flutter/material.dart';

import '../../../terrain_authoring/terrain_half_pixel_text.dart';
import '../../../terrain_authoring/terrain_source_models.dart';
import 'terrain_polygon_exact_edit_controller.dart';

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
    this.onBeforeApply,
    this.editController,
    this.applyButtonKey,
    this.applyLabel = 'Apply exact vertex',
    this.applyEnabled = true,
    this.coordinateStepHalfPixels = 1,
    this.controlGap = 8,
  }) : assert(coordinateStepHalfPixels > 0);

  final String keyPrefix;
  final String shapeId;
  final int vertexIndex;
  final TerrainSourceVertexDef vertex;
  final bool Function(int xHalfPixels, int yHalfPixels) onApply;
  final bool Function()? onBeforeApply;
  final TerrainPolygonExactEditController? editController;
  final Key? applyButtonKey;
  final String applyLabel;
  final bool applyEnabled;
  final int coordinateStepHalfPixels;
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
    _attachEditController();
  }

  @override
  void didUpdateWidget(covariant TerrainPolygonVertexEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.editController == widget.editController) return;
    oldWidget.editController?.detach(this);
    _attachEditController();
  }

  @override
  void dispose() {
    widget.editController?.detach(this);
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
                keyboardType: TextInputType.numberWithOptions(
                  signed: true,
                  decimal: widget.coordinateStepHalfPixels == 1,
                ),
                decoration: InputDecoration(
                  labelText: 'X (px)',
                  errorText: _xError,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => widget.editController?.markChanged(),
                onSubmitted: (_) => _apply(),
              ),
            ),
            SizedBox(width: widget.controlGap),
            Expanded(
              child: TextField(
                key: ValueKey<String>('${widget.keyPrefix}_vertex_y_field'),
                controller: _yController,
                keyboardType: TextInputType.numberWithOptions(
                  signed: true,
                  decimal: widget.coordinateStepHalfPixels == 1,
                ),
                decoration: InputDecoration(
                  labelText: 'Y (px)',
                  errorText: _yError,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => widget.editController?.markChanged(),
                onSubmitted: (_) => _apply(),
              ),
            ),
          ],
        ),
        SizedBox(height: widget.controlGap),
        FilledButton.icon(
          key:
              widget.applyButtonKey ??
              ValueKey<String>('${widget.keyPrefix}_apply_vertex'),
          onPressed: widget.applyEnabled ? _apply : null,
          icon: const Icon(Icons.check),
          label: Text(widget.applyLabel),
        ),
      ],
    );
  }

  bool _apply() {
    final xHalfPixels = TerrainHalfPixelText.tryParseTicks(_xController.text);
    final yHalfPixels = TerrainHalfPixelText.tryParseTicks(_yController.text);
    final coordinateError = widget.coordinateStepHalfPixels == 1
        ? 'Use an integer or .5 value.'
        : 'Use a whole-pixel value.';
    setState(() {
      _xError = _isOnAuthoringGrid(xHalfPixels) ? null : coordinateError;
      _yError = _isOnAuthoringGrid(yHalfPixels) ? null : coordinateError;
    });
    if (!_isOnAuthoringGrid(xHalfPixels) || !_isOnAuthoringGrid(yHalfPixels)) {
      return false;
    }
    if (widget.onBeforeApply?.call() == false) return false;
    return widget.onApply(xHalfPixels!, yHalfPixels!);
  }

  bool _isOnAuthoringGrid(int? halfPixels) =>
      halfPixels != null && halfPixels % widget.coordinateStepHalfPixels == 0;

  bool get _hasChanges =>
      TerrainHalfPixelText.tryParseTicks(_xController.text) !=
          widget.vertex.xHalfPixels ||
      TerrainHalfPixelText.tryParseTicks(_yController.text) !=
          widget.vertex.yHalfPixels;

  void _attachEditController() {
    widget.editController?.attach(
      this,
      hasChanges: () => _hasChanges,
      save: _apply,
      discard: _restoreSourceValues,
    );
  }

  void _restoreSourceValues() {
    _xController.text = TerrainHalfPixelText.formatTicks(
      widget.vertex.xHalfPixels,
    );
    _yController.text = TerrainHalfPixelText.formatTicks(
      widget.vertex.yHalfPixels,
    );
    if (!mounted) return;
    setState(() {
      _xError = null;
      _yError = null;
    });
  }
}
