import 'dart:ui';

/// Places measured labels in stable source order. Candidate scoring favors short
/// leaders, avoids every geographic pin, and separates labels where space allows.
/// All inputs/output use scene pixels; zoom never changes geographic anchors.
List<Rect> placeMapLabels({
  required List<Offset> anchors,
  required List<Size> labels,
  required Rect visibleMap,
}) {
  assert(anchors.length == labels.length);
  final placed = <Rect>[];
  for (var i = 0; i < anchors.length; i++) {
    final anchor = anchors[i], size = labels[i];
    Rect candidate(Offset center) => Rect.fromLTWH(
      (center.dx - size.width / 2).clamp(
        visibleMap.left,
        visibleMap.right - size.width,
      ),
      (center.dy - size.height / 2).clamp(
        visibleMap.top,
        visibleMap.bottom - size.height,
      ),
      size.width,
      size.height,
    );
    final candidates = <Rect>[
      for (var ring = 1; ring <= 4; ring++)
        for (final direction in const [
          Offset(0, -1),
          Offset(1, 0),
          Offset(-1, 0),
          Offset(0, 1),
          Offset(1, -1),
          Offset(-1, -1),
          Offset(1, 1),
          Offset(-1, 1),
        ])
          candidate(
            anchor +
                Offset(
                  direction.dx * (size.width / 2 + 18 * ring),
                  direction.dy * (size.height / 2 + 18 * ring),
                ),
          ),
      // Dense clusters can use free rows away from their shared anchor.
      for (
        var y = visibleMap.top + size.height / 2;
        y <= visibleMap.bottom - size.height / 2;
        y += size.height + 8
      )
        for (final x in [
          visibleMap.left + size.width / 2,
          visibleMap.center.dx,
          visibleMap.right - size.width / 2,
        ])
          candidate(Offset(x, y)),
      // Occupied-label edges supply exact free slots even when a regular grid
      // does not divide the viewport evenly (especially at large text scales).
      for (final other in placed)
        for (final center in [
          Offset(other.center.dx, other.top - 8 - size.height / 2),
          Offset(other.center.dx, other.bottom + 8 + size.height / 2),
          Offset(other.left - 8 - size.width / 2, other.center.dy),
          Offset(other.right + 8 + size.width / 2, other.center.dy),
        ])
          candidate(center),
      for (final x in [
        visibleMap.left + size.width / 2,
        visibleMap.right - size.width / 2,
      ])
        for (final y in [
          visibleMap.top + size.height / 2,
          visibleMap.bottom - size.height / 2,
        ])
          candidate(Offset(x, y)),
    ];
    double score(Rect bounds) {
      var penalty = (bounds.center - anchor).distance;
      for (final pin in anchors) {
        if (bounds.inflate(8).contains(pin)) penalty += 1000000;
      }
      for (final other in placed) {
        final overlap = bounds.inflate(4).intersect(other.inflate(4));
        if (!overlap.isEmpty) {
          penalty += 100000 + overlap.width * overlap.height;
        }
      }
      final leader = _leaderPoints(anchor, bounds);
      for (var j = 0; j < placed.length; j++) {
        if (_crossesLabel(leader, placed[j].inflate(4)) ||
            _crossesLabel(
              _leaderPoints(anchors[j], placed[j]),
              bounds.inflate(4),
            )) {
          penalty += 50000;
        }
      }
      return penalty;
    }

    var best = candidates.first;
    var bestScore = score(best);
    for (final option in candidates.skip(1)) {
      final value = score(option);
      if (value < bestScore) {
        best = option;
        bestScore = value;
      }
    }
    placed.add(best);
  }
  return placed;
}

/// Stops at the measured label edge. Straight leaders follow the center ray;
/// routed leaders finish horizontally without crossing the label.
Path mapCalloutLeader(Offset anchor, Rect bounds, {bool straight = false}) {
  if (straight) {
    if (bounds.isEmpty) return Path();
    final delta = anchor - bounds.center;
    final horizontal = delta.dx.abs() / (bounds.width / 2);
    final vertical = delta.dy.abs() / (bounds.height / 2);
    final extent = horizontal > vertical ? horizontal : vertical;
    // A label covering its pin has no visible connecting segment.
    if (extent <= 1) return Path();
    final edge = bounds.center + delta / extent;
    return Path()
      ..moveTo(anchor.dx, anchor.dy)
      ..lineTo(edge.dx, edge.dy);
  }
  final points = _leaderPoints(anchor, bounds);
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  for (final point in points.skip(1)) {
    path.lineTo(point.dx, point.dy);
  }
  return path;
}

List<Offset> _leaderPoints(Offset anchor, Rect bounds) {
  final side = anchor.dx < bounds.center.dx ? -1.0 : 1.0;
  final end = side < 0 ? bounds.centerLeft : bounds.centerRight;
  final shoulder = end + Offset(side * 12, 0);
  final clearance = bounds.inflate(4);
  final points = [anchor];
  if (anchor.dx >= clearance.left && anchor.dx <= clearance.right) {
    points.add(
      Offset(
        shoulder.dx,
        anchor.dy < bounds.center.dy ? clearance.top : clearance.bottom,
      ),
    );
  }
  return points
    ..add(shoulder)
    ..add(end);
}

bool _crossesLabel(List<Offset> points, Rect bounds) {
  for (var i = 1; i < points.length; i++) {
    var enter = 0.0, leave = 1.0;
    final from = points[i - 1], delta = points[i] - from;
    for (final axis in [
      (from.dx, delta.dx, bounds.left, bounds.right),
      (from.dy, delta.dy, bounds.top, bounds.bottom),
    ]) {
      if (axis.$2 == 0) {
        if (axis.$1 < axis.$3 || axis.$1 > axis.$4) {
          enter = 2;
          break;
        }
      } else {
        final a = (axis.$3 - axis.$1) / axis.$2,
            b = (axis.$4 - axis.$1) / axis.$2;
        final lo = a < b ? a : b, hi = a > b ? a : b;
        if (lo > enter) enter = lo;
        if (hi < leave) leave = hi;
      }
    }
    if (enter <= leave) return true;
  }
  return false;
}
