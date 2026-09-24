import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:runner_core/contracts/render_anim_set_definition.dart';
import 'package:runner_core/snapshots/enums.dart';

import 'deterministic_anim_view.dart';
import 'sprite_anim_set.dart';
import 'strip_animation_loader.dart';

/// Shared autonomous actor sprite loading; identity stays in the typed registry.
class ActorRenderEntry {
  ActorRenderEntry({required this.renderAnim, required double scale})
    : renderScale = Vector2.all(scale);

  final RenderAnimSetDefinition renderAnim;
  final Vector2 renderScale;
  SpriteAnimSet? _animSet;
  bool get isRenderable => _animSet != null;
  SpriteAnimSet get animSet =>
      _animSet ??
      (throw StateError('Actor sprite animations have not been loaded.'));

  Future<void> load(Images images) async {
    final idle = renderAnim.sourcesByKey[AnimKey.idle];
    if (idle == null || idle.trim().isEmpty) return;
    _animSet = await loadAnimSetFromDefinition(
      images,
      renderAnim: renderAnim,
      oneShotKeys: const {
        AnimKey.strike,
        AnimKey.cast,
        AnimKey.backStrike,
        AnimKey.strike2,
        AnimKey.teleportOut,
        AnimKey.ambush,
        AnimKey.hit,
        AnimKey.death,
      },
    );
  }

  DeterministicAnimView createView() => DeterministicAnimView(
    animSet: animSet,
    renderSize: Vector2(animSet.frameSize.x, animSet.frameSize.y),
    renderScale: renderScale,
  );
}

/// Catalog-driven preload and view lookup shared by enemy and allied actors.
class ActorRenderRegistry<Id extends Enum> {
  ActorRenderRegistry(Map<Id, ActorRenderEntry> entries)
    : _entries = Map.unmodifiable(entries);
  final Map<Id, ActorRenderEntry> _entries;

  ActorRenderEntry? entryFor(Id id) {
    final entry = _entries[id];
    return entry != null && entry.isRenderable ? entry : null;
  }

  Iterable<String> get assetPaths =>
      _entries.values.expand((entry) => entry.renderAnim.sourcesByKey.values);

  Future<void> load(Images images) async {
    for (final entry in _entries.values) {
      await entry.load(images);
    }
  }
}
