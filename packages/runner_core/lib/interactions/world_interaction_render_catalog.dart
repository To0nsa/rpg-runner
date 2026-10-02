import '../contracts/render_frame_rect.dart';
import '../util/vec2.dart';
import 'world_interaction_catalog.dart';

/// Pure appearance metadata shared by asset validation and the Flame registry.
/// The reviewed frames keep their original bytes; one common crop and pivot
/// preserve the source animation's alignment without per-frame recentering.
final class WorldInteractionRenderDefinition {
  const WorldInteractionRenderDefinition({
    required this.assetPaths,
    required this.source,
    required this.anchor,
    required this.worldScale,
    this.surfaceOffsetY = 0,
  });

  final List<String> assetPaths;
  final RenderFrameRect source;
  final Vec2 anchor;
  final double worldScale;
  final double surfaceOffsetY;

  /// Ten frames/second sampled from frozen simulation elapsed ticks.
  int frameAtTick(int elapsedTicks, int tickHz) =>
      (elapsedTicks * 10 ~/ tickHz) % assetPaths.length;
}

abstract final class WorldInteractionRenderCatalog {
  static WorldInteractionRenderDefinition get(WorldInteractionId id) =>
      switch (id) {
        WorldInteractionId.regenerationShrine =>
          const WorldInteractionRenderDefinition(
            assetPaths: [
              'entities/effects/world_interactions/fire_01.png',
              'entities/effects/world_interactions/fire_02.png',
              'entities/effects/world_interactions/fire_03.png',
              'entities/effects/world_interactions/fire_04.png',
            ],
            source: RenderFrameRect(586, 586, 134, 156),
            anchor: Vec2(67, 154),
            worldScale: 0.2,
            // Embed the flame base slightly in the bowl's rim, in world units.
            surfaceOffsetY: 1,
          ),
      };

  static Iterable<String> get assetPaths =>
      WorldInteractionId.values.expand((id) => get(id).assetPaths);
}
