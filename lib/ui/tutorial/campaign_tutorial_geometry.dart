import 'dart:ui';

import 'package:runner_core/snapshots/camera_snapshot.dart';
import 'package:runner_core/snapshots/entity_render_snapshot.dart';
import 'package:runner_content_pipeline/campaign_tutorial.dart';

import '../../game/spatial/world_view_transform.dart';
import '../viewport/viewport_metrics.dart';

/// The camera canvas can extend beyond a device in pixel-perfect cover mode.
/// Guidance must use the visible intersection, just as rendering and input do.
Rect campaignTutorialVisibleWorldBounds(
  CameraSnapshot camera,
  ViewportMetrics metrics,
  Size surfaceSize,
) {
  final visible = Rect.fromLTWH(
    metrics.offsetX,
    metrics.offsetY,
    metrics.viewW,
    metrics.viewH,
  ).intersect(Offset.zero & surfaceSize);
  final sx = camera.viewWidth / metrics.viewW;
  final sy = camera.viewHeight / metrics.viewH;
  return Rect.fromLTRB(
    camera.left + (visible.left - metrics.offsetX) * sx,
    camera.top + (visible.top - metrics.offsetY) * sy,
    camera.left + (visible.right - metrics.offsetX) * sx,
    camera.top + (visible.bottom - metrics.offsetY) * sy,
  );
}

/// Projects a chunk-authored visual target into the same fitted HUD coordinates
/// as gameplay. The host's calibrated display transform applies afterwards.
Rect campaignTutorialWorldTarget(
  Rect world,
  CameraSnapshot camera,
  ViewportMetrics metrics,
) {
  final view = WorldViewTransform(
    cameraCenterX: camera.centerX,
    cameraCenterY: camera.centerY,
    viewWidth: camera.viewWidth,
    viewHeight: camera.viewHeight,
  );
  final sx = metrics.viewW / camera.viewWidth;
  final sy = metrics.viewH / camera.viewHeight;
  return Rect.fromLTWH(
    metrics.offsetX + view.worldToViewX(world.left) * sx,
    metrics.offsetY + view.worldToViewY(world.top) * sy,
    world.width * sx,
    world.height * sy,
  );
}

/// Resolves authored fractions in the same logical space as the real HUD.
Rect tutorialSpotlightRect(Rect target, TutorialSpotlight spotlight) =>
    Rect.fromLTWH(
      target.left + target.width * spotlight.x,
      target.top + target.height * spotlight.y,
      target.width * spotlight.width,
      target.height * spotlight.height,
    );

/// Uses the current vulnerable body rather than the sprite's render anchor.
Rect campaignTutorialEntityBounds(EntityRenderSnapshot entity) {
  if (entity.combatCapsules.isNotEmpty) {
    return entity.combatCapsules
        .map(
          (c) => Rect.fromLTRB(
            entity.pos.x + c.minX,
            entity.pos.y + c.minY,
            entity.pos.x + c.maxX,
            entity.pos.y + c.maxY,
          ),
        )
        .reduce((a, b) => a.expandToInclude(b));
  }
  return Rect.fromCenter(
    center: Offset(entity.pos.x, entity.pos.y),
    width: entity.size?.x ?? 48,
    height: entity.size?.y ?? 64,
  );
}
