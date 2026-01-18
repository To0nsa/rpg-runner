import '../collision/static_world_geometry.dart';
import 'types/nav_tolerances.dart';
import 'types/surface_id.dart';
import 'types/walk_surface.dart';

/// Extracts [WalkSurface]s from tile-based world geometry.
///
/// **Pipeline**:
/// 1. Collect top faces of solid tiles as raw segments.
/// 2. Process ground layer (explicit segments or infinite plane).
/// 3. Subtract blockers (solids/gaps) from ground.
/// 4. Sort and merge adjacent coplanar segments.
///
/// **ID Assignment**:
/// Each surface gets a unique ID via [packSurfaceId], encoding chunk and local
/// indices. This enables stable references across graph rebuilds.
class SurfaceExtractor {
  SurfaceExtractor({
    // Use a pixel-ish tolerance by default to avoid fragmenting surfaces due to
    // tiny seams (chunk boundaries, floating error, inclusive/exclusive edges).
    this.mergeEps = navSpatialEps,
    this.groundPadding = 1024.0,
  });

  /// Tolerance for merging adjacent segments (pixels).
  final double mergeEps;

  /// Horizontal padding beyond world bounds for ground plane fallback.
  final double groundPadding;

  /// Extracts walkable surfaces from [geometry].
  ///
  /// **Returns**: Unmodifiable list of [WalkSurface]s, sorted and merged.
  List<WalkSurface> extract(StaticWorldGeometry geometry) {
    final segments = <_SurfaceSegment>[];

    // Stride for ground segment IDs to avoid collisions with tile IDs.
    const groundPieceStride = 1000;

    // -------------------------------------------------------------------------
    // Step 1: Collect solid top faces.
    // -------------------------------------------------------------------------
    var minX = double.infinity;
    var maxX = double.negativeInfinity;
    for (var i = 0; i < geometry.solids.length; i += 1) {
      final solid = geometry.solids[i];

      // Track world bounds for ground plane fallback.
      if (solid.minX < minX) minX = solid.minX;
      if (solid.maxX > maxX) maxX = solid.maxX;

      // Only include solids with a walkable top face.
      if ((solid.sides & StaticSolid.sideTop) == 0) continue;

      var localSolidIndex = solid.localSolidIndex;
      if (localSolidIndex < 0) {
        if (solid.chunkIndex != StaticSolid.noChunk) {
          throw StateError(
            'Chunk solid is missing a localSolidIndex; check track streamer.',
          );
        }
        // Non-chunk solid: use array index as fallback.
        localSolidIndex = i;
      }

      final id = packSurfaceId(
        chunkIndex: solid.chunkIndex,
        localSolidIndex: localSolidIndex,
      );
      segments.add(
        _SurfaceSegment(
          id: id,
          xMin: solid.minX,
          xMax: solid.maxX,
          yTop: solid.minY,
        ),
      );
    }

    // -------------------------------------------------------------------------
    // Step 2: Process ground layer.
    // -------------------------------------------------------------------------
    if (geometry.groundSegments.isNotEmpty) {
      // Explicit ground segments (from level data).
      for (var gi = 0; gi < geometry.groundSegments.length; gi += 1) {
        final ground = geometry.groundSegments[gi];
        var localSegmentIndex = ground.localSegmentIndex;
        if (localSegmentIndex < 0) {
          if (ground.chunkIndex != StaticSolid.noChunk) {
            throw StateError(
              'Ground segment is missing a localSegmentIndex; check track streamer.',
            );
          }
          localSegmentIndex = gi;
        }

        // Subtract solids that block the ground at this Y.
        final blockers = _collectGroundBlockers(
          geometry.solids,
          const <StaticGroundGap>[],
          ground.topY,
          mergeEps,
        );
        final groundSegments = _subtractRanges(
          ground.minX,
          ground.maxX,
          blockers,
          mergeEps,
        );

        // Create surface for each unblocked portion.
        for (var i = 0; i < groundSegments.length; i += 1) {
          final seg = groundSegments[i];
          final id = packSurfaceId(
            chunkIndex: ground.chunkIndex,
            localSolidIndex: localSegmentIndex * groundPieceStride + i,
          );
          segments.add(
            _SurfaceSegment(
              id: id,
              xMin: seg.min,
              xMax: seg.max,
              yTop: ground.topY,
            ),
          );
        }
      }
    } else {
      // Infinite ground plane fallback.
      final groundPlane = geometry.groundPlane;
      if (groundPlane != null) {
        final baseMinX = minX.isFinite ? minX : 0.0;
        final baseMaxX = maxX.isFinite ? maxX : 0.0;
        final groundMinX = baseMinX - groundPadding;
        final groundMaxX = baseMaxX + groundPadding;

        final blockers = _collectGroundBlockers(
          geometry.solids,
          geometry.groundGaps,
          groundPlane.topY,
          mergeEps,
        );
        final groundSegments = _subtractRanges(
          groundMinX,
          groundMaxX,
          blockers,
          mergeEps,
        );

        for (var i = 0; i < groundSegments.length; i += 1) {
          final seg = groundSegments[i];
          segments.add(
            _SurfaceSegment(
              id: packSurfaceId(
                chunkIndex: StaticSolid.groundChunk,
                localSolidIndex: i,
              ),
              xMin: seg.min,
              xMax: seg.max,
              yTop: groundPlane.topY,
            ),
          );
        }
      }
    }

    if (segments.isEmpty) {
      return const <WalkSurface>[];
    }

    // -------------------------------------------------------------------------
    // Step 3: Sort and merge adjacent coplanar segments.
    // -------------------------------------------------------------------------
    segments.sort(_compareSegments);

    final merged = <WalkSurface>[];
    var current = segments.first;
    for (var i = 1; i < segments.length; i += 1) {
      final next = segments[i];
      final sameY = (next.yTop - current.yTop).abs() <= mergeEps;
      final touches = next.xMin <= current.xMax + mergeEps;

      if (sameY && touches) {
        // Extend current segment to include next.
        if (next.xMax > current.xMax) {
          current = current.copyWith(xMax: next.xMax);
        }
      } else {
        // Flush current, start new segment.
        merged.add(
          WalkSurface(
            id: current.id,
            xMin: current.xMin,
            xMax: current.xMax,
            yTop: current.yTop,
          ),
        );
        current = next;
      }
    }

    // Flush final segment.
    merged.add(
      WalkSurface(
        id: current.id,
        xMin: current.xMin,
        xMax: current.xMax,
        yTop: current.yTop,
      ),
    );

    return List<WalkSurface>.unmodifiable(merged);
  }
}

// =============================================================================
// Internal types
// =============================================================================

/// Intermediate segment representation before merging.
class _SurfaceSegment {
  const _SurfaceSegment({
    required this.id,
    required this.xMin,
    required this.xMax,
    required this.yTop,
  });

  /// Packed surface ID (see [packSurfaceId]).
  final int id;

  /// Left edge X coordinate.
  final double xMin;

  /// Right edge X coordinate.
  final double xMax;

  /// Top Y coordinate (walking height).
  final double yTop;

  /// Creates a copy with modified [xMax] (used during merge).
  _SurfaceSegment copyWith({double? xMax}) {
    return _SurfaceSegment(
      id: id,
      xMin: xMin,
      xMax: xMax ?? this.xMax,
      yTop: yTop,
    );
  }
}

/// Mutable horizontal range (used for blocker collection).
class _Range {
  _Range(this.min, this.max);

  double min;
  double max;
}

// =============================================================================
// Helper functions
// =============================================================================

/// Collects horizontal ranges that block the ground at [groundTopY].
///
/// Includes:
/// - Solids with left/right walls touching ground Y.
/// - Explicit ground gaps.
///
/// Returns merged, sorted list of blocking ranges.
List<_Range> _collectGroundBlockers(
  List<StaticSolid> solids,
  List<StaticGroundGap> gaps,
  double groundTopY,
  double eps,
) {
  final blockers = <_Range>[];

  // Collect solids that intersect ground level and have vertical walls.
  for (final solid in solids) {
    final hasWalls =
        (solid.sides & (StaticSolid.sideLeft | StaticSolid.sideRight)) != 0;
    if (!hasWalls) continue;

    final touchesGround =
        solid.minY <= groundTopY + eps && solid.maxY >= groundTopY - eps;
    if (!touchesGround) continue;

    blockers.add(_Range(solid.minX, solid.maxX));
  }

  // Add explicit gaps.
  for (final gap in gaps) {
    blockers.add(_Range(gap.minX, gap.maxX));
  }

  if (blockers.isEmpty) return blockers;

  // Sort and merge overlapping blockers.
  blockers.sort((a, b) => a.min.compareTo(b.min));
  final merged = <_Range>[blockers.first];
  for (var i = 1; i < blockers.length; i += 1) {
    final current = blockers[i];
    final last = merged.last;
    if (current.min <= last.max + eps) {
      // Overlapping or adjacent—extend.
      if (current.max > last.max) {
        last.max = current.max;
      }
    } else {
      merged.add(_Range(current.min, current.max));
    }
  }

  return merged;
}

/// Subtracts [blockers] from range [min, max], returning unblocked segments.
///
/// **Algorithm**:
/// Walk left-to-right, emitting segments between blocker gaps.
List<_Range> _subtractRanges(
  double min,
  double max,
  List<_Range> blockers,
  double eps,
) {
  if (blockers.isEmpty) {
    return <_Range>[_Range(min, max)];
  }

  final segments = <_Range>[];
  var cursor = min;

  for (final blocker in blockers) {
    // Skip blockers entirely before our range.
    if (blocker.max <= min + eps) continue;
    // Stop if blocker starts after our range.
    if (blocker.min >= max - eps) break;

    // Clamp blocker to our range.
    final blockMin = blocker.min < min ? min : blocker.min;
    final blockMax = blocker.max > max ? max : blocker.max;

    // Emit segment before blocker (if any).
    if (blockMin > cursor + eps) {
      segments.add(_Range(cursor, blockMin));
    }

    // Advance cursor past blocker.
    if (blockMax > cursor) {
      cursor = blockMax;
    }
  }

  // Emit trailing segment (if any).
  if (cursor < max - eps) {
    segments.add(_Range(cursor, max));
  }

  return segments;
}

/// Comparison function for sorting segments (Y, then X, then ID).
int _compareSegments(_SurfaceSegment a, _SurfaceSegment b) {
  // Primary: Y ascending (lower platforms first in screen coords).
  if (a.yTop < b.yTop) return -1;
  if (a.yTop > b.yTop) return 1;
  // Secondary: X ascending.
  if (a.xMin < b.xMin) return -1;
  if (a.xMin > b.xMin) return 1;
  // Tertiary: Width ascending.
  if (a.xMax < b.xMax) return -1;
  if (a.xMax > b.xMax) return 1;
  // Final: ID for determinism.
  if (a.id < b.id) return -1;
  if (a.id > b.id) return 1;
  return 0;
}
