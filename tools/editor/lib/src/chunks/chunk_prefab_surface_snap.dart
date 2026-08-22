import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_edge.dart';
import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/collision/terrain/terrain_polygon_overlap.dart';

import '../prefabs/models/models.dart';
import '../terrain_authoring/terrain_source_core_adapter.dart';
import '../terrain_authoring/terrain_source_models.dart';
import 'chunk_domain_models.dart';

/// Screen-space reach used by direct prefab-to-terrain contact snapping.
const double chunkPrefabSurfaceSnapRadiusPx = 8;

/// Why one prefab gesture did or did not reach exact terrain contact.
enum ChunkPrefabSurfaceSnapStatus {
  snapped,
  noCollision,
  noHorizontalSupport,
  incompatibleScale,
  noTerrainSurface,
  noNearbyValidContact,
}

/// Immutable collision snapshot used during one prefab gesture.
///
/// Occupied polygons come from the accepted Core compilation used by
/// validation. Its direct polygons are compiled alone once so a terrain
/// interval hidden by the accepted placement remains available while moving
/// that placement. A moved placement can then be omitted from [obstacles]
/// without recompiling source during every pointer update.
@immutable
final class ChunkPrefabSurfaceSnapContext {
  factory ChunkPrefabSurfaceSnapContext.fromGeometry({
    required TerrainGeometry geometry,
    String? excludedPlacementKey,
  }) {
    final directInputs = geometry.polygons
        .where((polygon) => polygon.identity.placementKey == null)
        .map(
          (polygon) => TerrainPolygonInput(
            sourcePath: polygon.sourcePath,
            identity: polygon.identity,
            vertices: polygon.sourceVertices,
            collisionMode: polygon.collisionMode,
            surfaceKind: polygon.surfaceKind,
            materialKey: polygon.materialKey,
          ),
        );
    final directGeometry = const TerrainCompiler().compile(
      directInputs,
      geometryVersion: geometry.version,
    );
    final surfaces = directGeometry.edges
        .where(
          (edge) =>
              edge.id.placementKey == null &&
              edge.start.yTicks == edge.end.yTicks &&
              edge.start.xTicks != edge.end.xTicks &&
              edge.outwardNormal.yTicks < 0,
        )
        .toList(growable: false);
    final obstacles = geometry.polygons
        .where(
          (polygon) =>
              excludedPlacementKey == null ||
              polygon.identity.placementKey != excludedPlacementKey,
        )
        .toList(growable: false);
    return ChunkPrefabSurfaceSnapContext._(
      surfaces: surfaces,
      obstacles: obstacles,
    );
  }

  ChunkPrefabSurfaceSnapContext._({
    required Iterable<TerrainEdge> surfaces,
    required Iterable<TerrainPolygon> obstacles,
  }) : surfaces = List<TerrainEdge>.unmodifiable(surfaces),
       obstacles = List<TerrainPolygon>.unmodifiable(obstacles);

  /// Exposed, horizontal, upward-facing edges owned directly by the chunk.
  final List<TerrainEdge> surfaces;

  /// Accepted collision loops that a proposed placement may only touch.
  final List<TerrainPolygon> obstacles;
}

/// One deterministic prefab placement projection and its exact collision loop.
@immutable
final class ChunkPrefabSurfaceSnapResult {
  ChunkPrefabSurfaceSnapResult({
    required this.placement,
    required this.status,
    required Iterable<List<TerrainPoint>> collisionLoops,
    this.targetEdge,
  }) : collisionLoops = List<List<TerrainPoint>>.unmodifiable(
         collisionLoops.map(List<TerrainPoint>.unmodifiable),
       );

  final PlacedPrefabDef placement;
  final ChunkPrefabSurfaceSnapStatus status;
  final List<List<TerrainPoint>> collisionLoops;
  final TerrainEdge? targetEdge;

  bool get snapped => status == ChunkPrefabSurfaceSnapStatus.snapped;

  String get message => switch (status) {
    ChunkPrefabSurfaceSnapStatus.snapped => 'Collider edge touching terrain',
    ChunkPrefabSurfaceSnapStatus.noCollision =>
      'This prefab has no collision edge to snap.',
    ChunkPrefabSurfaceSnapStatus.noHorizontalSupport =>
      'Collider needs a horizontal lowest edge for surface snap.',
    ChunkPrefabSurfaceSnapStatus.incompatibleScale =>
      'This scale puts the collider support between whole pixels.',
    ChunkPrefabSurfaceSnapStatus.noTerrainSurface =>
      'No exposed horizontal terrain surface is available.',
    ChunkPrefabSurfaceSnapStatus.noNearbyValidContact =>
      'Move within 8 screen px of a free terrain surface.',
  };
}

/// Exact scale and contact policy for prefab collision placement.
abstract final class ChunkPrefabSurfaceSnap {
  /// Whether any accepted placement scale yields a lowest horizontal edge.
  static bool hasHorizontalSupport(PrefabV3Def prefab, {bool flipY = false}) {
    for (var scaleTenths = 3; scaleTenths <= 30; scaleTenths += 1) {
      final profile = _profile(
        prefab: prefab,
        scaleTenths: scaleTenths,
        flipX: false,
        flipY: flipY,
      );
      if (profile != null && profile.supports.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  /// Exact `0.1` scales whose lowest horizontal support stays on a whole pixel.
  static List<double> compatibleScales(
    PrefabV3Def prefab, {
    bool flipY = false,
  }) => List<double>.unmodifiable(<double>[
    for (var scaleTenths = 3; scaleTenths <= 30; scaleTenths += 1)
      if (_profile(
            prefab: prefab,
            scaleTenths: scaleTenths,
            flipX: false,
            flipY: flipY,
          )
          case final profile?
          when profile.supports.isNotEmpty &&
              profile.supportYTicks % terrainPhysicsTicksPerWorldUnit == 0)
        scaleTenths / 10,
  ]);

  /// Nearest compatible scale, preferring the smaller scale on equal distance.
  ///
  /// Prefabs without a usable collision support keep [preferred] because their
  /// visual scale has no terrain-contact invariant to satisfy.
  static double preferredCompatibleScale(
    PrefabV3Def prefab, {
    bool flipY = false,
    double preferred = defaultPrefabPlacementScale,
  }) {
    final compatible = compatibleScales(prefab, flipY: flipY);
    if (compatible.isEmpty) return preferred;
    return compatible.reduce((left, right) {
      final leftDistance = (left - preferred).abs();
      final rightDistance = (right - preferred).abs();
      return leftDistance <= rightDistance ? left : right;
    });
  }

  /// Whether [scale] can put the derived support edge on a whole-pixel line.
  static bool isScaleCompatible(
    PrefabV3Def prefab,
    double scale, {
    bool flipY = false,
  }) {
    final scaleTenths = (canonicalPrefabPlacementScale(scale) * 10).round();
    final profile = _profile(
      prefab: prefab,
      scaleTenths: scaleTenths,
      flipX: false,
      flipY: flipY,
    );
    return profile != null &&
        profile.supports.isNotEmpty &&
        profile.supportYTicks % terrainPhysicsTicksPerWorldUnit == 0;
  }

  /// Resolves [placement] to the nearest legal horizontal terrain contact.
  ///
  /// X remains on the caller's pixel or tile grid. Surface contact may refine
  /// Y away from the tile grid, but never away from a whole-pixel origin.
  /// Positive-area collision, out-of-bounds geometry, and point-only contact
  /// are rejected; a shared support interval is required.
  static ChunkPrefabSurfaceSnapResult resolve({
    required PlacedPrefabDef placement,
    required PrefabV3Def prefab,
    required ChunkPrefabSurfaceSnapContext? context,
    required double snapRadiusWorld,
    required int chunkWidth,
    required int chunkHeight,
  }) {
    final scaleTenths = (canonicalPrefabPlacementScale(placement.scale) * 10)
        .round();
    final profile = _profile(
      prefab: prefab,
      scaleTenths: scaleTenths,
      flipX: placement.flipX,
      flipY: placement.flipY,
    );
    if (profile == null) {
      return ChunkPrefabSurfaceSnapResult(
        placement: placement,
        status: prefab.collisionShapes.isEmpty
            ? ChunkPrefabSurfaceSnapStatus.noCollision
            : ChunkPrefabSurfaceSnapStatus.noHorizontalSupport,
        collisionLoops: const <List<TerrainPoint>>[],
      );
    }
    final baseLoops = _translateLoops(
      profile.loops,
      x: placement.x,
      y: placement.y,
    );
    if (profile.supports.isEmpty) {
      return ChunkPrefabSurfaceSnapResult(
        placement: placement,
        status: ChunkPrefabSurfaceSnapStatus.noHorizontalSupport,
        collisionLoops: baseLoops,
      );
    }
    if (profile.supportYTicks % terrainPhysicsTicksPerWorldUnit != 0) {
      return ChunkPrefabSurfaceSnapResult(
        placement: placement,
        status: ChunkPrefabSurfaceSnapStatus.incompatibleScale,
        collisionLoops: baseLoops,
      );
    }
    if (context == null || context.surfaces.isEmpty) {
      return ChunkPrefabSurfaceSnapResult(
        placement: placement,
        status: ChunkPrefabSurfaceSnapStatus.noTerrainSurface,
        collisionLoops: baseLoops,
      );
    }

    final radiusTicks = math.max(
      0,
      (snapRadiusWorld * terrainPhysicsTicksPerWorldUnit).round(),
    );
    final baseSupportY =
        placement.y * terrainPhysicsTicksPerWorldUnit + profile.supportYTicks;
    _SurfaceCandidate? best;
    for (final edge in context.surfaces) {
      final distanceTicks = (edge.start.yTicks - baseSupportY).abs();
      if (distanceTicks > radiusTicks) continue;
      final targetMinX = math.min(edge.start.xTicks, edge.end.xTicks);
      final targetMaxX = math.max(edge.start.xTicks, edge.end.xTicks);
      for (
        var supportIndex = 0;
        supportIndex < profile.supports.length;
        supportIndex += 1
      ) {
        final support = profile.supports[supportIndex];
        final supportMinX =
            placement.x * terrainPhysicsTicksPerWorldUnit + support.minXTicks;
        final supportMaxX =
            placement.x * terrainPhysicsTicksPerWorldUnit + support.maxXTicks;
        if (math.max(targetMinX, supportMinX) >=
            math.min(targetMaxX, supportMaxX)) {
          continue;
        }
        final targetOriginYTicks = edge.start.yTicks - profile.supportYTicks;
        if (targetOriginYTicks % terrainPhysicsTicksPerWorldUnit != 0) {
          continue;
        }
        final candidatePlacement = placement.copyWith(
          y: targetOriginYTicks ~/ terrainPhysicsTicksPerWorldUnit,
        );
        final loops = _translateLoops(
          profile.loops,
          x: candidatePlacement.x,
          y: candidatePlacement.y,
        );
        if (!_isInBounds(
              loops,
              chunkWidth: chunkWidth,
              chunkHeight: chunkHeight,
            ) ||
            _overlapsAny(loops, context.obstacles)) {
          continue;
        }
        final candidate = _SurfaceCandidate(
          placement: candidatePlacement,
          loops: loops,
          edge: edge,
          supportIndex: supportIndex,
          distanceTicks: distanceTicks,
        );
        if (best == null || candidate.compareTo(best) < 0) best = candidate;
      }
    }
    if (best == null) {
      return ChunkPrefabSurfaceSnapResult(
        placement: placement,
        status: ChunkPrefabSurfaceSnapStatus.noNearbyValidContact,
        collisionLoops: baseLoops,
      );
    }
    return ChunkPrefabSurfaceSnapResult(
      placement: best.placement,
      status: ChunkPrefabSurfaceSnapStatus.snapped,
      collisionLoops: best.loops,
      targetEdge: best.edge,
    );
  }
}

final class _PrefabSurfaceProfile {
  const _PrefabSurfaceProfile({
    required this.loops,
    required this.supports,
    required this.supportYTicks,
  });

  final List<List<TerrainPoint>> loops;
  final List<_HorizontalSupport> supports;
  final int supportYTicks;
}

final class _HorizontalSupport {
  const _HorizontalSupport({required this.minXTicks, required this.maxXTicks});

  final int minXTicks;
  final int maxXTicks;
}

_PrefabSurfaceProfile? _profile({
  required PrefabV3Def prefab,
  required int scaleTenths,
  required bool flipX,
  required bool flipY,
}) {
  if (prefab.collisionShapes.isEmpty) return null;
  final transform = TerrainSourceCoreAdapter.placementTransform(
    anchorXHalfPixels: 0,
    anchorYHalfPixels: 0,
    translationXHalfPixels: 0,
    translationYHalfPixels: 0,
    scaleTenths: scaleTenths,
    flipX: flipX,
    flipY: flipY,
  );
  final loops = <List<TerrainPoint>>[];
  int? supportYTicks;
  for (final shape in prefab.collisionShapes) {
    if (shape.collisionMode == TerrainSourceCollisionMode.none) continue;
    final loop = shape.vertices
        .map(
          (vertex) => transform.apply(
            SourceTerrainPoint(vertex.xHalfPixels, vertex.yHalfPixels),
          ),
        )
        .toList(growable: false);
    if (loop.length < 3 || _signedDoubledArea(loop) == BigInt.zero) continue;
    loops.add(List<TerrainPoint>.unmodifiable(loop));
    for (final point in loop) {
      supportYTicks = supportYTicks == null
          ? point.yTicks
          : math.max(supportYTicks, point.yTicks);
    }
  }
  if (loops.isEmpty) return null;
  final supports = <_HorizontalSupport>[];
  for (final loop in loops) {
    for (var index = 0; index < loop.length; index += 1) {
      final start = loop[index];
      final end = loop[(index + 1) % loop.length];
      if (start.yTicks != supportYTicks || end.yTicks != supportYTicks) {
        continue;
      }
      final minX = math.min(start.xTicks, end.xTicks);
      final maxX = math.max(start.xTicks, end.xTicks);
      if (minX == maxX) continue;
      supports.add(_HorizontalSupport(minXTicks: minX, maxXTicks: maxX));
    }
  }
  return _PrefabSurfaceProfile(
    loops: List<List<TerrainPoint>>.unmodifiable(loops),
    supports: List<_HorizontalSupport>.unmodifiable(supports),
    supportYTicks: supportYTicks!,
  );
}

List<List<TerrainPoint>> _translateLoops(
  List<List<TerrainPoint>> loops, {
  required int x,
  required int y,
}) {
  final dx = x * terrainPhysicsTicksPerWorldUnit;
  final dy = y * terrainPhysicsTicksPerWorldUnit;
  return List<List<TerrainPoint>>.unmodifiable(
    loops.map(
      (loop) => List<TerrainPoint>.unmodifiable(
        loop.map((point) => TerrainPoint(point.xTicks + dx, point.yTicks + dy)),
      ),
    ),
  );
}

bool _isInBounds(
  List<List<TerrainPoint>> loops, {
  required int chunkWidth,
  required int chunkHeight,
}) {
  final maxX = chunkWidth * terrainPhysicsTicksPerWorldUnit;
  final maxY = chunkHeight * terrainPhysicsTicksPerWorldUnit;
  return loops.every(
    (loop) => loop.every(
      (point) =>
          point.xTicks >= 0 &&
          point.xTicks <= maxX &&
          point.yTicks >= 0 &&
          point.yTicks <= maxY,
    ),
  );
}

bool _overlapsAny(
  List<List<TerrainPoint>> loops,
  List<TerrainPolygon> obstacles,
) {
  for (final loop in loops) {
    final loopBounds = _bounds(loop);
    for (final obstacle in obstacles) {
      if (!_boundsIntersect(loopBounds, _bounds(obstacle.vertices))) continue;
      if (TerrainPolygonOverlap.physicsLoops(loop, obstacle.vertices)) {
        return true;
      }
    }
  }
  return false;
}

(int, int, int, int) _bounds(List<TerrainPoint> loop) {
  var minX = loop.first.xTicks;
  var minY = loop.first.yTicks;
  var maxX = minX;
  var maxY = minY;
  for (final point in loop.skip(1)) {
    minX = math.min(minX, point.xTicks);
    minY = math.min(minY, point.yTicks);
    maxX = math.max(maxX, point.xTicks);
    maxY = math.max(maxY, point.yTicks);
  }
  return (minX, minY, maxX, maxY);
}

bool _boundsIntersect((int, int, int, int) left, (int, int, int, int) right) =>
    left.$1 <= right.$3 &&
    left.$3 >= right.$1 &&
    left.$2 <= right.$4 &&
    left.$4 >= right.$2;

BigInt _signedDoubledArea(List<TerrainPoint> loop) {
  var area = BigInt.zero;
  for (var index = 0; index < loop.length; index += 1) {
    final current = loop[index];
    final next = loop[(index + 1) % loop.length];
    area +=
        BigInt.from(current.xTicks) * BigInt.from(next.yTicks) -
        BigInt.from(next.xTicks) * BigInt.from(current.yTicks);
  }
  return area;
}

final class _SurfaceCandidate implements Comparable<_SurfaceCandidate> {
  const _SurfaceCandidate({
    required this.placement,
    required this.loops,
    required this.edge,
    required this.supportIndex,
    required this.distanceTicks,
  });

  final PlacedPrefabDef placement;
  final List<List<TerrainPoint>> loops;
  final TerrainEdge edge;
  final int supportIndex;
  final int distanceTicks;

  @override
  int compareTo(_SurfaceCandidate other) {
    final distanceOrder = distanceTicks.compareTo(other.distanceTicks);
    if (distanceOrder != 0) return distanceOrder;
    final edgeOrder = edge.id.compareTo(other.edge.id);
    return edgeOrder != 0
        ? edgeOrder
        : supportIndex.compareTo(other.supportIndex);
  }
}
