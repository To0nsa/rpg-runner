import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:runner_core/contracts/render_anim_set_definition.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/traps/trap_catalog.dart';
import 'package:runner_core/traps/trap_id.dart';

import '../sprite_anim/strip_animation_loader.dart';

/// Loads catalog rectangles through the shared animation loader. Core alone
/// selects the frame; the registry never advances an animation ticker.
final class TrapRenderRegistry {
  final Map<TrapId, List<Sprite>> _frames = {};
  Iterable<String> get assetPaths =>
      TrapId.values.map((id) => TrapCatalog.get(id).assetPath);
  Sprite frame(TrapId id, int frameIndex) => _frames[id]![frameIndex];

  Future<void> load(Images images) async {
    for (final id in TrapId.values) {
      final def = TrapCatalog.get(id);
      final first = def.frames.first.source;
      final anim = await loadAnimSetFromDefinition(
        images,
        renderAnim: RenderAnimSetDefinition(
          frameWidth: first.width,
          frameHeight: first.height,
          anchorPoint: def.anchor,
          sourcesByKey: {AnimKey.idle: def.assetPath},
          sourceFramesByKey: {
            AnimKey.idle: [for (final frame in def.frames) frame.source],
          },
          frameCountsByKey: {AnimKey.idle: def.frames.length},
          stepTimeSecondsByKey: const {AnimKey.idle: 0.1},
        ),
        oneShotKeys: const {},
      );
      _frames[id] = List.unmodifiable(
        anim.animations[AnimKey.idle]!.frames.map((frame) => frame.sprite),
      );
    }
  }
}
