import 'dart:ui';

import 'package:flame/components.dart';
import 'package:runner_core/snapshots/trap_snapshot.dart';
import 'package:runner_core/traps/trap_catalog.dart';

import '../../util/math_util.dart' as math;
import 'trap_cue_painter.dart';

/// Mount on CameraComponent.viewfinder: Flame draws it after the complete world
/// under the same camera transform, and before viewport/screen HUD content.
final class TrapCueOverlay extends Component {
  List<TrapSnapshot> traps = const [];
  final Vector2 cameraCenter = Vector2.zero();
  bool drawDamagePoses = false;

  @override
  void render(Canvas canvas) {
    for (final trap in traps) {
      final definition = TrapCatalog.get(trap.source.trapId);
      final x = math.snapWorldToPixelsInCameraSpace1d(trap.x, cameraCenter.x);
      final y = math.snapWorldToPixelsInCameraSpace1d(trap.y, cameraCenter.y);
      if (drawDamagePoses) {
        paintTrapDamagePose(
          canvas,
          definition: definition,
          frameIndex: trap.frameIndex,
          x: x,
          y: y,
          facing: trap.facing,
        );
      }
      paintTrapCue(
        canvas,
        definition: definition,
        x: x,
        y: y,
        facing: trap.facing,
        phase: trap.phase,
      );
    }
  }
}
