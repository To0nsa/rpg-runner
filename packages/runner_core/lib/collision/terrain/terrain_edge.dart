import 'terrain_edge_id.dart';
import 'terrain_numeric.dart';
import 'terrain_polygon.dart';

/// Fixed fractional precision used by compiled edge lengths.
const int terrainEdgeLengthFractionScale = 1024;

/// Endpoint context retained for later ghost-vertex collision filtering.
enum TerrainVertexJoin {
  /// No compatible adjacent exposed edge exists.
  exposed,

  /// An adjacent edge exists and forms a geometric corner.
  connected,

  /// An adjacent edge continues in the same quantized direction.
  smooth,
}

/// Immutable exposed collision segment compiled from canonical terrain.
class TerrainEdge {
  /// Creates one compiler-owned edge record.
  ///
  /// Endpoints, directions, joins, and bounds must be derived together by the
  /// terrain compiler; direct callers must preserve those invariants.
  TerrainEdge({
    required this.id,
    required this.start,
    required this.end,
    required this.tangent,
    required this.outwardNormal,
    required this.collisionMode,
    required this.surfaceKind,
    required this.materialKey,
    required this.previousId,
    required this.nextId,
    required this.startJoin,
    required this.endJoin,
    required this.bounds,
  }) : lengthSquaredTicks = _lengthSquared(start, end),
       lengthFloorTicks = _integerSquareRoot(_lengthSquared(start, end)),
       lengthScaledCeilTicks = _scaledLengthCeil(start, end),
       projectionXFactor = _projectionFactor(start, end, horizontal: true),
       projectionXDenominator = _projectionDenominator(
         start,
         end,
         horizontal: true,
       ),
       projectionYFactor = _projectionFactor(start, end, horizontal: false),
       projectionYDenominator = _projectionDenominator(
         start,
         end,
         horizontal: false,
       );

  /// Stable source lineage and canonical tie order.
  final TerrainEdgeId id;

  /// Directed start point in 1/1024-world-unit physics ticks.
  final TerrainPoint start;

  /// Directed end point in 1/1024-world-unit physics ticks.
  final TerrainPoint end;

  /// Quantized unit direction from [start] to [end].
  final TerrainDirection tangent;

  /// Quantized clockwise Y-down outward unit normal.
  final TerrainDirection outwardNormal;

  /// Physical sidedness, independent from semantic metadata.
  final TerrainCollisionMode collisionMode;

  /// Optional gameplay surface classifier retained without interpretation.
  final String? surfaceKind;

  /// Optional material classifier retained without interpretation.
  final String? materialKey;

  /// Compatible exposed edge entering [start], if one exists.
  final TerrainEdgeId? previousId;

  /// Compatible exposed edge leaving [end], if one exists.
  final TerrainEdgeId? nextId;

  /// Endpoint context at [start] for later ghost-vertex filtering.
  final TerrainVertexJoin startJoin;

  /// Endpoint context at [end] for later ghost-vertex filtering.
  final TerrainVertexJoin endJoin;

  /// Tight inclusive bounds in 1/1024-world-unit physics ticks.
  final TerrainAabb bounds;

  /// Squared finite-segment length in physics ticks.
  ///
  /// This compiler-time fact keeps exact hot-loop distance comparisons within
  /// small-integer arithmetic.
  final int lengthSquaredTicks;

  /// Floor finite-segment length reused by deterministic support math.
  final int lengthFloorTicks;

  /// Ceiling segment length in 1/1024-physics-tick fixed-point units.
  ///
  /// The conservative sub-tick ceiling lets hot collision checks compare an
  /// exact cross product without square roots, division, or boxed integers.
  final int lengthScaledCeilTicks;

  /// GCD-reduced horizontal factor for exact finite-face projection.
  final int projectionXFactor;

  /// Positive denominator paired with [projectionXFactor].
  final int projectionXDenominator;

  /// GCD-reduced vertical factor for exact finite-face projection.
  final int projectionYFactor;

  /// Positive denominator paired with [projectionYFactor].
  final int projectionYDenominator;

  /// Directed horizontal span in physics ticks.
  int get dxTicks => end.xTicks - start.xTicks;

  /// Directed vertical span in physics ticks.
  int get dyTicks => end.yTicks - start.yTicks;

  @override
  bool operator ==(Object other) =>
      other is TerrainEdge &&
      id == other.id &&
      start == other.start &&
      end == other.end &&
      tangent == other.tangent &&
      outwardNormal == other.outwardNormal &&
      collisionMode == other.collisionMode &&
      surfaceKind == other.surfaceKind &&
      materialKey == other.materialKey &&
      previousId == other.previousId &&
      nextId == other.nextId &&
      startJoin == other.startJoin &&
      endJoin == other.endJoin &&
      bounds.minX == other.bounds.minX &&
      bounds.minY == other.bounds.minY &&
      bounds.maxX == other.bounds.maxX &&
      bounds.maxY == other.bounds.maxY;

  /// Object hashes are suitable for collections, never deterministic digests.
  @override
  int get hashCode => Object.hash(
    id,
    start,
    end,
    tangent,
    outwardNormal,
    collisionMode,
    surfaceKind,
    materialKey,
    previousId,
    nextId,
    startJoin,
    endJoin,
    bounds.minX,
    bounds.minY,
    bounds.maxX,
    bounds.maxY,
  );
}

int _lengthSquared(TerrainPoint start, TerrainPoint end) {
  final dx = end.xTicks - start.xTicks;
  final dy = end.yTicks - start.yTicks;
  return dx * dx + dy * dy;
}

int _scaledLengthCeil(TerrainPoint start, TerrainPoint end) {
  final lengthSquared = _lengthSquared(start, end);
  final lengthFloor = _integerSquareRoot(lengthSquared);
  final remainder = lengthSquared - lengthFloor * lengthFloor;
  if (remainder == 0) {
    return lengthFloor * terrainEdgeLengthFractionScale;
  }
  // sqrt(n) - floor(sqrt(n)) = remainder / (sqrt(n) + floor).
  // Replacing the denominator with 2*floor is a conservative upper bound,
  // and all intermediates remain well inside signed 63-bit arithmetic.
  final fractionalCeil =
      (remainder * terrainEdgeLengthFractionScale + lengthFloor * 2 - 1) ~/
      (lengthFloor * 2);
  return lengthFloor * terrainEdgeLengthFractionScale + fractionalCeil;
}

int _projectionFactor(
  TerrainPoint start,
  TerrainPoint end, {
  required bool horizontal,
}) {
  final component = horizontal
      ? end.xTicks - start.xTicks
      : end.yTicks - start.yTicks;
  if (component == 0) return 0;
  final divisor = component.abs().gcd(_lengthSquared(start, end));
  return component ~/ divisor;
}

int _projectionDenominator(
  TerrainPoint start,
  TerrainPoint end, {
  required bool horizontal,
}) {
  final component = horizontal
      ? end.xTicks - start.xTicks
      : end.yTicks - start.yTicks;
  if (component == 0) return 1;
  final lengthSquared = _lengthSquared(start, end);
  return lengthSquared ~/ component.abs().gcd(lengthSquared);
}

int _integerSquareRoot(int value) {
  if (value < 2) return value;
  var estimate = 1 << ((value.bitLength + 1) >> 1);
  while (true) {
    final next = (estimate + value ~/ estimate) >> 1;
    if (next >= estimate) return estimate;
    estimate = next;
  }
}
