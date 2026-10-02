import 'package:flame/components.dart';
import 'package:runner_core/interactions/world_interaction_render_catalog.dart';
import 'package:runner_core/snapshots/world_interaction_snapshot.dart';

import '../../runner_flame/render_constants.dart';
import '../../util/math_util.dart' as math;
import 'world_interaction_render_registry.dart';

/// Snapshot-owned effects, reconstructed on mount and retired with visibility.
/// Flame time never activates an object or advances its simulation clock.
final class WorldInteractionRenderSystem {
  WorldInteractionRenderSystem({required this.world, required this.registry});
  final Component world;
  final WorldInteractionRenderRegistry registry;
  final Map<String, SpriteComponent> _views = {};

  void sync(
    List<WorldInteractionSnapshot> interactions, {
    required int tickHz,
    required Vector2 cameraCenter,
  }) {
    final seen = <String>{};
    for (final interaction in interactions) {
      if (!interaction.active) continue;
      seen.add(interaction.instanceId);
      final def = WorldInteractionRenderCatalog.get(interaction.interactionId);
      final sprite = registry.frame(
        interaction.interactionId,
        def.frameAtTick(interaction.elapsedTicks, tickHz),
      );
      final view = _views.putIfAbsent(interaction.instanceId, () {
        final component = SpriteComponent(
          anchor: Anchor(
            def.anchor.x / def.source.width,
            def.anchor.y / def.source.height,
          ),
        );
        world.add(component);
        return component;
      });
      view.sprite = sprite;
      view.size.setFrom(sprite.srcSize * (def.worldScale * interaction.scale));
      view.priority = priorityStaticPrefabs + interaction.zIndex;
      view.position.setValues(
        math.snapWorldToPixelsInCameraSpace1d(interaction.x, cameraCenter.x),
        math.snapWorldToPixelsInCameraSpace1d(
          interaction.y + def.surfaceOffsetY * interaction.scale,
          cameraCenter.y,
        ),
      );
    }
    for (final id in _views.keys.where((id) => !seen.contains(id)).toList()) {
      _views.remove(id)!.removeFromParent();
    }
  }
}
