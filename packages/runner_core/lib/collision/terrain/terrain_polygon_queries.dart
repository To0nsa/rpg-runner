import 'dart:math' as math;

import 'terrain_numeric.dart';

/// Integer-coordinate even/odd containment; points on edges are excluded.
/// The polygon must be a normalized simple loop in physics ticks.
bool terrainPointStrictlyInsidePolygon(
  TerrainPoint point,
  List<TerrainPoint> vertices,
) {
  var inside = false;
  for (
    var currentIndex = 0, previousIndex = vertices.length - 1;
    currentIndex < vertices.length;
    previousIndex = currentIndex, currentIndex += 1
  ) {
    final current = vertices[currentIndex];
    final previous = vertices[previousIndex];
    final edgeX = current.xTicks - previous.xTicks;
    final edgeY = current.yTicks - previous.yTicks;
    final relativeX = point.xTicks - previous.xTicks;
    final relativeY = point.yTicks - previous.yTicks;
    if (edgeX * relativeY - edgeY * relativeX == 0 &&
        point.xTicks >= math.min(previous.xTicks, current.xTicks) &&
        point.xTicks <= math.max(previous.xTicks, current.xTicks) &&
        point.yTicks >= math.min(previous.yTicks, current.yTicks) &&
        point.yTicks <= math.max(previous.yTicks, current.yTicks)) {
      return false;
    }
    final crossesY =
        (current.yTicks > point.yTicks) != (previous.yTicks > point.yTicks);
    if (!crossesY) continue;
    final left =
        (point.xTicks - current.xTicks) * (previous.yTicks - current.yTicks);
    final right =
        (previous.xTicks - current.xTicks) * (point.yTicks - current.yTicks);
    final crossesRight = previous.yTicks > current.yTicks
        ? left < right
        : left > right;
    if (crossesRight) inside = !inside;
  }
  return inside;
}
