import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';

import '../../../../chunks/chunk_marker_authoring_catalog.dart';
import '../../../../chunks/chunk_v2_marker_placement_projection.dart';
import '../../../../chunks/chunk_domain_models.dart';
import '../../shared/editor_scene_view_utils.dart';
import '../../shared/terrain_polygon_scene_painter.dart';
import 'chunk_enemy_idle_frame.dart';

/// Loads and paints runtime-faithful enemy sprites behind marker evidence.
///
/// Decoded images are scoped to the current repository workspace. Accepted
/// placements use their exact resolved body center, rejected placements use
/// the attempted body center, and outcomes without a static body use their
/// authored marker anchor as a muted reference.
class ChunkMarkerPlacementOverlay extends StatefulWidget {
  const ChunkMarkerPlacementOverlay({
    super.key,
    required this.workspaceRootPath,
    required this.projection,
    required this.transform,
    this.selectedMarkerKey,
    this.suppressedMarkerKey,
    this.showResolvedEvidence = true,
  });

  final String workspaceRootPath;
  final ChunkV2MarkerPlacementProjection projection;
  final TerrainPolygonViewportTransform transform;
  final String? selectedMarkerKey;
  final String? suppressedMarkerKey;
  final bool showResolvedEvidence;

  @override
  State<ChunkMarkerPlacementOverlay> createState() =>
      _ChunkMarkerPlacementOverlayState();
}

class _ChunkMarkerPlacementOverlayState
    extends State<ChunkMarkerPlacementOverlay> {
  late EditorUiImageCache _imageCache;
  var _loadEpoch = 0;

  @override
  void initState() {
    super.initState();
    _imageCache = EditorUiImageCache();
    _ensureImagesLoaded();
  }

  @override
  void didUpdateWidget(covariant ChunkMarkerPlacementOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceRootPath != widget.workspaceRootPath) {
      _loadEpoch += 1;
      _imageCache.dispose();
      _imageCache = EditorUiImageCache();
      _ensureImagesLoaded();
      return;
    }
    if (!identical(oldWidget.projection, widget.projection) ||
        (!oldWidget.showResolvedEvidence && widget.showResolvedEvidence)) {
      _ensureImagesLoaded();
    }
  }

  @override
  void dispose() {
    _loadEpoch += 1;
    _imageCache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imagesByPath = <String, ui.Image>{};
    for (final frame in _requiredFrames()) {
      final image = _imageCache.imageFor(frame.absoluteSourcePath);
      if (image != null) imagesByPath[frame.absoluteSourcePath] = image;
    }
    return CustomPaint(
      key: const ValueKey<String>('chunk_marker_placement_overlay'),
      painter: ChunkMarkerPlacementOverlayPainter(
        projection: widget.projection,
        transform: widget.transform,
        workspaceRootPath: widget.workspaceRootPath,
        enemyImagesByPath: imagesByPath,
        selectedMarkerKey: widget.selectedMarkerKey,
        suppressedMarkerKey: widget.suppressedMarkerKey,
        showResolvedEvidence: widget.showResolvedEvidence,
      ),
    );
  }

  Iterable<ChunkEnemyIdleFrame> _requiredFrames() sync* {
    final seenPaths = <String>{};
    for (final outcome in widget.projection.outcomes) {
      if (outcome.enemyId == null) continue;
      final enemy = chunkMarkerEnemyCatalogEntryFor(outcome.enemyId!.name);
      if (enemy == null) continue;
      final frame = ChunkEnemyIdleFrame.fromEnemy(
        enemy: enemy,
        workspaceRootPath: widget.workspaceRootPath,
      );
      if (frame != null && seenPaths.add(frame.absoluteSourcePath)) yield frame;
    }
  }

  void _ensureImagesLoaded() {
    if (!widget.showResolvedEvidence) return;
    final paths = _requiredFrames()
        .map((frame) => frame.absoluteSourcePath)
        .toSet();
    if (paths.isEmpty) return;
    final epoch = ++_loadEpoch;
    unawaited(() async {
      await Future.wait(paths.map(_imageCache.ensureLoaded));
      if (mounted && epoch == _loadEpoch) setState(() {});
    }());
  }
}

/// Read-only marker anchors and exact Core placement evidence.
class ChunkMarkerPlacementOverlayPainter extends CustomPainter {
  const ChunkMarkerPlacementOverlayPainter({
    required this.projection,
    required this.transform,
    this.workspaceRootPath = '',
    this.enemyImagesByPath = const <String, ui.Image>{},
    this.selectedMarkerKey,
    this.suppressedMarkerKey,
    this.showResolvedEvidence = true,
  });

  final ChunkV2MarkerPlacementProjection projection;
  final TerrainPolygonViewportTransform transform;
  final String workspaceRootPath;
  final Map<String, ui.Image> enemyImagesByPath;
  final String? selectedMarkerKey;
  final String? suppressedMarkerKey;
  final bool showResolvedEvidence;

  /// Number of recognized outcomes with a decoded, valid idle frame.
  ///
  /// Accepted sprites use exact resolved bodies. Rejected sprites use their
  /// attempted bodies; deferred or otherwise body-less sprites use their
  /// authored anchors as visibly muted references.
  int get enemySpriteCount {
    var count = 0;
    for (final outcome in projection.outcomes) {
      if (_enemySpriteFor(outcome) != null) count += 1;
    }
    return count;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (showResolvedEvidence) {
      for (final outcome in projection.outcomes) {
        if (outcome.selectionKey == suppressedMarkerKey) continue;
        _paintEnemySprite(canvas, outcome);
      }
    }
    for (final outcome in projection.outcomes) {
      if (outcome.selectionKey == suppressedMarkerKey) continue;
      _paintOutcome(
        canvas,
        outcome,
        selected: outcome.selectionKey == selectedMarkerKey,
        showResolvedEvidence: showResolvedEvidence,
      );
    }
  }

  void _paintEnemySprite(Canvas canvas, ChunkV2MarkerPlacementOutcome outcome) {
    final sprite = _enemySpriteFor(outcome);
    if (sprite == null) return;
    canvas.drawImageRect(
      sprite.image,
      sprite.frame.sourceRect,
      sprite.frame.runtimeDestination(
        bodyPoint: sprite.bodyPoint,
        sceneZoom: transform.zoom,
      ),
      Paint()
        ..filterQuality = FilterQuality.none
        ..color = Colors.white.withValues(alpha: sprite.opacity),
    );
  }

  ({
    ui.Image image,
    ChunkEnemyIdleFrame frame,
    Offset bodyPoint,
    double opacity,
  })?
  _enemySpriteFor(ChunkV2MarkerPlacementOutcome outcome) {
    if (outcome.enemyId == null) return null;
    final enemy = chunkMarkerEnemyCatalogEntryFor(outcome.enemyId!.name);
    if (enemy == null) return null;
    final frame = ChunkEnemyIdleFrame.fromEnemy(
      enemy: enemy,
      workspaceRootPath: workspaceRootPath,
    );
    if (frame == null) return null;
    final image = enemyImagesByPath[frame.absoluteSourcePath];
    if (image == null || !frame.fits(image)) return null;
    return (
      image: image,
      frame: frame,
      bodyPoint: _enemySpriteBodyPoint(outcome),
      opacity: _enemySpriteOpacity(outcome),
    );
  }

  Offset _enemySpriteBodyPoint(ChunkV2MarkerPlacementOutcome outcome) {
    final body =
        outcome.result?.bodyCenter ?? outcome.result?.requestedBodyCenter;
    if (body != null) return _toCanvas(body);
    return _worldToCanvas(
      outcome.marker.x.toDouble(),
      outcome.marker.y.toDouble(),
    );
  }

  double _enemySpriteOpacity(ChunkV2MarkerPlacementOutcome outcome) {
    if (outcome.accepted && !outcome.deferred) return 1;
    return switch (outcome.disposition) {
      ChunkV2MarkerPlacementDisposition.deferredGuaranteed ||
      ChunkV2MarkerPlacementDisposition.deferredConditional => 0.68,
      ChunkV2MarkerPlacementDisposition.guaranteedRejected ||
      ChunkV2MarkerPlacementDisposition.conditionalRejected => 0.58,
      ChunkV2MarkerPlacementDisposition.disabled => 0.45,
      ChunkV2MarkerPlacementDisposition.malformed => 0.52,
      _ => 1,
    };
  }

  void _paintOutcome(
    Canvas canvas,
    ChunkV2MarkerPlacementOutcome outcome, {
    required bool selected,
    required bool showResolvedEvidence,
  }) {
    final color = _dispositionColor(outcome.disposition);
    final anchor = _worldToCanvas(
      outcome.marker.x.toDouble(),
      outcome.marker.y.toDouble(),
    );
    final intendedSurface = outcome.intendedSurface;
    if (showResolvedEvidence && intendedSurface != null) {
      canvas.drawLine(
        _toCanvas(intendedSurface.start),
        _toCanvas(intendedSurface.end),
        Paint()
          ..strokeWidth = selected ? 6 : 4
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: selected ? 0.95 : 0.66),
      );
    }

    final result = outcome.result;
    final profile = outcome.profile;
    final body = result?.bodyCenter ?? result?.requestedBodyCenter;
    if (showResolvedEvidence && body != null && profile != null) {
      final bodyCanvas = _toCanvas(body);
      canvas.drawLine(
        anchor,
        bodyCanvas,
        Paint()
          ..strokeWidth = selected ? 2.5 : 1.5
          ..color = color.withValues(alpha: 0.75),
      );
      final capsuleCenter = body.translated(
        profile.capsule.resolvedOffsetXTicks,
        profile.capsule.offsetYTicks,
      );
      _drawCapsule(
        canvas,
        center: capsuleCenter,
        radiusTicks: profile.capsule.radiusTicks,
        verticalHalfSegmentTicks: profile.capsule.verticalHalfSegmentTicks,
        color: color,
        selected: selected,
        rejected: result?.accepted == false,
      );
    }

    final anchorPaint = Paint()
      ..color = color
      ..style = outcome.deferred ? PaintingStyle.stroke : PaintingStyle.fill
      ..strokeWidth = selected ? 3 : 2;
    final radius = selected ? 7.0 : 5.0;
    if (outcome.disposition == ChunkV2MarkerPlacementDisposition.malformed) {
      canvas.drawLine(
        anchor - Offset(radius, radius),
        anchor + Offset(radius, radius),
        anchorPaint,
      );
      canvas.drawLine(
        anchor + Offset(radius, -radius),
        anchor + Offset(-radius, radius),
        anchorPaint,
      );
    } else if (outcome.deferred) {
      final path = Path()
        ..moveTo(anchor.dx, anchor.dy - radius)
        ..lineTo(anchor.dx + radius, anchor.dy)
        ..lineTo(anchor.dx, anchor.dy + radius)
        ..lineTo(anchor.dx - radius, anchor.dy)
        ..close();
      canvas.drawPath(path, anchorPaint);
    } else {
      canvas.drawCircle(anchor, radius, anchorPaint);
    }
  }

  void _drawCapsule(
    Canvas canvas, {
    required TerrainPoint center,
    required int radiusTicks,
    required int verticalHalfSegmentTicks,
    required Color color,
    required bool selected,
    required bool rejected,
  }) {
    final centerCanvas = _toCanvas(center);
    final radius =
        radiusTicks / terrainPhysicsTicksPerWorldUnit * transform.zoom;
    final halfHeight =
        (radiusTicks + verticalHalfSegmentTicks) /
        terrainPhysicsTicksPerWorldUnit *
        transform.zoom;
    final bounds = Rect.fromLTRB(
      centerCanvas.dx - radius,
      centerCanvas.dy - halfHeight,
      centerCanvas.dx + radius,
      centerCanvas.dy + halfHeight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds, Radius.circular(radius)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 3 : 2
        ..color = color.withValues(alpha: rejected ? 0.78 : 1),
    );
    if (rejected) {
      canvas.drawLine(
        bounds.topLeft,
        bounds.bottomRight,
        Paint()
          ..strokeWidth = selected ? 3 : 2
          ..color = color.withValues(alpha: 0.9),
      );
      canvas.drawLine(
        bounds.topRight,
        bounds.bottomLeft,
        Paint()
          ..strokeWidth = selected ? 3 : 2
          ..color = color.withValues(alpha: 0.9),
      );
    }
  }

  Color _dispositionColor(ChunkV2MarkerPlacementDisposition disposition) =>
      switch (disposition) {
        ChunkV2MarkerPlacementDisposition.guaranteedAccepted => const Color(
          0xFF4ADE80,
        ),
        ChunkV2MarkerPlacementDisposition.conditionalAccepted => const Color(
          0xFF67E8F9,
        ),
        ChunkV2MarkerPlacementDisposition.guaranteedRejected => const Color(
          0xFFF87171,
        ),
        ChunkV2MarkerPlacementDisposition.conditionalRejected => const Color(
          0xFFFBBF24,
        ),
        ChunkV2MarkerPlacementDisposition.disabled => const Color(0xFF94A3B8),
        ChunkV2MarkerPlacementDisposition.deferredGuaranteed ||
        ChunkV2MarkerPlacementDisposition.deferredConditional => const Color(
          0xFFC4B5FD,
        ),
        ChunkV2MarkerPlacementDisposition.malformed => const Color(0xFFFF4D8D),
      };

  Offset _toCanvas(TerrainPoint point) => Offset(
    transform.origin.dx +
        point.xTicks / terrainPhysicsTicksPerWorldUnit * transform.zoom,
    transform.origin.dy +
        point.yTicks / terrainPhysicsTicksPerWorldUnit * transform.zoom,
  );

  Offset _worldToCanvas(double x, double y) => Offset(
    transform.origin.dx + x * transform.zoom,
    transform.origin.dy + y * transform.zoom,
  );

  @override
  bool shouldRepaint(
    covariant ChunkMarkerPlacementOverlayPainter oldDelegate,
  ) =>
      !identical(projection, oldDelegate.projection) ||
      selectedMarkerKey != oldDelegate.selectedMarkerKey ||
      suppressedMarkerKey != oldDelegate.suppressedMarkerKey ||
      showResolvedEvidence != oldDelegate.showResolvedEvidence ||
      workspaceRootPath != oldDelegate.workspaceRootPath ||
      !mapEquals(enemyImagesByPath, oldDelegate.enemyImagesByPath) ||
      transform != oldDelegate.transform;
}

/// Draws one route-local authored marker anchor without accepted Core evidence.
final class ChunkMarkerAnchorPreviewPainter extends CustomPainter {
  const ChunkMarkerAnchorPreviewPainter({
    required this.marker,
    required this.transform,
  });

  final PlacedMarkerDef marker;
  final TerrainPolygonViewportTransform transform;

  @override
  void paint(Canvas canvas, Size size) {
    final anchor = Offset(
      transform.origin.dx + marker.x * transform.zoom,
      transform.origin.dy + marker.y * transform.zoom,
    );
    final paint = Paint()
      ..color = const Color(0xFF81D4FA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(anchor, 8, paint);
    canvas.drawLine(
      anchor - const Offset(12, 0),
      anchor + const Offset(12, 0),
      paint,
    );
    canvas.drawLine(
      anchor - const Offset(0, 12),
      anchor + const Offset(0, 12),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant ChunkMarkerAnchorPreviewPainter oldDelegate) =>
      oldDelegate.marker != marker || oldDelegate.transform != transform;
}
