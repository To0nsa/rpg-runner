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
    this.colorMatrix,
  });

  final List<String> assetPaths;
  final RenderFrameRect source;
  final Vec2 anchor;
  final double worldScale;
  final double surfaceOffsetY;

  /// Optional 4x5 RGBA transform applied by the renderer, preserving source art.
  final List<double>? colorMatrix;

  /// Ten frames/second sampled from frozen simulation elapsed ticks.
  int frameAtTick(int elapsedTicks, int tickHz) =>
      (elapsedTicks * 10 ~/ tickHz) % assetPaths.length;
}

abstract final class WorldInteractionRenderCatalog {
  static const _firePaths = [
    'entities/effects/world_interactions/fire_01.png',
    'entities/effects/world_interactions/fire_02.png',
    'entities/effects/world_interactions/fire_03.png',
    'entities/effects/world_interactions/fire_04.png',
  ];

  static WorldInteractionRenderDefinition get(
    WorldInteractionAppearanceId appearanceId,
  ) => switch (appearanceId) {
    WorldInteractionAppearanceId.emberFlame =>
      const WorldInteractionRenderDefinition(
        assetPaths: _firePaths,
        source: RenderFrameRect(586, 586, 134, 156),
        anchor: Vec2(67, 154),
        worldScale: 0.2,
        surfaceOffsetY: 1,
      ),
    WorldInteractionAppearanceId.blueFlame =>
      const WorldInteractionRenderDefinition(
        assetPaths: _firePaths,
        source: RenderFrameRect(586, 586, 134, 156),
        anchor: Vec2(67, 154),
        worldScale: 0.15,
        surfaceOffsetY: 1,
        // Map the orange edge and yellow core to blue and pale cyan.
        colorMatrix: [
          0.10,
          0.50,
          0,
          0,
          0,
          0.20,
          0.80,
          0,
          0,
          0,
          0.65,
          0.55,
          0,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ],
      ),
  };

  static Iterable<String> get assetPaths => WorldInteractionAppearanceId.values
      .expand((id) => get(id).assetPaths)
      .toSet();
}
