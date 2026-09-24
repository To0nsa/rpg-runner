import 'dart:ui';

import 'package:flame/components.dart';
import 'package:runner_core/snapshots/trap_snapshot.dart';
import 'package:runner_core/traps/trap_catalog.dart';

import '../util/math_util.dart' as math;
import 'render_debug_flags.dart';
import 'trap_damage_painter.dart';

/// Exact trap hitboxes behind the existing non-release hitbox debug toggle.
/// Camera-space placement keeps the overlay aligned with rendered trap art.
final class TrapHitboxOverlay extends Component {
  List<TrapSnapshot> traps = const [];
  final Vector2 cameraCenter = Vector2.zero();

  @override
  void render(Canvas canvas) {
    if (!RenderDebugFlags.canUseRenderDebug ||
        !RenderDebugFlags.drawActorHitboxes) {
      return;
    }
    for (final trap in traps) {
      final definition = TrapCatalog.get(trap.source.trapId);
      final x = math.snapWorldToPixelsInCameraSpace1d(trap.x, cameraCenter.x);
      final y = math.snapWorldToPixelsInCameraSpace1d(trap.y, cameraCenter.y);
      paintTrapDamagePose(
        canvas,
        definition: definition,
        frameIndex: trap.frameIndex,
        x: x,
        y: y,
        facing: trap.facing,
      );
    }
  }
}
