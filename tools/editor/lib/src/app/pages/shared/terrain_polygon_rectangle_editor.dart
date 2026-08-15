import 'package:flutter/material.dart';

import '../../../terrain_authoring/terrain_axis_aligned_rectangle.dart';
import '../../../terrain_authoring/terrain_half_pixel_text.dart';

/// Exact dimension editor for an axis-aligned polygon rectangle.
///
/// Parsing remains in integer half-pixel ticks and applies all four corners in
/// one callback. Its vertical anchor is the bottom edge, so changing height
/// moves only the top two corners instead of shifting terrain support.
class TerrainPolygonRectangleEditor extends StatefulWidget {
  const TerrainPolygonRectangleEditor({
    super.key,
    required this.keyPrefix,
    required this.rectangle,
    required this.onApply,
    this.controlGap = 8,
  });

  final String keyPrefix;
  final TerrainAxisAlignedRectangle rectangle;
  final void Function({
    required int xHalfPixels,
    required int bottomYHalfPixels,
    required int widthHalfPixels,
    required int heightHalfPixels,
  })
  onApply;
  final double controlGap;

  @override
  State<TerrainPolygonRectangleEditor> createState() =>
      _TerrainPolygonRectangleEditorState();
}

class _TerrainPolygonRectangleEditorState
    extends State<TerrainPolygonRectangleEditor> {
  late final TextEditingController _xController;
  late final TextEditingController _yController;
  late final TextEditingController _widthController;
  late final TextEditingController _heightController;
  String? _xError;
  String? _yError;
  String? _widthError;
  String? _heightError;

  @override
  void initState() {
    super.initState();
    _xController = _controllerFor(widget.rectangle.xHalfPixels);
    _yController = _controllerFor(
      widget.rectangle.yHalfPixels + widget.rectangle.heightHalfPixels,
    );
    _widthController = _controllerFor(widget.rectangle.widthHalfPixels);
    _heightController = _controllerFor(widget.rectangle.heightHalfPixels);
  }

  @override
  void dispose() {
    _xController.dispose();
    _yController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Rectangle dimensions',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        SizedBox(height: widget.controlGap),
        Row(
          children: <Widget>[
            Expanded(
              child: _field(
                key: '${widget.keyPrefix}_rectangle_x_field',
                controller: _xController,
                label: 'X (px)',
                error: _xError,
              ),
            ),
            SizedBox(width: widget.controlGap),
            Expanded(
              child: _field(
                key: '${widget.keyPrefix}_rectangle_bottom_field',
                controller: _yController,
                label: 'Bottom (px)',
                error: _yError,
              ),
            ),
          ],
        ),
        SizedBox(height: widget.controlGap),
        Row(
          children: <Widget>[
            Expanded(
              child: _field(
                key: '${widget.keyPrefix}_rectangle_width_field',
                controller: _widthController,
                label: 'Width (px)',
                error: _widthError,
              ),
            ),
            SizedBox(width: widget.controlGap),
            Expanded(
              child: _field(
                key: '${widget.keyPrefix}_rectangle_height_field',
                controller: _heightController,
                label: 'Height (px)',
                error: _heightError,
              ),
            ),
          ],
        ),
        SizedBox(height: widget.controlGap),
        FilledButton.icon(
          key: ValueKey<String>('${widget.keyPrefix}_apply_rectangle'),
          onPressed: _apply,
          icon: const Icon(Icons.check),
          label: const Text('Apply rectangle dimensions'),
        ),
      ],
    );
  }

  TextField _field({
    required String key,
    required TextEditingController controller,
    required String label,
    required String? error,
  }) => TextField(
    key: ValueKey<String>(key),
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(
      signed: true,
      decimal: true,
    ),
    decoration: InputDecoration(
      labelText: label,
      errorText: error,
      border: const OutlineInputBorder(),
    ),
    onSubmitted: (_) => _apply(),
  );

  void _apply() {
    final xHalfPixels = TerrainHalfPixelText.tryParseTicks(_xController.text);
    final bottomYHalfPixels = TerrainHalfPixelText.tryParseTicks(
      _yController.text,
    );
    final widthHalfPixels = TerrainHalfPixelText.tryParseTicks(
      _widthController.text,
    );
    final heightHalfPixels = TerrainHalfPixelText.tryParseTicks(
      _heightController.text,
    );
    setState(() {
      _xError = xHalfPixels == null ? 'Use an integer or .5 value.' : null;
      _yError = bottomYHalfPixels == null
          ? 'Use an integer or .5 value.'
          : null;
      _widthError = widthHalfPixels == null
          ? 'Use an integer or .5 value.'
          : widthHalfPixels <= 0
          ? 'Must be greater than 0.'
          : null;
      _heightError = heightHalfPixels == null
          ? 'Use an integer or .5 value.'
          : heightHalfPixels <= 0
          ? 'Must be greater than 0.'
          : null;
    });
    if (xHalfPixels == null ||
        bottomYHalfPixels == null ||
        widthHalfPixels == null ||
        heightHalfPixels == null ||
        widthHalfPixels <= 0 ||
        heightHalfPixels <= 0) {
      return;
    }
    widget.onApply(
      xHalfPixels: xHalfPixels,
      bottomYHalfPixels: bottomYHalfPixels,
      widthHalfPixels: widthHalfPixels,
      heightHalfPixels: heightHalfPixels,
    );
  }

  TextEditingController _controllerFor(int halfPixels) =>
      TextEditingController(text: TerrainHalfPixelText.formatTicks(halfPixels));
}
