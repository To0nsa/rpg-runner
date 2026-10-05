/// Projectile render registry and loaders (render layer only).
library;

import 'package:flame/cache.dart';
import 'package:flame/components.dart';

import 'package:runner_core/contracts/render_anim_set_definition.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/projectiles/projectile_render_catalog.dart';
import 'package:runner_core/snapshots/enums.dart';

import '../sprite_anim/deterministic_anim_view.dart';
import '../sprite_anim/sprite_anim_set.dart';
import '../sprite_anim/strip_animation_loader.dart';

typedef ProjectileAnimLoader = Future<SpriteAnimSet> Function(
  Images images, {
  required RenderAnimSetDefinition renderAnim,
  required Set<AnimKey> oneShotKeys,
});

typedef ProjectileViewFactory = DeterministicAnimView Function(
  SpriteAnimSet animSet,
  Vector2 renderScale,
);

const Set<AnimKey> _defaultProjectileOneShotKeys = <AnimKey>{
  AnimKey.spawn,
  AnimKey.hit,
};

DeterministicAnimView _defaultProjectileViewFactory(
  SpriteAnimSet animSet,
  Vector2 renderScale,
) {
  return DeterministicAnimView(
    animSet: animSet,
    renderSize: Vector2(animSet.frameSize.x, animSet.frameSize.y),
    renderScale: renderScale,
    respectFacing: false,
  );
}

class ProjectileRenderEntry {
  ProjectileRenderEntry({
    required this.id,
    required this.renderScale,
    this.oneShotKeys = _defaultProjectileOneShotKeys,
    this.loader = loadAnimSetFromDefinition,
    this.viewFactory = _defaultProjectileViewFactory,
  });

  final ProjectileId id;
  final Vector2 renderScale;
  final Set<AnimKey> oneShotKeys;
  final ProjectileAnimLoader loader;
  final ProjectileViewFactory viewFactory;

  SpriteAnimSet? _animSet;
  bool _hasAssets = true;

  bool get hasAssets => _hasAssets;

  bool get isLoaded => _animSet != null;

  bool get isRenderable => _hasAssets && _animSet != null;

  SpriteAnimSet get animSet {
    final value = _animSet;
    if (value == null) {
      throw StateError('ProjectileRenderEntry($id) has not been loaded yet.');
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

/// Render registry for projectiles (ProjectileId -> render wiring).
class ProjectileRenderRegistry {
  ProjectileRenderRegistry({
    ProjectileRenderCatalog projectileCatalog = const ProjectileRenderCatalog(),
  }) : _projectileCatalog = projectileCatalog;

  final ProjectileRenderCatalog _projectileCatalog;

  final Map<ProjectileId, ProjectileRenderEntry> _entries =
      <ProjectileId, ProjectileRenderEntry>{
        ProjectileId.npcSpear: ProjectileRenderEntry(
          id: ProjectileId.npcSpear,
          renderScale: Vector2.all(
            ProjectileRenderCatalog.scaleFor(ProjectileId.npcSpear),
          ),
        ),
        ProjectileId.npcArrow: ProjectileRenderEntry(
          id: ProjectileId.npcArrow,
          renderScale: Vector2.all(
            ProjectileRenderCatalog.scaleFor(ProjectileId.npcArrow),
          ),
        ),
        ProjectileId.poisonDart: ProjectileRenderEntry(
          id: ProjectileId.poisonDart,
          renderScale: Vector2.all(
            ProjectileRenderCatalog.scaleFor(ProjectileId.poisonDart),
          ),
        ),
        ProjectileId.iceBolt: ProjectileRenderEntry(
          id: ProjectileId.iceBolt,
          renderScale: Vector2.all(
            ProjectileRenderCatalog.scaleFor(ProjectileId.iceBolt),
          ),
        ),
        ProjectileId.thunderBolt: ProjectileRenderEntry(
          id: ProjectileId.thunderBolt,
          renderScale: Vector2.all(
            ProjectileRenderCatalog.scaleFor(ProjectileId.thunderBolt),
          ),
        ),
        ProjectileId.fireBolt: ProjectileRenderEntry(
          id: ProjectileId.fireBolt,
          renderScale: Vector2.all(
            ProjectileRenderCatalog.scaleFor(ProjectileId.fireBolt),
          ),
        ),
        ProjectileId.acidBolt: ProjectileRenderEntry(
          id: ProjectileId.acidBolt,
          renderScale: Vector2.all(
            ProjectileRenderCatalog.scaleFor(ProjectileId.acidBolt),
          ),
        ),
        ProjectileId.darkBolt: ProjectileRenderEntry(
          id: ProjectileId.darkBolt,
          renderScale: Vector2.all(
            ProjectileRenderCatalog.scaleFor(ProjectileId.darkBolt),
          ),
        ),
        ProjectileId.earthBolt: ProjectileRenderEntry(
          id: ProjectileId.earthBolt,
          renderScale: Vector2.all(
            ProjectileRenderCatalog.scaleFor(ProjectileId.earthBolt),
          ),
        ),
        ProjectileId.holyBolt: ProjectileRenderEntry(
          id: ProjectileId.holyBolt,
          renderScale: Vector2.all(
            ProjectileRenderCatalog.scaleFor(ProjectileId.holyBolt),
          ),
        ),
        ProjectileId.waterBolt: ProjectileRenderEntry(
          id: ProjectileId.waterBolt,
          renderScale: Vector2.all(
            ProjectileRenderCatalog.scaleFor(ProjectileId.waterBolt),
          ),
        ),
      };

  ProjectileRenderEntry? entryFor(ProjectileId id) {
    final entry = _entries[id];
    if (entry == null || !entry.isRenderable) return null;
    return entry;
  }

  /// Exact image sources preloaded by this registry.
  Iterable<String> get assetPaths => _entries.values.expand(
    (entry) => _projectileCatalog.get(entry.id).sourcesByKey.values,
  );

  Future<void> load(Images images) async {
    for (final entry in _entries.values) {
      final renderAnim = _projectileCatalog.get(entry.id);
      await entry.load(images, renderAnim: renderAnim);
    }
  }
}
