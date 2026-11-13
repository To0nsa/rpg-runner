import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'map_callout.dart';
import 'map_callout_geometry.dart';

/// Measured, automatically placed map callouts shared by game maps and authoring
/// previews. Anchors are scene pixels in the same order as the label children.
class MapLocationLayer extends MultiChildRenderObjectWidget {
  const MapLocationLayer({
    super.key,
    required this.anchors,
    required this.visibleMap,
    required super.children,
  });
  final List<Offset> anchors;
  final Rect visibleMap;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _MapLocationLayer(anchors, visibleMap);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderBox renderObject,
  ) => (renderObject as _MapLocationLayer).update(anchors, visibleMap);
}

class _LocationParentData extends ContainerBoxParentData<RenderBox> {}

class _MapLocationLayer extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _LocationParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _LocationParentData> {
  _MapLocationLayer(this._anchors, this._visibleMap);
  List<Offset> _anchors;
  Rect _visibleMap;
  List<Rect> _labels = const [];

  void update(List<Offset> anchors, Rect visibleMap) {
    _anchors = anchors;
    _visibleMap = visibleMap;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _LocationParentData) {
      child.parentData = _LocationParentData();
    }
  }

  @override
  void performLayout() {
    size = constraints.biggest;
    final sizes = <Size>[];
    var child = firstChild;
    while (child != null) {
      child.layout(
        BoxConstraints.loose(
          Size(math.min(240, _visibleMap.width), _visibleMap.height),
        ),
        parentUsesSize: true,
      );
      sizes.add(child.size);
      child = (child.parentData! as _LocationParentData).nextSibling;
    }
    _labels = placeMapLabels(
      anchors: _anchors,
      labels: sizes,
      visibleMap: _visibleMap,
    );
    child = firstChild;
    var i = 0;
    while (child != null) {
      final data = child.parentData! as _LocationParentData;
      data.offset = _labels[i++].topLeft;
      child = data.nextSibling;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (var i = 0; i < _labels.length; i++) {
      paintMapCallout(
        context.canvas,
        offset: offset,
        anchor: _anchors[i],
        bounds: _labels[i],
      );
    }
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
