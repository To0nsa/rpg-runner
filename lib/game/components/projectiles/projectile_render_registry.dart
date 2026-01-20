/// Projectile render registry and loaders (render layer only).
library;

import 'dart:math';

import 'package:flame/cache.dart';
import 'package:flame/components.dart';

import '../../../core/contracts/render_anim_set_definition.dart';
import '../../../core/projectiles/projectile_id.dart';
import '../../../core/projectiles/projectile_render_catalog.dart';
import '../../../core/snapshots/enums.dart';
import '../sprite_anim/deterministic_anim_view_component.dart';
import '../sprite_anim/sprite_anim_set.dart';
import '../sprite_anim/strip_animation_loader.dart';

typedef ProjectileAnimLoader =
    Future<SpriteAnimSet> Function(
      Images images, {
      required RenderAnimSetDefinition renderAnim,
      required Set<AnimKey> oneShotKeys,
    });

typedef ProjectileViewFactory =
    DeterministicAnimViewComponent Function(
      SpriteAnimSet animSet,
      Vector2 renderScale,
    );

const Set<AnimKey> _defaultProjectileOneShotKeys = <AnimKey>{
  AnimKey.spawn,
  AnimKey.hit,
};

DeterministicAnimViewComponent _defaultProjectileViewFactory(
  SpriteAnimSet animSet,
  Vector2 renderScale,
) {
  return DeterministicAnimViewComponent(
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
    this.spinSpeedRadPerSecond = 0.0,
  });

  final ProjectileId id;
  final Vector2 renderScale;
  final Set<AnimKey> oneShotKeys;
  final ProjectileAnimLoader loader;
  final ProjectileViewFactory viewFactory;
  final double spinSpeedRadPerSecond;

  SpriteAnimSet? _animSet;
  bool _hasAssets = true;
  final Map<int, int> _spawnAnimTicksCache = <int, int>{};

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

  int spawnAnimTicks(int tickHz) {
    final cached = _spawnAnimTicksCache[tickHz];
    if (cached != null) return cached;

    final set = _animSet;
    if (set == null) return 0;
    final anim = set.animations[AnimKey.spawn];
    if (anim == null) return 0;
    final frameCount = anim.frames.length;
    if (frameCount <= 1) return 0;

    final ticksPerFrame = set.ticksPerFrameFor(AnimKey.spawn, tickHz);
    final totalTicks = ticksPerFrame * frameCount;
    _spawnAnimTicksCache[tickHz] = totalTicks;
    return totalTicks;
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

  static const double _throwingAxeSpinRps = 6.0;
  static const double _throwingKnifeSpinRps = 7.0;

  final Map<ProjectileId, ProjectileRenderEntry> _entries =
      <ProjectileId, ProjectileRenderEntry>{
        ProjectileId.iceBolt: ProjectileRenderEntry(
          id: ProjectileId.iceBolt,
          renderScale: Vector2.all(1.0),
        ),
        ProjectileId.thunderBolt: ProjectileRenderEntry(
          id: ProjectileId.thunderBolt,
          renderScale: Vector2.all(1.0),
        ),
        ProjectileId.fireBolt: ProjectileRenderEntry(
          id: ProjectileId.fireBolt,
          renderScale: Vector2.all(1.0),
        ),
        ProjectileId.throwingAxe: ProjectileRenderEntry(
          id: ProjectileId.throwingAxe,
          renderScale: Vector2.all(1.0),
          spinSpeedRadPerSecond: _throwingAxeSpinRps * 2.0 * pi,
        ),
        ProjectileId.throwingKnife: ProjectileRenderEntry(
          id: ProjectileId.throwingKnife,
          renderScale: Vector2.all(1.0),
          spinSpeedRadPerSecond: _throwingKnifeSpinRps * 2.0 * pi,
        ),
      };

  ProjectileRenderEntry? entryFor(ProjectileId id) {
    final entry = _entries[id];
    if (entry == null || !entry.isRenderable) return null;
    return entry;
  }

  Future<void> load(Images images) async {
    for (final entry in _entries.values) {
      final renderAnim = _projectileCatalog.get(entry.id);
      await entry.load(images, renderAnim: renderAnim);
    }
  }
}
