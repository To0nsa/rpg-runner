import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../collision/terrain/terrain_geometry.dart';
import '../collision/terrain/terrain_numeric.dart';
import 'types/terrain_navigation_surface.dart';
import 'types/terrain_surface_graph.dart';
import 'terrain_graph_artifact_revision.dart';

/// Bump when graph building, placement queries or codec semantics change.
/// Artifact admission is an optimization; a miss always uses the Core builder.
const terrainGraphArtifactVersion = 1;

/// Exact, version-independent input identity. Positions and source IDs remain
/// part of geometry; profiles use full doubles rather than rounded signatures.
String terrainGraphArtifactKey({
  required TerrainGeometry geometry,
  required TerrainSurfaceSet surfaces,
  required TerrainSurfaceGraphBuildProfile profile,
}) {
  final geometryKey = _geometryKeys[geometry] ??= [
    geometry.sourceSignature(),
    geometry.withVersion(0).edgeSignature(),
  ];
  final surfaceKey = _surfaceKeys[surfaces] ??= surfaces.signature();
  final profileKey = _profileKeys[profile] ??= _profileRecord(profile);
  return sha256
      .convert(
        utf8.encode(
          jsonEncode([
            terrainGraphArtifactVersion,
            terrainGraphArtifactBuildRevision,
            geometryKey,
            surfaceKey,
            profileKey,
          ]),
        ),
      )
      .toString();
}

final _geometryKeys = Expando<List<String>>();
final _surfaceKeys = Expando<String>();
final _profileKeys = Expando<List<Object?>>();

List<Object?> _profileRecord(TerrainSurfaceGraphBuildProfile p) {
  final t = p.traversalProfile;
  final j = p.jumpTemplate.profile;
  return [
    p.profileKey,
    p.radiusTicks,
    p.verticalHalfSegmentTicks,
    p.authoredOffsetXTicks,
    p.offsetYTicks,
    p.supportRequirement.kind.name,
    p.supportRequirement.numerator,
    p.supportRequirement.denominator,
    p.locomotionSpeedTicksPerSecond,
    p.simulationTicksPerSecond,
    p.canJump,
    t.enabled,
    t.isKinematic,
    t.useGravity,
    t.gravityScaleBp,
    t.collideCeilings,
    t.collideLeftWalls,
    t.collideRightWalls,
    t.maxWalkableSlopeAngleUnits,
    t.minimumSupportUpComponent,
    t.stepHeightTicks,
    t.snapDistanceTicks,
    t.oneWaySupportEnabled,
    t.dropThroughEnabled,
    t.groundedMobilityHelpersEnabled,
    [
      for (final point in t.slopeSpeedPoints)
        [
          point.angleUnits,
          point.uphillMultiplierBp,
          point.downhillMultiplierBp,
        ],
    ],
    j.jumpSpeed,
    j.gravityY,
    j.dtSeconds,
    j.maxAirTicks,
    j.airSpeedX,
    j.agentHalfWidth,
    j.effectiveHalfHeight,
    j.requiredSupportFraction,
    j.collideCeilings,
    j.collideLeftWalls,
    j.collideRightWalls,
  ];
}

/// Compact CSR records for one exact graph, with bounded decoding.
///
/// Integrity is checked against a digest from a trusted release manifest.
/// A digest supplied alongside arbitrary client bytes establishes no trust.
abstract final class TerrainGraphArtifactCodec {
  static const maxBytes = 16 * 1024 * 1024;
  static const _maxNodes = 100000;
  static const _maxEdges = 1000000;

  static Uint8List encode({
    required String key,
    required TerrainSurfaceGraph graph,
  }) {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(key)) {
      throw ArgumentError.value(key, 'key', 'Expected SHA-256 input identity.');
    }
    final out = _Writer()..bytes.addAll(utf8.encode('RNG1$key'));
    out.uint(graph.surfaces.length);
    out.uint(graph.edges.length);
    for (var i = 0; i < graph.surfaces.length; i++) {
      out.uint(graph.eligibility[i] ? 1 : 0);
      out.uint(graph.edgeOffsets[i + 1] - graph.edgeOffsets[i]);
    }
    for (final edge in graph.edges) {
      out.uint(edge.kind.index);
      out.uint(edge.to);
      out.sint(edge.takeoffPoint.xTicks);
      out.sint(edge.takeoffPoint.yTicks);
      out.sint(edge.landingPoint.xTicks);
      out.sint(edge.landingPoint.yTicks);
      out.uint(edge.commitDirectionX == 1 ? 1 : 0);
      out.uint(edge.travelTicks);
      out.uint(edge.distanceTicks);
      out.uint(edge.costUnits);
    }
    if (out.bytes.length > maxBytes) {
      throw StateError('Graph artifact exceeds byte limit.');
    }
    return Uint8List.fromList(out.bytes);
  }

  /// Rejects corrupt, oversized, mismatched or noncanonical graph data.
  /// Hosts treat FormatException/ArgumentError as a deterministic rebuild miss.
  static TerrainSurfaceGraph decode({
    required Uint8List bytes,
    required String expectedSha256,
    required String key,
    required TerrainSurfaceSet surfaces,
    required TerrainSurfaceGraphBuildProfile profile,
  }) {
    if (bytes.length < 70 ||
        bytes.length > maxBytes ||
        sha256.convert(bytes).toString() != expectedSha256 ||
        ascii.decode(bytes.sublist(0, 68), allowInvalid: true) != 'RNG1$key') {
      throw const FormatException(
        'Graph artifact integrity or identity mismatch.',
      );
    }
    final input = _Reader(bytes, 68);
    final nodes = input.uint();
    final count = input.uint();
    if (nodes != surfaces.surfaces.length ||
        nodes > _maxNodes ||
        count > _maxEdges) {
      throw const FormatException('Graph artifact dimensions exceed bounds.');
    }
    final eligible = <bool>[];
    final offsets = <int>[0];
    for (var i = 0; i < nodes; i++) {
      final flag = input.uint();
      if (flag > 1) throw const FormatException('Invalid graph eligibility.');
      eligible.add(flag == 1);
      final end = offsets.last + input.uint();
      if (end > count) throw const FormatException('Invalid CSR row length.');
      offsets.add(end);
    }
    final edges = <TerrainSurfaceGraphEdge>[];
    for (var i = 0; i < count; i++) {
      final kindIndex = input.uint();
      if (kindIndex >= TerrainSurfaceEdgeKind.values.length) {
        throw const FormatException('Unknown graph edge kind.');
      }
      final kind = TerrainSurfaceEdgeKind.values[kindIndex];
      final to = input.uint();
      final takeoff = TerrainPoint(input.sint(), input.sint());
      final landing = TerrainPoint(input.sint(), input.sint());
      final direction = input.uint();
      final travel = input.uint();
      final distance = input.uint();
      final cost = input.uint();
      if (direction > 1 ||
          travel <= 0 ||
          cost <= 0 ||
          (kind == TerrainSurfaceEdgeKind.walk
              ? distance <= 0
              : distance != 0)) {
        throw const FormatException('Invalid graph edge values.');
      }
      final edge = kind == TerrainSurfaceEdgeKind.walk
          ? TerrainSurfaceGraphEdge.walk(
              to: to,
              takeoffPoint: takeoff,
              landingPoint: landing,
              commitDirectionX: direction == 1 ? 1 : -1,
              distanceTicks: distance,
              locomotionSpeedTicksPerSecond:
                  profile.locomotionSpeedTicksPerSecond,
              simulationTicksPerSecond: profile.simulationTicksPerSecond,
            )
          : TerrainSurfaceGraphEdge.airborne(
              to: to,
              kind: kind,
              takeoffPoint: takeoff,
              landingPoint: landing,
              commitDirectionX: direction == 1 ? 1 : -1,
              travelTicks: travel,
              simulationTicksPerSecond: profile.simulationTicksPerSecond,
            );
      if (edge.travelTicks != travel || edge.costUnits != cost) {
        throw const FormatException('Graph edge cost differs from profile.');
      }
      edges.add(edge);
    }
    if (input.position != bytes.length) {
      throw const FormatException('Trailing graph data.');
    }
    try {
      return TerrainSurfaceGraph(
        surfaceSet: surfaces,
        buildProfile: profile,
        eligibility: eligible,
        edgeOffsets: offsets,
        edges: edges,
      );
    } on ArgumentError catch (error) {
      throw FormatException('Invalid graph CSR: $error');
    }
  }
}

final class _Writer {
  final bytes = <int>[];
  void uint(int value) {
    if (value < 0 || value > 9007199254740991) {
      throw ArgumentError('Graph integer exceeds portable exact range.');
    }
    while (value >= 128) {
      bytes.add(value % 128 + 128);
      value ~/= 128;
    }
    bytes.add(value);
  }

  void sint(int value) => uint(value >= 0 ? value * 2 : -value * 2 - 1);
}

final class _Reader {
  _Reader(this.bytes, this.position);
  final Uint8List bytes;
  int position;
  int uint() {
    var value = 0;
    var factor = 1;
    for (var i = 0; i < 8; i++) {
      if (position >= bytes.length) {
        throw const FormatException('Truncated graph artifact.');
      }
      final byte = bytes[position++];
      value += (byte % 128) * factor;
      if (value > 9007199254740991) {
        throw const FormatException('Graph integer overflow.');
      }
      if (byte < 128) {
        if (i > 0 && byte == 0) {
          throw const FormatException('Noncanonical graph integer.');
        }
        return value;
      }
      factor *= 128;
    }
    throw const FormatException('Graph integer overflow.');
  }

  int sint() {
    final value = uint();
    return value.isEven ? value ~/ 2 : -(value ~/ 2) - 1;
  }
}
