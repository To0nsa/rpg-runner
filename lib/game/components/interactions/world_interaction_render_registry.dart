import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:runner_core/interactions/world_interaction_catalog.dart';
import 'package:runner_core/interactions/world_interaction_render_catalog.dart';

/// Loads the complete frame set before gameplay, including captured editor Play.
final class WorldInteractionRenderRegistry {
  final Map<WorldInteractionId, List<Sprite>> _frames = {};
  Iterable<String> get assetPaths => WorldInteractionRenderCatalog.assetPaths;

  Sprite frame(WorldInteractionId id, int index) => _frames[id]![index];

  Future<void> load(Images images) async {
    for (final id in WorldInteractionId.values) {
      final def = WorldInteractionRenderCatalog.get(id);
      final rect = def.source;
      final frames = <Sprite>[];
      for (final path in def.assetPaths) {
        final image = await images.load(path);
        if (rect.x < 0 ||
            rect.y < 0 ||
            rect.x + rect.width > image.width ||
            rect.y + rect.height > image.height) {
          throw StateError('Interaction frame exceeds image bounds: $path');
        }
        frames.add(
          Sprite(
            image,
            srcPosition: Vector2(rect.x.toDouble(), rect.y.toDouble()),
            srcSize: Vector2(rect.width.toDouble(), rect.height.toDouble()),
          ),
        );
      }
      _frames[id] = List.unmodifiable(frames);
    }
  }
}
