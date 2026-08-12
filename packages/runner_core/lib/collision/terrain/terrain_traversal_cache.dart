import 'dart:collection';

import 'terrain_edge_id.dart';
import 'terrain_geometry.dart';
import 'terrain_numeric.dart';

/// Cached traversal measurements for one canonical terrain edge.
class TerrainTraversalEdgeData {
  const TerrainTraversalEdgeData({
    required this.edgeId,
    required this.absoluteSlopeAngleUnits,
  });

  final TerrainEdgeId edgeId;

  /// Absolute angle from horizontal in 1/1024-degree units.
  final int absoluteSlopeAngleUnits;
}

/// Immutable canonical-order slope cache tied to one geometry version.
///
/// It is derived beside geometry publication and is deliberately excluded from
/// stable edge identity and `edges-v1` signatures.
class TerrainTraversalCache {
  factory TerrainTraversalCache.fromGeometry(TerrainGeometry geometry) {
    final entries = <TerrainTraversalEdgeData>[
      for (final edge in geometry.edges)
        TerrainTraversalEdgeData(
          edgeId: edge.id,
          absoluteSlopeAngleUnits: terrainAbsoluteSlopeAngleUnits(
            dxTicks: edge.dxTicks,
            dyTicks: edge.dyTicks,
            tangentXTicks: edge.tangent.xTicks,
            tangentYTicks: edge.tangent.yTicks,
          ),
        ),
    ];
    return TerrainTraversalCache._(
      geometryVersion: geometry.version,
      entries: UnmodifiableListView<TerrainTraversalEdgeData>(entries),
      byEdgeId: Map<TerrainEdgeId, TerrainTraversalEdgeData>.unmodifiable(
        <TerrainEdgeId, TerrainTraversalEdgeData>{
          for (final entry in entries) entry.edgeId: entry,
        },
      ),
    );
  }

  const TerrainTraversalCache._({
    required this.geometryVersion,
    required this.entries,
    required this.byEdgeId,
  });

  final int geometryVersion;
  final List<TerrainTraversalEdgeData> entries;
  final Map<TerrainEdgeId, TerrainTraversalEdgeData> byEdgeId;

  TerrainTraversalEdgeData operator [](TerrainEdgeId edgeId) {
    final value = byEdgeId[edgeId];
    if (value == null) {
      throw StateError('Traversal cache has no entry for edge $edgeId.');
    }
    return value;
  }
}

/// Derives an absolute slope angle with a 24-iteration integer CORDIC.
///
/// Inputs are integer physics deltas. Optional quantized tangent components
/// snap accepted 0/30/45/60/90-degree direction equalities to exact authored
/// control angles.
int terrainAbsoluteSlopeAngleUnits({
  required int dxTicks,
  required int dyTicks,
  int? tangentXTicks,
  int? tangentYTicks,
}) {
  if (dxTicks == 0 && dyTicks == 0) {
    throw ArgumentError('A terrain edge delta must not be zero.');
  }
  if ((tangentXTicks == null) != (tangentYTicks == null)) {
    throw ArgumentError('Both tangent components must be supplied together.');
  }
  if (tangentXTicks != null) {
    final snapped = _snappedControlAngle(
      tangentXTicks.abs(),
      tangentYTicks!.abs(),
    );
    if (snapped != null) return snapped;
  }

  var x = dxTicks.abs();
  var y = dyTicks.abs();
  var angleBam = 0;
  for (var iteration = 0; iteration < _cordicAtanBam.length; iteration += 1) {
    if (y == 0) continue;
    final direction = y > 0 ? 1 : -1;
    final nextX = x + direction * (y >> iteration);
    final nextY = y - direction * (x >> iteration);
    x = nextX;
    y = nextY;
    angleBam += direction * _cordicAtanBam[iteration];
  }
  final magnitude = angleBam.abs();
  return (magnitude * 360 * terrainSlopeAngleUnitsPerDegree +
          (_fullTurnBam ~/ 2)) ~/
      _fullTurnBam;
}

int? _snappedControlAngle(int x, int y) {
  if (y == 0) return 0;
  if (x == 0) return 90 * terrainSlopeAngleUnitsPerDegree;
  if (x == 887 && y == 512) {
    return 30 * terrainSlopeAngleUnitsPerDegree;
  }
  if (x == 724 && y == 724) {
    return 45 * terrainSlopeAngleUnitsPerDegree;
  }
  if (x == 512 && y == 887) {
    return 60 * terrainSlopeAngleUnitsPerDegree;
  }
  return null;
}

const int _fullTurnBam = 1 << 32;

// Binary-angle constants are atan(2^-i), where a full turn is 2^32.
const List<int> _cordicAtanBam = <int>[
  0x20000000,
  0x12E4051D,
  0x09FB385B,
  0x051111D4,
  0x028B0D43,
  0x0145D7E1,
  0x00A2F61E,
  0x00517C55,
  0x0028BE53,
  0x00145F2F,
  0x000A2F98,
  0x000517CC,
  0x00028BE6,
  0x000145F3,
  0x0000A2FA,
  0x0000517D,
  0x000028BE,
  0x0000145F,
  0x00000A30,
  0x00000518,
  0x0000028C,
  0x00000146,
  0x000000A3,
  0x00000051,
];
