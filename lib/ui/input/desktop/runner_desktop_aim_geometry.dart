import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:runner_core/snapshots/camera_snapshot.dart';

import '../../../game/spatial/world_view_transform.dart';
import '../../viewport/viewport_metrics.dart';

/// Immutable fitted-viewport geometry for desktop pointer aim.
///
/// All positions are logical pixels in the input region's local coordinate
/// system. The player point is the rendered, pixel-snapped position so cursor
/// direction stays aligned with the Flame view across DPI and letterboxing.
@immutable
final class RunnerDesktopAimGeometry {
  const RunnerDesktopAimGeometry({
    required this.viewportRect,
    required this.playerPosition,
  });

  /// Builds aim geometry from authoritative camera/player world coordinates.
  ///
  /// [ViewportMetrics] already includes device-pixel-ratio fitting. The world
  /// point is snapped in view space to match the renderer's camera-relative
  /// pixel snapping before it is scaled into logical viewport coordinates.
  factory RunnerDesktopAimGeometry.fromWorld({
    required ViewportMetrics metrics,
    required CameraSnapshot camera,
    required Offset playerWorldPosition,
  }) {
    final transform = WorldViewTransform(
      cameraCenterX: camera.centerX,
      cameraCenterY: camera.centerY,
      viewWidth: camera.viewWidth,
      viewHeight: camera.viewHeight,
    );
    final playerViewX = transform
        .worldToViewX(playerWorldPosition.dx)
        .roundToDouble();
    final playerViewY = transform
        .worldToViewY(playerWorldPosition.dy)
        .roundToDouble();
    final viewportRect = Rect.fromLTWH(
      metrics.offsetX,
      metrics.offsetY,
      metrics.viewW,
      metrics.viewH,
    );

    return RunnerDesktopAimGeometry(
      viewportRect: viewportRect,
      playerPosition: Offset(
        viewportRect.left + playerViewX * metrics.viewW / camera.viewWidth,
        viewportRect.top + playerViewY * metrics.viewH / camera.viewHeight,
      ),
    );
  }

  /// Bounds of the fitted game view, excluding letterbox and host chrome.
  final Rect viewportRect;

  /// Rendered player point in the input region's logical coordinates.
  final Offset playerPosition;

  /// Whether [localPosition] belongs to the fitted gameplay viewport.
  bool contains(Offset localPosition) => viewportRect.contains(localPosition);

  /// Returns a normalized cursor direction, or `null` outside/at the player.
  Offset? directionFor(Offset localPosition) {
    if (!contains(localPosition)) return null;
    final delta = localPosition - playerPosition;
    final length = math.sqrt(delta.dx * delta.dx + delta.dy * delta.dy);
    if (length == 0) return null;
    return Offset(delta.dx / length, delta.dy / length);
  }
}
