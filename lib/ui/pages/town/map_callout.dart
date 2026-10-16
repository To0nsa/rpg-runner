import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../theme/ui_world_palette.dart';

/// Places a label and routes its leader using the child's actual layout bounds.
/// Keeping both in one render object avoids delayed measurements after font,
/// text-scale or viewport changes. Only the label receives pointer events.
class MapCallout extends SingleChildRenderObjectWidget {
  const MapCallout({
    super.key,
    required this.anchor,
    required this.labelCenter,
    required this.visibleMap,
    required super.child,
  });

  final Offset anchor, labelCenter;
  final Rect visibleMap;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMapCallout(anchor, labelCenter, visibleMap);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderShiftedBox renderObject,
  ) {
    (renderObject as _RenderMapCallout).updatePositions(
      anchor,
      labelCenter,
      visibleMap,
    );
  }
}

class _RenderMapCallout extends RenderShiftedBox {
  _RenderMapCallout(this._anchor, this._labelCenter, this._visibleMap)
    : super(null);

  Offset _anchor, _labelCenter;
  Rect _visibleMap;

  void updatePositions(Offset anchor, Offset labelCenter, Rect visibleMap) {
    if (_anchor == anchor &&
        _labelCenter == labelCenter &&
        _visibleMap == visibleMap) {
      return;
    }
    _anchor = anchor;
    _labelCenter = labelCenter;
    _visibleMap = visibleMap;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    size = constraints.biggest;
    final label = child!;
    label.layout(BoxConstraints.loose(_visibleMap.size), parentUsesSize: true);
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
    final side = _anchor.dx < bounds.center.dx ? -1.0 : 1.0;
    final end = side < 0 ? bounds.centerLeft : bounds.centerRight;
    final shoulder = end + Offset(side * 12, 0);
    final clearance = bounds.inflate(4);
    final path = Path()..moveTo(_anchor.dx, _anchor.dy);

    // A pin above/below its label needs a corner outside the text before the
    // short horizontal finish. A direct diagonal could otherwise cut through it.
    if (_anchor.dx >= clearance.left && _anchor.dx <= clearance.right) {
      final cornerY = _anchor.dy < bounds.center.dy
          ? clearance.top
          : clearance.bottom;
      path.lineTo(shoulder.dx, cornerY);
    }
    path
      ..lineTo(shoulder.dx, shoulder.dy)
      ..lineTo(end.dx, end.dy);

    final canvas = context.canvas;
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
    canvas.drawCircle(_anchor, 4, paint);
    paint.color = UiWorldPalette.mist200;
    canvas.drawCircle(_anchor, 2.5, paint);
    canvas.restore();
    context.paintChild(label, offset + labelOffset);
  }
}
