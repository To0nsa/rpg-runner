/// Spell-impact render registry and loaders (render layer only).
library;

import 'package:flame/cache.dart';
import 'package:flame/components.dart';

import 'package:runner_core/contracts/render_anim_set_definition.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/spell_impacts/spell_impact_id.dart';
import 'package:runner_core/spell_impacts/spell_impact_render_catalog.dart';
import '../sprite_anim/sprite_anim_set.dart';
import '../sprite_anim/strip_animation_loader.dart';

typedef SpellImpactAnimLoader =
    Future<SpriteAnimSet> Function(
      Images images, {
      required RenderAnimSetDefinition renderAnim,
      required Set<AnimKey> oneShotKeys,
    });

const Set<AnimKey> _defaultSpellImpactOneShotKeys = <AnimKey>{AnimKey.hit};

class SpellImpactRenderEntry {
  SpellImpactRenderEntry({
    required this.id,
    required this.renderScale,
    this.oneShotKeys = _defaultSpellImpactOneShotKeys,
    this.loader = loadAnimSetFromDefinition,
  });

  final SpellImpactId id;
  final Vector2 renderScale;
  final Set<AnimKey> oneShotKeys;
  final SpellImpactAnimLoader loader;

  SpriteAnimSet? _animSet;
  bool _hasAssets = true;

  bool get hasAssets => _hasAssets;
  bool get isLoaded => _animSet != null;
  bool get isRenderable => _hasAssets && _animSet != null;

  SpriteAnimSet get animSet {
    final value = _animSet;
    if (value == null) {
      throw StateError('SpellImpactRenderEntry($id) has not been loaded yet.');
    }
    return value;
  }

  Future<void> load(
    Images images, {
    required RenderAnimSetDefinition renderAnim,
  }) async {
    final hitPath = renderAnim.sourcesByKey[AnimKey.hit];
    if (hitPath == null || hitPath.trim().isEmpty) {
      _hasAssets = false;
      _animSet = null;
      return;
    }
    _animSet = await loader(
      images,
      renderAnim: renderAnim,
      oneShotKeys: oneShotKeys,
    );
  }
}

/// Render registry for spell impacts (SpellImpactId -> render wiring).
class SpellImpactRenderRegistry {
  SpellImpactRenderRegistry({
    SpellImpactRenderCatalog impactCatalog = const SpellImpactRenderCatalog(),
  }) : _impactCatalog = impactCatalog;

  final SpellImpactRenderCatalog _impactCatalog;

  final Map<SpellImpactId, SpellImpactRenderEntry> _entries =
      <SpellImpactId, SpellImpactRenderEntry>{
        SpellImpactId.fireExplosion: SpellImpactRenderEntry(
          id: SpellImpactId.fireExplosion,
          renderScale: Vector2.all(1.0),
        ),
      };

  SpellImpactRenderEntry? entryFor(SpellImpactId id) {
    final entry = _entries[id];
    if (entry == null || !entry.isRenderable) return null;
    return entry;
  }

  Future<void> load(Images images) async {
    for (final entry in _entries.values) {
      final renderAnim = _impactCatalog.get(entry.id);
      await entry.load(images, renderAnim: renderAnim);
    }
  }
}
