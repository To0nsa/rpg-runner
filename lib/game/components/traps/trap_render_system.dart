import 'package:flame/components.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/snapshots/trap_snapshot.dart';
import 'package:runner_core/traps/trap_catalog.dart';
import 'package:runner_core/traps/trap_placement.dart';

import '../../runner_flame/render_constants.dart';
import '../../util/math_util.dart' as math;
import 'trap_render_registry.dart';

/// Bounded view pool keyed by immutable streamed placement identity.
final class TrapRenderSystem {
  TrapRenderSystem({required this.world, required this.registry});
  final Component world;
  final TrapRenderRegistry registry;
  final Map<TrapSourceRef, SpriteComponent> _views = {};

  void sync(List<TrapSnapshot> traps, {required Vector2 cameraCenter}) {
    final seen = <TrapSourceRef>{};
    for (final trap in traps) {
      seen.add(trap.source);
      final def = TrapCatalog.get(trap.source.trapId);
      final sprite = registry.frame(trap.source.trapId, trap.frameIndex);
      final view = _views.putIfAbsent(trap.source, () {
        final component = SpriteComponent(
          size: sprite.srcSize.clone(),
          anchor: Anchor(
            def.anchor.x / sprite.srcSize.x,
            def.anchor.y / sprite.srcSize.y,
          ),
        );
        world.add(component);
        return component;
      });
      view.sprite = sprite;
      view.priority = switch (trap.phase) {
        TrapPhase.warning || TrapPhase.active => priorityActiveTraps,
        _ => priorityIdleTraps,
      };
      view.scale.x = trap.facing == Facing.left ? -1 : 1;
      view.position.setValues(
        math.snapWorldToPixelsInCameraSpace1d(trap.x, cameraCenter.x),
        math.snapWorldToPixelsInCameraSpace1d(trap.y, cameraCenter.y),
      );
    }
    for (final key
        in _views.keys.where((key) => !seen.contains(key)).toList()) {
      _views.remove(key)!.removeFromParent();
    }
  }
}
