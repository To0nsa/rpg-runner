import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../collision/terrain/terrain_edge_id.dart';
import '../../collision/terrain/terrain_numeric.dart';
import '../../collision/terrain/terrain_polygon.dart';
import '../../collision/terrain/terrain_traversal_profile.dart';

/// Navigation meaning of one directed surface endpoint.
enum TerrainSurfaceEndpointKind {
  /// No unambiguous compatible surface continues through the endpoint.
  ledge,

  /// The adjacent surface continues in the same quantized direction.
  smooth,

  /// The adjacent surface is compatible but changes direction.
  corner,
}

/// Immutable upward-facing terrain segment shared by every graph profile.
///
/// Endpoints use authoritative 1/1024-world-unit physics ticks and are always
/// directed from lower X to higher X. [id] is the exact compiled edge identity;
/// runtime graph indices are intentionally not persistent identities.
class TerrainNavigationSurface {
  /// Creates one validated shared node from a compiled upward terrain edge.
  factory TerrainNavigationSurface({
    required TerrainEdgeId id,
    required TerrainPoint start,
    required TerrainPoint end,
    required TerrainDirection tangent,
    required TerrainDirection outwardNormal,
    required TerrainCollisionMode collisionMode,
    required String? surfaceKind,
    required String? materialKey,
    required TerrainEdgeId? previousId,
    required TerrainEdgeId? nextId,
    required TerrainSurfaceEndpointKind startKind,
    required TerrainSurfaceEndpointKind endKind,
    required TerrainEdgeId chainId,
  }) {
    final dx = end.xTicks - start.xTicks;
    final dy = end.yTicks - start.yTicks;
    if (dx <= 0 || outwardNormal.yTicks >= 0 || tangent.xTicks <= 0) {
      throw ArgumentError(
        'Navigation surfaces must be non-vertical, left-to-right, and '
        'upward-facing.',
      );
    }
    if ((previousId == null) !=
            (startKind == TerrainSurfaceEndpointKind.ledge) ||
        (nextId == null) != (endKind == TerrainSurfaceEndpointKind.ledge)) {
      throw ArgumentError(
        'Endpoint kinds must agree with previous/next surface identity.',
      );
    }
    return TerrainNavigationSurface._(
      id: id,
      start: start,
      end: end,
      tangent: tangent,
      outwardNormal: outwardNormal,
      lengthTicks: _roundedIntegerHypotenuse(dx, dy),
      collisionMode: collisionMode,
      surfaceKind: surfaceKind,
      materialKey: materialKey,
      previousId: previousId,
      nextId: nextId,
      startKind: startKind,
      endKind: endKind,
      chainId: chainId,
    );
  }

  const TerrainNavigationSurface._({
    required this.id,
    required this.start,
    required this.end,
    required this.tangent,
    required this.outwardNormal,
    required this.lengthTicks,
    required this.collisionMode,
    required this.surfaceKind,
    required this.materialKey,
    required this.previousId,
    required this.nextId,
    required this.startKind,
    required this.endKind,
    required this.chainId,
  });

  /// Exact persistent identity of the compiled source edge.
  final TerrainEdgeId id;

  /// Inclusive lower-X endpoint in authoritative physics ticks.
  final TerrainPoint start;

  /// Inclusive higher-X endpoint in authoritative physics ticks.
  final TerrainPoint end;

  /// Quantized left-to-right unit direction.
  final TerrainDirection tangent;

  /// Quantized outward unit normal with a negative Y component.
  final TerrainDirection outwardNormal;

  /// Segment length rounded to the nearest authoritative physics tick.
  final int lengthTicks;

  /// Solid or top-side-only physical contact behavior.
  final TerrainCollisionMode collisionMode;

  /// Optional authored semantic surface classifier.
  final String? surfaceKind;

  /// Optional authored material classifier used at chain boundaries.
  final String? materialKey;

  /// Compatible surface ending at [start], or `null` when [start] is a ledge.
  final TerrainEdgeId? previousId;

  /// Compatible surface beginning at [end], or `null` when [end] is a ledge.
  final TerrainEdgeId? nextId;

  /// Navigation classification of the lower-X endpoint.
  final TerrainSurfaceEndpointKind startKind;

  /// Navigation classification of the higher-X endpoint.
  final TerrainSurfaceEndpointKind endKind;

  /// Canonically lowest [TerrainEdgeId] in this connected surface chain.
  final TerrainEdgeId chainId;

  /// Inclusive lower X in authoritative physics ticks.
  int get xMinTicks => start.xTicks;

  /// Inclusive higher X in authoritative physics ticks.
  int get xMaxTicks => end.xTicks;

  /// Positive horizontal span in authoritative physics ticks.
  int get dxTicks => end.xTicks - start.xTicks;

  /// Signed vertical span in Y-down authoritative physics ticks.
  int get dyTicks => end.yTicks - start.yTicks;

  /// Whether ordinary traversal cannot continue through [start].
  bool get startIsLedge => startKind == TerrainSurfaceEndpointKind.ledge;

  /// Whether ordinary traversal cannot continue through [end].
  bool get endIsLedge => endKind == TerrainSurfaceEndpointKind.ledge;

  /// Returns the nearest physics-grid Y on this segment at [xTicks].
  ///
  /// The query is inclusive at both endpoints and rejects X outside the finite
  /// segment. Integer rational interpolation keeps results platform-stable;
  /// exact half-tick ties round away from zero.
  int yAtXTicks(int xTicks) {
    if (xTicks < start.xTicks || xTicks > end.xTicks) {
      throw RangeError.range(xTicks, start.xTicks, end.xTicks, 'xTicks');
    }
    final numerator =
        start.yTicks * dxTicks + dyTicks * (xTicks - start.xTicks);
    return _divideRoundNearest(numerator, dxTicks);
  }

  /// Whether this shared node is support-eligible for [profile].
  bool isEligibleFor(TerrainTraversalProfile profile) {
    if (collisionMode == TerrainCollisionMode.oneWay &&
        !profile.oneWaySupportEnabled) {
      return false;
    }
    return -outwardNormal.yTicks >= profile.minimumSupportUpComponent;
  }
}

/// Immutable canonical surface set derived from one terrain geometry version.
class TerrainSurfaceSet {
  /// Validates and freezes surfaces already ordered by exact canonical ID.
  factory TerrainSurfaceSet({
    required int geometryVersion,
    required Iterable<TerrainNavigationSurface> surfaces,
  }) {
    if (geometryVersion < 0) {
      throw ArgumentError.value(
        geometryVersion,
        'geometryVersion',
        'Must be non-negative.',
      );
    }
    final ordered = List<TerrainNavigationSurface>.of(surfaces);
    for (var index = 1; index < ordered.length; index += 1) {
      if (ordered[index - 1].id.compareTo(ordered[index].id) >= 0) {
        throw ArgumentError(
          'Terrain navigation surfaces must have unique canonical ID order.',
        );
      }
    }
    final byId = <TerrainEdgeId, TerrainNavigationSurface>{
      for (final surface in ordered) surface.id: surface,
    };
    for (final surface in ordered) {
      if (!byId.containsKey(surface.chainId)) {
        throw ArgumentError('Every chain ID must identify a set member.');
      }
      final previous = surface.previousId == null
          ? null
          : byId[surface.previousId];
      final next = surface.nextId == null ? null : byId[surface.nextId];
      if ((surface.previousId != null && previous == null) ||
          (surface.nextId != null && next == null) ||
          (previous != null && previous.nextId != surface.id) ||
          (next != null && next.previousId != surface.id)) {
        throw ArgumentError(
          'Surface adjacency must be present and reciprocal within the set.',
        );
      }
    }
    return TerrainSurfaceSet._(
      geometryVersion: geometryVersion,
      surfaces: UnmodifiableListView<TerrainNavigationSurface>(ordered),
      byId: Map<TerrainEdgeId, TerrainNavigationSurface>.unmodifiable(byId),
      indexById: Map<TerrainEdgeId, int>.unmodifiable(<TerrainEdgeId, int>{
        for (var index = 0; index < ordered.length; index += 1)
          ordered[index].id: index,
      }),
    );
  }

  const TerrainSurfaceSet._({
    required this.geometryVersion,
    required this.surfaces,
    required Map<TerrainEdgeId, TerrainNavigationSurface> byId,
    required Map<TerrainEdgeId, int> indexById,
  }) : _byId = byId,
       _indexById = indexById;

  /// Exact version of the source terrain geometry.
  final int geometryVersion;

  /// Shared nodes in strict [TerrainEdgeId] order.
  final List<TerrainNavigationSurface> surfaces;
  final Map<TerrainEdgeId, TerrainNavigationSurface> _byId;
  final Map<TerrainEdgeId, int> _indexById;

  /// Finds an exact persistent surface identity, or returns `null`.
  TerrainNavigationSurface? surfaceById(TerrainEdgeId id) => _byId[id];

  /// Returns a version-local index; callers must discard it on version change.
  int? indexOfId(TerrainEdgeId id) => _indexById[id];

  /// Canonical integer records for the version-independent `nav-surfaces-v1`.
  List<String> canonicalRecords() => List<String>.unmodifiable(<String>[
    for (final surface in surfaces)
      _canonicalRecord(<String>[
        'nav-surfaces-v1',
        surface.id.canonicalKey,
        surface.start.xTicks.toString(),
        surface.start.yTicks.toString(),
        surface.end.xTicks.toString(),
        surface.end.yTicks.toString(),
        surface.tangent.xTicks.toString(),
        surface.tangent.yTicks.toString(),
        surface.outwardNormal.xTicks.toString(),
        surface.outwardNormal.yTicks.toString(),
        surface.lengthTicks.toString(),
        surface.collisionMode.name,
        surface.surfaceKind ?? '',
        surface.materialKey ?? '',
        surface.previousId?.canonicalKey ?? '',
        surface.nextId?.canonicalKey ?? '',
        surface.startKind.name,
        surface.endKind.name,
        surface.chainId.canonicalKey,
      ]),
  ]);

  /// SHA-256 digest of [canonicalRecords], independent of bundle version.
  String signature() =>
      sha256.convert(utf8.encode(canonicalRecords().join('\n'))).toString();
}

int _roundedIntegerHypotenuse(int dx, int dy) {
  final squared = dx * dx + dy * dy;
  final floor = _integerSquareRoot(squared);
  final lowerDistance = squared - floor * floor;
  final upper = floor + 1;
  final upperDistance = upper * upper - squared;
  return upperDistance <= lowerDistance ? upper : floor;
}

int _integerSquareRoot(int value) {
  if (value < 0) throw ArgumentError.value(value, 'value');
  if (value < 2) return value;
  var current = 1 << ((value.bitLength + 1) >> 1);
  while (true) {
    final next = (current + value ~/ current) >> 1;
    if (next >= current) return current;
    current = next;
  }
}

int _divideRoundNearest(int numerator, int positiveDenominator) {
  if (numerator >= 0) {
    return (numerator + positiveDenominator ~/ 2) ~/ positiveDenominator;
  }
  return -((-numerator + positiveDenominator ~/ 2) ~/ positiveDenominator);
}

String _canonicalRecord(List<String> fields) =>
    fields.map((field) => '${utf8.encode(field).length}:$field').join('|');
