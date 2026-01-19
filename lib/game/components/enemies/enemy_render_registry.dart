/// Enemy render registry and loaders (render layer only).
library;

import 'package:flame/cache.dart';
import 'package:flame/components.dart';

import '../../../core/contracts/render_anim_set_definition.dart';
import '../../../core/enemies/enemy_catalog.dart';
import '../../../core/enemies/enemy_id.dart';
import '../../../core/snapshots/enums.dart';
import '../sprite_anim/deterministic_anim_view_component.dart';
import '../sprite_anim/sprite_anim_set.dart';
import '../sprite_anim/strip_animation_loader.dart';

typedef EnemyAnimLoader =
    Future<SpriteAnimSet> Function(
      Images images, {
      required RenderAnimSetDefinition renderAnim,
      required Set<AnimKey> oneShotKeys,
    });

typedef EnemyViewFactory =
    DeterministicAnimViewComponent Function(
      SpriteAnimSet animSet,
      Vector2 renderScale,
    );

enum EnemyDeathAnimPolicy { spawn, none }

const Set<AnimKey> _defaultEnemyOneShotKeys = <AnimKey>{
  AnimKey.attack,
  AnimKey.hit,
  AnimKey.death,
};

DeterministicAnimViewComponent _defaultEnemyViewFactory(
  SpriteAnimSet animSet,
  Vector2 renderScale,
) {
  return DeterministicAnimViewComponent(
    animSet: animSet,
    renderSize: Vector2(animSet.frameSize.x, animSet.frameSize.y),
    renderScale: renderScale,
  );
}

class EnemyRenderEntry {
  EnemyRenderEntry({
    required this.id,
    required this.renderScale,
    this.deathAnimPolicy = EnemyDeathAnimPolicy.spawn,
    this.oneShotKeys = _defaultEnemyOneShotKeys,
    this.loader = loadAnimSetFromDefinition,
    this.viewFactory = _defaultEnemyViewFactory,
  });

  final EnemyId id;
  final Vector2 renderScale;
  final EnemyDeathAnimPolicy deathAnimPolicy;
  final Set<AnimKey> oneShotKeys;
  final EnemyAnimLoader loader;
  final EnemyViewFactory viewFactory;

  SpriteAnimSet? _animSet;
  bool _hasAssets = true;

  bool get hasAssets => _hasAssets;

  bool get isLoaded => _animSet != null;

  bool get isRenderable => _hasAssets && _animSet != null;

  SpriteAnimSet get animSet {
    final value = _animSet;
    if (value == null) {
      throw StateError('EnemyRenderEntry($id) has not been loaded yet.');
    }
    return value;
  }

  Future<void> load(
    Images images, {
    required RenderAnimSetDefinition renderAnim,
  }) async {
    final idlePath = renderAnim.sourcesByKey[AnimKey.idle];
    if (idlePath == null || idlePath.trim().isEmpty) {
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

/// Render registry for enemies (EnemyId -> render wiring).
class EnemyRenderRegistry {
  EnemyRenderRegistry({EnemyCatalog enemyCatalog = const EnemyCatalog()})
    : _enemyCatalog = enemyCatalog;

  final EnemyCatalog _enemyCatalog;

  final Map<EnemyId, EnemyRenderEntry> _entries = <EnemyId, EnemyRenderEntry>{
    EnemyId.unocoDemon: EnemyRenderEntry(
      id: EnemyId.unocoDemon,
      renderScale: Vector2.all(0.5),
    ),
    EnemyId.groundEnemy: EnemyRenderEntry(
      id: EnemyId.groundEnemy,
      renderScale: Vector2.all(1.5),
    ),
  };

  EnemyRenderEntry? entryFor(EnemyId id) {
    final entry = _entries[id];
    if (entry == null || !entry.isRenderable) return null;
    return entry;
  }

  Future<void> load(Images images) async {
    for (final entry in _entries.values) {
      final renderAnim = _enemyCatalog.get(entry.id).renderAnim;
      await entry.load(images, renderAnim: renderAnim);
    }
  }
}
