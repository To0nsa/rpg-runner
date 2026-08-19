import 'package:flutter/material.dart';

import '../../../terrain_authoring/terrain_axis_aligned_rectangle.dart';
import '../../../terrain_authoring/terrain_half_pixel_text.dart';
import 'terrain_polygon_exact_edit_controller.dart';

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
    this.onBeforeApply,
    this.editController,
    this.applyButtonKey,
    this.applyLabel = 'Apply rectangle dimensions',
    this.applyEnabled = true,
    this.coordinateStepHalfPixels = 1,
    this.controlGap = 8,
  }) : assert(coordinateStepHalfPixels > 0);

  final String keyPrefix;
  final TerrainAxisAlignedRectangle rectangle;
  final bool Function({
    required int xHalfPixels,
    required int bottomYHalfPixels,
    required int widthHalfPixels,
    required int heightHalfPixels,
  })
  onApply;
  final bool Function()? onBeforeApply;
  final TerrainPolygonExactEditController? editController;
  final Key? applyButtonKey;
  final String applyLabel;
  final bool applyEnabled;
  final int coordinateStepHalfPixels;
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
    _attachEditController();
  }

  @override
  void didUpdateWidget(covariant TerrainPolygonRectangleEditor oldWidget) {
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
          key:
              widget.applyButtonKey ??
              ValueKey<String>('${widget.keyPrefix}_apply_rectangle'),
          onPressed: widget.applyEnabled ? _apply : null,
          icon: const Icon(Icons.check),
          label: Text(widget.applyLabel),
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
    keyboardType: TextInputType.numberWithOptions(
      signed: true,
      decimal: widget.coordinateStepHalfPixels == 1,
    ),
    decoration: InputDecoration(
      labelText: label,
      errorText: error,
      border: const OutlineInputBorder(),
    ),
    onChanged: (_) => widget.editController?.markChanged(),
    onSubmitted: (_) => _apply(),
  );

  bool _apply() {
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
    final coordinateError = widget.coordinateStepHalfPixels == 1
        ? 'Use an integer or .5 value.'
        : 'Use a whole-pixel value.';
    setState(() {
      _xError = _isOnAuthoringGrid(xHalfPixels) ? null : coordinateError;
      _yError = _isOnAuthoringGrid(bottomYHalfPixels) ? null : coordinateError;
      _widthError = !_isOnAuthoringGrid(widthHalfPixels)
          ? coordinateError
          : widthHalfPixels! <= 0
          ? 'Must be greater than 0.'
          : null;
      _heightError = !_isOnAuthoringGrid(heightHalfPixels)
          ? coordinateError
          : heightHalfPixels! <= 0
          ? 'Must be greater than 0.'
          : null;
    });
    if (!_isOnAuthoringGrid(xHalfPixels) ||
        !_isOnAuthoringGrid(bottomYHalfPixels) ||
        !_isOnAuthoringGrid(widthHalfPixels) ||
        !_isOnAuthoringGrid(heightHalfPixels) ||
        widthHalfPixels! <= 0 ||
        heightHalfPixels! <= 0) {
      return false;
    }
    if (widget.onBeforeApply?.call() == false) return false;
    return widget.onApply(
      xHalfPixels: xHalfPixels!,
      bottomYHalfPixels: bottomYHalfPixels!,
      widthHalfPixels: widthHalfPixels,
      heightHalfPixels: heightHalfPixels,
    );
  }

  bool _isOnAuthoringGrid(int? halfPixels) =>
      halfPixels != null && halfPixels % widget.coordinateStepHalfPixels == 0;

  bool get _hasChanges =>
      TerrainHalfPixelText.tryParseTicks(_xController.text) !=
          widget.rectangle.xHalfPixels ||
      TerrainHalfPixelText.tryParseTicks(_yController.text) !=
          widget.rectangle.yHalfPixels + widget.rectangle.heightHalfPixels ||
      TerrainHalfPixelText.tryParseTicks(_widthController.text) !=
          widget.rectangle.widthHalfPixels ||
      TerrainHalfPixelText.tryParseTicks(_heightController.text) !=
          widget.rectangle.heightHalfPixels;

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
      widget.rectangle.xHalfPixels,
    );
    _yController.text = TerrainHalfPixelText.formatTicks(
      widget.rectangle.yHalfPixels + widget.rectangle.heightHalfPixels,
    );
    _widthController.text = TerrainHalfPixelText.formatTicks(
      widget.rectangle.widthHalfPixels,
    );
    _heightController.text = TerrainHalfPixelText.formatTicks(
      widget.rectangle.heightHalfPixels,
    );
    if (!mounted) return;
    setState(() {
      _xError = null;
      _yError = null;
      _widthError = null;
      _heightError = null;
    });
  }

  TextEditingController _controllerFor(int halfPixels) =>
      TextEditingController(text: TerrainHalfPixelText.formatTicks(halfPixels));
}
