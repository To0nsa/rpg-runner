import '../collision/static_world_geometry.dart';
import 'nav_tolerances.dart';
import 'surface_id.dart';
import 'walk_surface.dart';

class SurfaceExtractor {
  SurfaceExtractor({
    this.mergeEps = navGeomEps,
    this.groundPadding = 1024.0,
  });

  final double mergeEps;
  final double groundPadding;

  List<WalkSurface> extract(StaticWorldGeometry geometry) {
    final segments = <_SurfaceSegment>[];

    var minX = double.infinity;
    var maxX = double.negativeInfinity;
    for (var i = 0; i < geometry.solids.length; i += 1) {
      final solid = geometry.solids[i];
      if (solid.minX < minX) minX = solid.minX;
      if (solid.maxX > maxX) maxX = solid.maxX;

      if ((solid.sides & StaticSolid.sideTop) == 0) continue;

      var localSolidIndex = solid.localSolidIndex;
      if (localSolidIndex < 0) {
        if (solid.chunkIndex != StaticSolid.noChunk) {
          throw StateError(
            'Chunk solid is missing a localSolidIndex; check track streamer.',
          );
        }
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

    final groundPlane = geometry.groundPlane;
    if (groundPlane != null) {
      final baseMinX = minX.isFinite ? minX : 0.0;
      final baseMaxX = maxX.isFinite ? maxX : 0.0;
      final groundMinX = baseMinX - groundPadding;
      final groundMaxX = baseMaxX + groundPadding;
      final blockers =
          _collectGroundBlockers(geometry.solids, groundPlane.topY, mergeEps);
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

    if (segments.isEmpty) {
      return const <WalkSurface>[];
    }

    segments.sort(_compareSegments);

    final merged = <WalkSurface>[];
    var current = segments.first;
    for (var i = 1; i < segments.length; i += 1) {
      final next = segments[i];
      final sameY = (next.yTop - current.yTop).abs() <= mergeEps;
      final touches = next.xMin <= current.xMax + mergeEps;
      if (sameY && touches) {
        if (next.xMax > current.xMax) {
          current = current.copyWith(xMax: next.xMax);
        }
      } else {
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

class _SurfaceSegment {
  const _SurfaceSegment({
    required this.id,
    required this.xMin,
    required this.xMax,
    required this.yTop,
  });

  final int id;
  final double xMin;
  final double xMax;
  final double yTop;

  _SurfaceSegment copyWith({double? xMax}) {
    return _SurfaceSegment(
      id: id,
      xMin: xMin,
      xMax: xMax ?? this.xMax,
      yTop: yTop,
    );
  }
}

class _Range {
  _Range(this.min, this.max);

  double min;
  double max;
}

List<_Range> _collectGroundBlockers(
  List<StaticSolid> solids,
  double groundTopY,
  double eps,
) {
  final blockers = <_Range>[];
  for (final solid in solids) {
    final hasWalls =
        (solid.sides & (StaticSolid.sideLeft | StaticSolid.sideRight)) != 0;
    if (!hasWalls) continue;
    final touchesGround =
        solid.minY <= groundTopY + eps && solid.maxY >= groundTopY - eps;
    if (!touchesGround) continue;
    blockers.add(_Range(solid.minX, solid.maxX));
  }

  if (blockers.isEmpty) return blockers;

  blockers.sort((a, b) => a.min.compareTo(b.min));
  final merged = <_Range>[blockers.first];
  for (var i = 1; i < blockers.length; i += 1) {
    final current = blockers[i];
    final last = merged.last;
    if (current.min <= last.max + eps) {
      if (current.max > last.max) {
        last.max = current.max;
      }
    } else {
      merged.add(_Range(current.min, current.max));
    }
  }

  return merged;
}

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
    if (blocker.max <= min + eps) continue;
    if (blocker.min >= max - eps) break;
    final blockMin = blocker.min < min ? min : blocker.min;
    final blockMax = blocker.max > max ? max : blocker.max;
    if (blockMin > cursor + eps) {
      segments.add(_Range(cursor, blockMin));
    }
    if (blockMax > cursor) {
      cursor = blockMax;
    }
  }
  if (cursor < max - eps) {
    segments.add(_Range(cursor, max));
  }
  return segments;
}

int _compareSegments(_SurfaceSegment a, _SurfaceSegment b) {
  if (a.yTop < b.yTop) return -1;
  if (a.yTop > b.yTop) return 1;
  if (a.xMin < b.xMin) return -1;
  if (a.xMin > b.xMin) return 1;
  if (a.xMax < b.xMax) return -1;
  if (a.xMax > b.xMax) return 1;
  if (a.id < b.id) return -1;
  if (a.id > b.id) return 1;
  return 0;
}
