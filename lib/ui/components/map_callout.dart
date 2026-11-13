import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../theme/ui_world_palette.dart';
import 'map_callout_geometry.dart';

/// Places a label and routes its leader using the child's actual layout bounds.
/// Keeping both in one render object avoids delayed measurements after font,
/// text-scale or viewport changes. Only the label receives pointer events.
class MapCallout extends SingleChildRenderObjectWidget {
  const MapCallout({
    super.key,
    required this.anchor,
    required this.labelCenter,
    required this.visibleMap,
    this.maxLabelWidth,
    this.straightLeader = false,
    required super.child,
  });

  final Offset anchor, labelCenter;
  final Rect visibleMap;
  final double? maxLabelWidth;

  /// Connect directly to the measured label edge instead of routing around it.
  final bool straightLeader;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderMapCallout(
    anchor,
    labelCenter,
    visibleMap,
    maxLabelWidth,
    straightLeader,
  );

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderShiftedBox renderObject,
  ) {
    (renderObject as _RenderMapCallout).updatePositions(
      anchor,
      labelCenter,
      visibleMap,
      maxLabelWidth,
      straightLeader,
    );
  }
}

class _RenderMapCallout extends RenderShiftedBox {
  _RenderMapCallout(
    this._anchor,
    this._labelCenter,
    this._visibleMap,
    this._maxLabelWidth,
    this._straightLeader,
  ) : super(null);

  Offset _anchor, _labelCenter;
  Rect _visibleMap;
  double? _maxLabelWidth;
  bool _straightLeader;

  void updatePositions(
    Offset anchor,
    Offset labelCenter,
    Rect visibleMap,
    double? maxLabelWidth,
    bool straightLeader,
  ) {
    if (_anchor == anchor &&
        _labelCenter == labelCenter &&
        _visibleMap == visibleMap &&
        _maxLabelWidth == maxLabelWidth &&
        _straightLeader == straightLeader) {
      return;
    }
    _anchor = anchor;
    _labelCenter = labelCenter;
    _visibleMap = visibleMap;
    _maxLabelWidth = maxLabelWidth;
    _straightLeader = straightLeader;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    size = constraints.biggest;
    final label = child!;
    label.layout(
      BoxConstraints.loose(
        Size(_maxLabelWidth ?? _visibleMap.width, _visibleMap.height),
      ),
      parentUsesSize: true,
    );
    final desired = _labelCenter - label.size.center(Offset.zero);
    (label.parentData! as BoxParentData).offset = Offset(
      desired.dx.clamp(_visibleMap.left, _visibleMap.right - label.size.width),
      desired.dy.clamp(_visibleMap.top, _visibleMap.bottom - label.size.height),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final label = child!;
    final labelOffset = (label.parentData! as BoxParentData).offset;
    final bounds = labelOffset & label.size;
    paintMapCallout(
      context.canvas,
      offset: offset,
      anchor: _anchor,
      bounds: bounds,
      straightLeader: _straightLeader,
    );
    context.paintChild(label, offset + labelOffset);
  }
}

/// Shared leader and geographic dot painting for automatic and authored labels.
void paintMapCallout(
  Canvas canvas, {
  required Offset offset,
  required Offset anchor,
  required Rect bounds,
  bool straightLeader = false,
}) {
  final path = mapCalloutLeader(anchor, bounds, straight: straightLeader);
  canvas.save();
  canvas.translate(offset.dx, offset.dy);
  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 3
    ..color = UiWorldPalette.ink900;
  canvas.drawPath(path, paint);
  paint
    ..strokeWidth = 1
    ..color = UiWorldPalette.mist200;
  canvas.drawPath(path, paint);
  paint
    ..style = PaintingStyle.fill
    ..color = UiWorldPalette.ink900;
  canvas.drawCircle(anchor, 4, paint);
  paint.color = UiWorldPalette.mist200;
  canvas.drawCircle(anchor, 2.5, paint);
  canvas.restore();
}
