import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

import '../../../../chunks/chunk_marker_authoring_catalog.dart';

/// Runtime-faithful first-idle-frame geometry for one marker enemy.
///
/// Source rectangles are sheet pixels. Runtime destinations align the Core
/// animation anchor to an already transformed body point and apply both the
/// catalog render scale and the scene zoom.
final class ChunkEnemyIdleFrame {
  ChunkEnemyIdleFrame._({
    required this.absoluteSourcePath,
    required this.sourceRect,
    required this.frameSize,
    required this.anchorPoint,
    required this.renderScale,
  });

  /// Resolves an enemy's first idle frame under the repository image root.
  ///
  /// Returns null when Core has no usable idle source path.
  static ChunkEnemyIdleFrame? fromEnemy({
    required ChunkMarkerEnemyCatalogEntry enemy,
    required String workspaceRootPath,
  }) {
    final sourcePath = enemy.previewSourcePath?.trim();
    if (sourcePath == null || sourcePath.isEmpty) return null;
    final columns = enemy.previewGridColumns;
    final startFrame = enemy.previewStartFrame;
    final column = columns == null ? startFrame : startFrame % columns;
    final rowOffset = columns == null ? 0 : startFrame ~/ columns;
    final frameSize = Size(
      enemy.renderAnim.frameWidth.toDouble(),
      enemy.renderAnim.frameHeight.toDouble(),
    );
    return ChunkEnemyIdleFrame._(
      absoluteSourcePath: p.normalize(
        p.join(workspaceRootPath, 'assets', 'images', sourcePath),
      ),
      sourceRect: Rect.fromLTWH(
        column * frameSize.width,
        (enemy.previewRow + rowOffset) * frameSize.height,
        frameSize.width,
        frameSize.height,
      ),
      frameSize: frameSize,
      anchorPoint: Offset(
        enemy.renderAnim.anchorPoint.x,
        enemy.renderAnim.anchorPoint.y,
      ),
      renderScale: enemy.renderScale,
    );
  }

  final String absoluteSourcePath;
  final Rect sourceRect;
  final Size frameSize;
  final Offset anchorPoint;
  final double renderScale;

  /// Whether [image] contains the complete authored frame rectangle.
  bool fits(ui.Image image) =>
      sourceRect.left >= 0 &&
      sourceRect.top >= 0 &&
      sourceRect.right <= image.width &&
      sourceRect.bottom <= image.height;

  /// Fits the frame inside [bounds] while preserving pixel-art proportions.
  Rect thumbnailDestination(Rect bounds, {double padding = 8}) {
    final available = Size(
      (bounds.width - padding * 2).clamp(1, double.infinity),
      (bounds.height - padding * 2).clamp(1, double.infinity),
    );
    final fitted = applyBoxFit(BoxFit.contain, frameSize, available);
    return Alignment.center.inscribe(fitted.destination, bounds);
  }

  /// Returns the canvas rectangle whose animation anchor lands on [bodyPoint].
  ///
  /// [bodyPoint] is already in canvas pixels; [sceneZoom] is canvas pixels per
  /// world pixel. The source orientation is retained because marker placement
  /// and runtime both initialize enemies facing their catalog-authored art.
  Rect runtimeDestination({
    required Offset bodyPoint,
    required double sceneZoom,
  }) {
    final canvasScale = renderScale * sceneZoom;
    return Rect.fromLTWH(
      bodyPoint.dx - anchorPoint.dx * canvasScale,
      bodyPoint.dy - anchorPoint.dy * canvasScale,
      frameSize.width * canvasScale,
      frameSize.height * canvasScale,
    );
  }
}
