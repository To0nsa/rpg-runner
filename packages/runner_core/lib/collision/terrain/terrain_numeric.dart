import 'dart:math' as math;

/// Number of exact authored-coordinate ticks in one world unit.
///
/// Source geometry is restricted to half-world-unit increments.
const int terrainSourceTicksPerWorldUnit = 2;

/// Number of deterministic physics ticks in one world unit.
const int terrainPhysicsTicksPerWorldUnit = 1024;

/// Geometry equality tolerance in physics ticks.
const int terrainGeometryEpsilonTicks = 1;

/// Contact and deterministic tie tolerance in physics ticks.
const int terrainContactEpsilonTicks = 2;

/// Dimensionless guard for zero denominators and stalled sweep progress.
const double terrainParametricGuard = 1e-12;

/// Dimensionless endpoint classifier tolerance for segment parameters.
const double terrainEndpointParameterEpsilon = 1e-9;

/// Collision skin in physics ticks (`1/16` world unit).
const int terrainCollisionSkinTicks = 64;

/// Maximum blocking contacts resolved for one actor during one fixed tick.
const int terrainMaxBlockingContacts = 4;

/// Maximum deterministic initial-overlap correction passes per fixed tick.
const int terrainMaxRecoveryIterations = 4;

/// Fixed scale used by compiled unit tangents and normals.
///
/// Reusing the 1/1024 physics scale makes the accepted `(56,-97)` edge
/// quantize exactly to the inclusive 60-degree walkability threshold.
const int terrainDirectionScale = 1024;

/// Fixed slope-angle units per degree used by traversal caches.
const int terrainSlopeAngleUnitsPerDegree = 1024;

/// Default square terrain-index cell width in world units.
const int terrainDefaultCellSizeWorld = 64;

/// Maximum absolute coordinate accepted at public conversion boundaries.
///
/// This keeps values and common products inside signed 63-bit arithmetic while
/// allowing more than one billion world units in either direction.
const int terrainMaxAbsPhysicsTicks = 1 << 40;

/// Exact point on the authored half-world-unit coordinate grid.
class SourceTerrainPoint {
  /// Creates a source point from already-validated half-world-unit ticks.
  factory SourceTerrainPoint(int xTicks, int yTicks) {
    const factor =
        terrainPhysicsTicksPerWorldUnit ~/ terrainSourceTicksPerWorldUnit;
    _checkPhysicsRange(xTicks * factor, 'xTicks');
    _checkPhysicsRange(yTicks * factor, 'yTicks');
    return SourceTerrainPoint._(xTicks, yTicks);
  }

  const SourceTerrainPoint._(this.xTicks, this.yTicks);

  /// Converts exact half-grid world coordinates to source ticks.
  factory SourceTerrainPoint.fromWorld(double x, double y) {
    return SourceTerrainPoint(
      sourceCoordinateToTicks(x, name: 'x'),
      sourceCoordinateToTicks(y, name: 'y'),
    );
  }

  /// Horizontal source coordinate in half-world-unit ticks.
  final int xTicks;

  /// Vertical source coordinate in half-world-unit ticks.
  final int yTicks;

  /// Converts this authored point exactly to the physics grid.
  TerrainPoint toPhysicsPoint() {
    const factor =
        terrainPhysicsTicksPerWorldUnit ~/ terrainSourceTicksPerWorldUnit;
    return TerrainPoint(xTicks * factor, yTicks * factor);
  }

  @override
  bool operator ==(Object other) =>
      other is SourceTerrainPoint &&
      xTicks == other.xTicks &&
      yTicks == other.yTicks;

  @override
  int get hashCode => Object.hash(xTicks, yTicks);

  @override
  String toString() => 'SourceTerrainPoint($xTicks, $yTicks)';
}

/// Exact point on the deterministic 1/1024-world-unit physics grid.
class TerrainPoint implements Comparable<TerrainPoint> {
  /// Creates a point from checked physics-grid ticks.
  factory TerrainPoint(int xTicks, int yTicks) {
    _checkPhysicsRange(xTicks, 'xTicks');
    _checkPhysicsRange(yTicks, 'yTicks');
    return TerrainPoint._(xTicks, yTicks);
  }

  const TerrainPoint._(this.xTicks, this.yTicks);

  /// Quantizes finite world coordinates to the physics grid.
  factory TerrainPoint.fromWorld(double x, double y) {
    return TerrainPoint(
      physicsCoordinateToTicks(x, name: 'x'),
      physicsCoordinateToTicks(y, name: 'y'),
    );
  }

  /// Horizontal coordinate in 1/1024-world-unit ticks.
  final int xTicks;

  /// Vertical coordinate in 1/1024-world-unit ticks.
  final int yTicks;

  /// Horizontal coordinate in world units.
  double get x => xTicks / terrainPhysicsTicksPerWorldUnit;

  /// Vertical coordinate in world units.
  double get y => yTicks / terrainPhysicsTicksPerWorldUnit;

  /// Returns this point translated by integer physics ticks.
  TerrainPoint translated(int dxTicks, int dyTicks) =>
      TerrainPoint(xTicks + dxTicks, yTicks + dyTicks);

  @override
  int compareTo(TerrainPoint other) {
    final xOrder = xTicks.compareTo(other.xTicks);
    return xOrder != 0 ? xOrder : yTicks.compareTo(other.yTicks);
  }

  @override
  bool operator ==(Object other) =>
      other is TerrainPoint && xTicks == other.xTicks && yTicks == other.yTicks;

  @override
  int get hashCode => Object.hash(xTicks, yTicks);

  @override
  String toString() => 'TerrainPoint($xTicks, $yTicks)';
}

/// Quantized unit vector used for compiled tangents and outward normals.
class TerrainDirection {
  /// Creates a direction whose components use [terrainDirectionScale].
  factory TerrainDirection(int xTicks, int yTicks) {
    if (xTicks == 0 && yTicks == 0) {
      throw ArgumentError('Terrain direction must not be zero.');
    }
    if (xTicks.abs() > terrainDirectionScale ||
        yTicks.abs() > terrainDirectionScale) {
      throw RangeError('Terrain direction components must be normalized.');
    }
    final magnitudeSquared = xTicks * xTicks + yTicks * yTicks;
    final targetSquared = terrainDirectionScale * terrainDirectionScale;
    if ((magnitudeSquared - targetSquared).abs() > 2 * terrainDirectionScale) {
      throw ArgumentError('Terrain direction must be a quantized unit vector.');
    }
    return TerrainDirection._(xTicks, yTicks);
  }

  const TerrainDirection._(this.xTicks, this.yTicks);

  /// Quantizes and normalizes a non-zero vector without trigonometry.
  factory TerrainDirection.fromDelta(int dxTicks, int dyTicks) =>
      TerrainDirection.fromVector(dxTicks.toDouble(), dyTicks.toDouble());

  /// Quantizes and normalizes finite components already expressed in one unit.
  factory TerrainDirection.fromVector(double dx, double dy) {
    _requireFinite(dx, 'dx');
    _requireFinite(dy, 'dy');
    if (dx == 0 && dy == 0) {
      throw ArgumentError('Cannot normalize a zero-length terrain vector.');
    }
    final length = math.sqrt(dx * dx + dy * dy);
    return TerrainDirection(
      terrainQuantizeDirectionComponent(dx, length),
      terrainQuantizeDirectionComponent(dy, length),
    );
  }

  /// Horizontal component where [terrainDirectionScale] equals one.
  final int xTicks;

  /// Vertical component where [terrainDirectionScale] equals one.
  final int yTicks;

  /// Horizontal component converted to the inclusive unit-vector range.
  double get x => xTicks / terrainDirectionScale;

  /// Vertical component converted to the inclusive unit-vector range.
  double get y => yTicks / terrainDirectionScale;

  @override
  bool operator ==(Object other) =>
      other is TerrainDirection &&
      xTicks == other.xTicks &&
      yTicks == other.yTicks;

  @override
  int get hashCode => Object.hash(xTicks, yTicks);

  @override
  String toString() => 'TerrainDirection($xTicks, $yTicks)';
}

/// Closed axis-aligned bounds expressed in deterministic physics ticks.
class TerrainAabb {
  /// Creates checked closed bounds in 1/1024-world-unit physics ticks.
  factory TerrainAabb({
    required int minX,
    required int minY,
    required int maxX,
    required int maxY,
  }) {
    _checkPhysicsRange(minX, 'minX');
    _checkPhysicsRange(minY, 'minY');
    _checkPhysicsRange(maxX, 'maxX');
    _checkPhysicsRange(maxY, 'maxY');
    if (minX > maxX || minY > maxY) {
      throw ArgumentError('Terrain AABB minimums must not exceed maximums.');
    }
    return TerrainAabb._(minX: minX, minY: minY, maxX: maxX, maxY: maxY);
  }

  const TerrainAabb._({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });

  /// Inclusive minimum horizontal coordinate in physics ticks.
  final int minX;

  /// Inclusive minimum vertical coordinate in physics ticks.
  final int minY;

  /// Inclusive maximum horizontal coordinate in physics ticks.
  final int maxX;

  /// Inclusive maximum vertical coordinate in physics ticks.
  final int maxY;

  /// Returns bounds expanded by [ticks] on all sides.
  TerrainAabb expanded(int ticks) {
    if (ticks < 0) {
      throw ArgumentError.value(ticks, 'ticks', 'Must be non-negative.');
    }
    return TerrainAabb(
      minX: minX - ticks,
      minY: minY - ticks,
      maxX: maxX + ticks,
      maxY: maxY + ticks,
    );
  }

  /// Returns the closed union of these bounds and [other].
  TerrainAabb union(TerrainAabb other) => TerrainAabb(
    minX: math.min(minX, other.minX),
    minY: math.min(minY, other.minY),
    maxX: math.max(maxX, other.maxX),
    maxY: math.max(maxY, other.maxY),
  );

  /// Whether these closed bounds intersect [other].
  bool intersects(TerrainAabb other) =>
      minX <= other.maxX &&
      maxX >= other.minX &&
      minY <= other.maxY &&
      maxY >= other.minY;
}

/// Source placement transform applied in anchor/reflection/scale/translation
/// order before one physics-grid quantization.
class TerrainSourceTransform {
  /// Defines a finite positive-scale placement transform in world units.
  ///
  /// Values are validated when [apply] runs so constant source definitions can
  /// remain lightweight.
  const TerrainSourceTransform({
    this.anchorX = 0,
    this.anchorY = 0,
    this.reflectX = false,
    this.reflectY = false,
    this.scale = 1,
    this.translateX = 0,
    this.translateY = 0,
  });

  /// Horizontal reflection/scale pivot in world units.
  final double anchorX;

  /// Vertical reflection/scale pivot in world units.
  final double anchorY;

  /// Whether to reflect the anchor-relative horizontal coordinate.
  final bool reflectX;

  /// Whether to reflect the anchor-relative vertical coordinate.
  final bool reflectY;

  /// Uniform positive scale applied after reflection.
  final double scale;

  /// Horizontal world-unit translation applied after scale.
  final double translateX;

  /// Vertical world-unit translation applied after scale.
  final double translateY;

  /// Applies this transform and returns one quantized physics-grid point.
  TerrainPoint apply(SourceTerrainPoint source) {
    _requireFinite(anchorX, 'anchorX');
    _requireFinite(anchorY, 'anchorY');
    _requireFinite(scale, 'scale');
    _requireFinite(translateX, 'translateX');
    _requireFinite(translateY, 'translateY');
    if (scale <= 0) {
      throw ArgumentError.value(scale, 'scale', 'Must be positive.');
    }

    var x = source.xTicks / terrainSourceTicksPerWorldUnit - anchorX;
    var y = source.yTicks / terrainSourceTicksPerWorldUnit - anchorY;
    if (reflectX) x = -x;
    if (reflectY) y = -y;
    return TerrainPoint.fromWorld(
      x * scale + translateX,
      y * scale + translateY,
    );
  }
}

/// Converts one exact half-grid world coordinate to authored integer ticks.
int sourceCoordinateToTicks(double value, {String name = 'value'}) {
  _requireFinite(value, name);
  final scaled = value * terrainSourceTicksPerWorldUnit;
  final rounded = scaled.round();
  if (scaled != rounded.toDouble()) {
    throw ArgumentError.value(
      value,
      name,
      'Must be an exact multiple of 0.5 world units.',
    );
  }
  _checkPhysicsRange(
    rounded *
        (terrainPhysicsTicksPerWorldUnit ~/ terrainSourceTicksPerWorldUnit),
    name,
  );
  return rounded;
}

/// Quantizes one finite world coordinate to deterministic physics ticks.
int physicsCoordinateToTicks(double value, {String name = 'value'}) {
  _requireFinite(value, name);
  final ticks = (value * terrainPhysicsTicksPerWorldUnit).round();
  _checkPhysicsRange(ticks, name);
  return ticks;
}

/// Rounds a finite value already expressed in physics ticks with range checks.
int terrainPhysicsTickValueToInt(double value, {String name = 'value'}) {
  _requireFinite(value, name);
  final ticks = value.round();
  _checkPhysicsRange(ticks, name);
  return ticks;
}

/// Quantizes one finite unit-vector component without allocating an object.
///
/// [vectorLength] must be the positive length of the vector that owns
/// [component].
int terrainQuantizeDirectionComponent(double component, double vectorLength) {
  _requireFinite(component, 'component');
  _requireFinite(vectorLength, 'vectorLength');
  if (vectorLength <= 0) {
    throw ArgumentError.value(
      vectorLength,
      'vectorLength',
      'Must be positive.',
    );
  }
  final quantized = (component * terrainDirectionScale / vectorLength).round();
  if (quantized.abs() > terrainDirectionScale) {
    throw RangeError.range(
      quantized,
      -terrainDirectionScale,
      terrainDirectionScale,
      'component',
    );
  }
  return quantized;
}

/// Deterministic floor division for positive [divisor], including negatives.
int terrainFloorDiv(int value, int divisor) {
  if (divisor <= 0) {
    throw ArgumentError.value(divisor, 'divisor', 'Must be positive.');
  }
  final quotient = value ~/ divisor;
  final remainder = value.remainder(divisor);
  return remainder < 0 ? quotient - 1 : quotient;
}

int _greatestCommonDivisor(int a, int b) {
  var left = a.abs();
  var right = b.abs();
  while (right != 0) {
    final next = left.remainder(right);
    left = right;
    right = next;
  }
  return left;
}

/// Returns the greatest common divisor of two integer magnitudes.
int terrainGreatestCommonDivisor(int a, int b) => _greatestCommonDivisor(a, b);

void _requireFinite(double value, String name) {
  if (!value.isFinite) {
    throw ArgumentError.value(value, name, 'Must be finite.');
  }
}

void _checkPhysicsRange(int ticks, String name) {
  if (ticks.abs() > terrainMaxAbsPhysicsTicks) {
    throw RangeError.range(
      ticks,
      -terrainMaxAbsPhysicsTicks,
      terrainMaxAbsPhysicsTicks,
      name,
    );
  }
}
