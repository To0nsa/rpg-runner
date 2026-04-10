import 'package:flame/components.dart';
import 'package:flutter/widgets.dart';

import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/snapshots/entity_render_snapshot.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/snapshots/static_prefab_sprite_snapshot.dart';
import 'package:runner_core/snapshots/static_solid_snapshot.dart';

import '../components/static_prefab_sprite_component.dart';
import '../components/player/player_view.dart';
import '../components/enemies/enemy_render_registry.dart';
import '../components/pickups/pickup_render_registry.dart';
import '../components/projectiles/projectile_render_registry.dart';
import '../components/sprite_anim/deterministic_anim_view.dart';
import '../components/sprite_anim/sprite_anim_set.dart';
import '../debug/render_debug_flags.dart';
import '../game_controller.dart';
import '../spatial/world_view_transform.dart';
import '../tuning/combat_feedback_tuning.dart';
import '../util/math_util.dart' as math;
import 'render_constants.dart';

/// Owns live run entity view pools and static/hitbox synchronization.
class LiveWorldSyncSystem {
  LiveWorldSyncSystem({
    required this.controller,
    required this.world,
    required this.playerCharacter,
    required EnemyRenderRegistry enemyRenderRegistry,
    required ProjectileRenderRegistry projectileRenderRegistry,
    required PickupRenderRegistry pickupRenderRegistry,
    required CombatFeedbackTuning combatFeedbackTuning,
  }) : _enemyRenderRegistry = enemyRenderRegistry,
       _projectileRenderRegistry = projectileRenderRegistry,
       _pickupRenderRegistry = pickupRenderRegistry,
       _combatFeedbackTuning = combatFeedbackTuning;

  final GameController controller;
  final Component world;
  final PlayerCharacterDefinition playerCharacter;

  final EnemyRenderRegistry _enemyRenderRegistry;
  final ProjectileRenderRegistry _projectileRenderRegistry;
  final PickupRenderRegistry _pickupRenderRegistry;
  final CombatFeedbackTuning _combatFeedbackTuning;

  late final PlayerView _player;
  final Map<_StaticPrefabSpriteKey, StaticPrefabSpriteComponent>
  _staticPrefabSpritesByKey =
      <_StaticPrefabSpriteKey, StaticPrefabSpriteComponent>{};
  List<_StaticPrefabSpriteKey> _staticPrefabSpriteOrder =
      const <_StaticPrefabSpriteKey>[];
  List<StaticPrefabSpriteSnapshot>? _lastStaticPrefabSpritesSnapshot;

  final List<RectangleComponent> _staticSolids = <RectangleComponent>[];
  List<StaticSolidSnapshot>? _lastStaticSolidsSnapshot;

  final Map<int, DeterministicAnimView> _projectileAnimViews =
      <int, DeterministicAnimView>{};
  final Map<int, DeterministicAnimView> _pickupAnimViews =
      <int, DeterministicAnimView>{};
  final Map<int, DeterministicAnimView> _enemies =
      <int, DeterministicAnimView>{};
  final Map<int, RectangleComponent> _hitboxes = <int, RectangleComponent>{};
  final Map<int, RectangleComponent> _actorHitboxes =
      <int, RectangleComponent>{};
  final Map<int, int> _projectileSpawnTicks = <int, int>{};
  final Set<int> _seenIdsScratch = <int>{};
  final List<int> _toRemoveScratch = <int>[];
  final Vector2 _snapScratch = Vector2.zero();

  final Paint _hitboxPaint = Paint()..color = const Color(0x66EF4444);
  final Paint _actorHitboxPaint = Paint()
    ..color = const Color(0xFF22C55E)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  PlayerView get playerView => _player;

  Map<int, DeterministicAnimView> get enemyViews => _enemies;

  Map<int, RectangleComponent> get actorHitboxes => _actorHitboxes;

  Paint get actorHitboxPaint => _actorHitboxPaint;

  bool get hasTriggerHitboxes => _hitboxes.isNotEmpty;

  bool get _drawStaticSolids =>
      RenderDebugFlags.canUseRenderDebug && RenderDebugFlags.drawStaticSolids;

  void mountPlayer(SpriteAnimSet playerAnimations) {
    _player = PlayerView(
      animationSet: playerAnimations,
      renderScale: Vector2.all(runnerPlayerRenderTuning.scale),
      feedbackTuning: _combatFeedbackTuning,
    )..priority = priorityPlayer;
    world.add(_player);
  }

  void mountStaticSolids(List<StaticSolidSnapshot> solids) {
    if (!_drawStaticSolids) {
      _lastStaticSolidsSnapshot = solids;
      return;
    }
    if (solids.isEmpty) {
      return;
    }
    _lastStaticSolidsSnapshot = solids;

    for (final solid in solids) {
      final color = solid.oneWayTop
          ? const Color(0x6648BB78)
          : const Color(0x668B5CF6);

      final rect = RectangleComponent(
        position: Vector2(solid.minX, solid.minY),
        size: Vector2(solid.maxX - solid.minX, solid.maxY - solid.minY),
        paint: Paint()..color = color,
      )..priority = priorityStaticSolids;
      _staticSolids.add(rect);
      world.add(rect);
    }
  }

  void mountStaticPrefabSprites(List<StaticPrefabSpriteSnapshot> sprites) {
    syncStaticPrefabSprites(sprites);
  }

  void syncStaticPrefabSprites(List<StaticPrefabSpriteSnapshot> sprites) {
    if (identical(sprites, _lastStaticPrefabSpritesSnapshot)) {
      return;
    }
    _lastStaticPrefabSpritesSnapshot = sprites;

    final nextOrder = <_StaticPrefabSpriteKey>[];
    final nextKeys = <_StaticPrefabSpriteKey>{};

    for (final sprite in sprites) {
      final key = _StaticPrefabSpriteKey.fromSnapshot(sprite);
      nextOrder.add(key);
      nextKeys.add(key);
      if (_staticPrefabSpritesByKey.containsKey(key)) {
        continue;
      }

      final view = StaticPrefabSpriteComponent(
        assetPath: sprite.assetPath,
        srcRect: Rect.fromLTWH(
          sprite.srcX.toDouble(),
          sprite.srcY.toDouble(),
          sprite.srcWidth.toDouble(),
          sprite.srcHeight.toDouble(),
        ),
        position: Vector2(sprite.x, sprite.y),
        size: Vector2(sprite.width, sprite.height),
      )..priority = priorityStaticSolids + sprite.zIndex;
      _staticPrefabSpritesByKey[key] = view;
      world.add(view);
    }

    final staleKeys = _staticPrefabSpritesByKey.keys
        .where((key) => !nextKeys.contains(key))
        .toList(growable: false);
    for (final key in staleKeys) {
      _staticPrefabSpritesByKey.remove(key)?.removeFromParent();
    }

    _staticPrefabSpriteOrder = List<_StaticPrefabSpriteKey>.unmodifiable(
      nextOrder,
    );
  }

  void snapStaticPrefabSprites(
    List<StaticPrefabSpriteSnapshot> sprites, {
    required Vector2 cameraCenter,
    required int virtualWidth,
    required int virtualHeight,
  }) {
    if (sprites.isEmpty || _staticPrefabSpriteOrder.length != sprites.length) {
      return;
    }
    final transform = WorldViewTransform(
      cameraCenterX: cameraCenter.x,
      cameraCenterY: cameraCenter.y,
      viewWidth: virtualWidth.toDouble(),
      viewHeight: virtualHeight.toDouble(),
    );

    for (final sprite in sprites) {
      final key = _StaticPrefabSpriteKey.fromSnapshot(sprite);
      final view = _staticPrefabSpritesByKey[key];
      if (view == null) {
        continue;
      }
      view.position.setValues(
        math.snapWorldToPixelsInViewX(sprite.x, transform),
        math.snapWorldToPixelsInViewY(sprite.y, transform),
      );
    }
  }

  void syncStaticSolids(List<StaticSolidSnapshot> solids) {
    if (!_drawStaticSolids) {
      _lastStaticSolidsSnapshot = solids;
      if (_staticSolids.isNotEmpty) {
        for (final view in _staticSolids) {
          view.removeFromParent();
        }
        _staticSolids.clear();
      }
      return;
    }
    if (identical(solids, _lastStaticSolidsSnapshot)) {
      return;
    }
    _lastStaticSolidsSnapshot = solids;

    for (final view in _staticSolids) {
      view.removeFromParent();
    }
    _staticSolids.clear();

    mountStaticSolids(solids);
  }

  void snapStaticSolids(
    List<StaticSolidSnapshot> solids, {
    required Vector2 cameraCenter,
    required int virtualWidth,
    required int virtualHeight,
  }) {
    if (solids.isEmpty || _staticSolids.length != solids.length) {
      return;
    }
    final transform = WorldViewTransform(
      cameraCenterX: cameraCenter.x,
      cameraCenterY: cameraCenter.y,
      viewWidth: virtualWidth.toDouble(),
      viewHeight: virtualHeight.toDouble(),
    );

    for (var i = 0; i < solids.length; i++) {
      final solid = solids[i];
      final view = _staticSolids[i];
      view.position.setValues(
        math.snapWorldToPixelsInViewX(solid.minX, transform),
        math.snapWorldToPixelsInViewY(solid.minY, transform),
      );
    }
  }

  void syncPlayer({
    required EntityRenderSnapshot? player,
    required Map<int, EntityRenderSnapshot> prevById,
    required double alpha,
    required Vector2 cameraCenter,
  }) {
    if (player == null) {
      return;
    }
    final prev = prevById[player.id] ?? player;
    final worldX = math.lerpDouble(prev.pos.x, player.pos.x, alpha);
    final worldY = math.lerpDouble(prev.pos.y, player.pos.y, alpha);
    _snapScratch.setValues(
      math.snapWorldToPixelsInCameraSpace1d(worldX, cameraCenter.x),
      math.snapWorldToPixelsInCameraSpace1d(worldY, cameraCenter.y),
    );
    _player.applySnapshot(player, tickHz: controller.tickHz, pos: _snapScratch);
    _player.setStatusVisualMask(player.statusVisualMask);
  }

  void syncEnemies(
    List<EntityRenderSnapshot> entities, {
    required Map<int, EntityRenderSnapshot> prevById,
    required double alpha,
    required Vector2 cameraCenter,
  }) {
    final seen = _seenIdsScratch..clear();

    for (final entity in entities) {
      if (entity.kind != EntityKind.enemy) {
        continue;
      }

      final entry = entity.enemyId == null
          ? null
          : _enemyRenderRegistry.entryFor(entity.enemyId!);
      if (entry == null) {
        _enemies.remove(entity.id)?.removeFromParent();
        continue;
      }

      seen.add(entity.id);

      var view = _enemies[entity.id];
      if (view == null) {
        view = entry.viewFactory(entry.animSet, entry.renderScale)
          ..priority = priorityEnemies
          ..setFeedbackTuning(_combatFeedbackTuning);
        _enemies[entity.id] = view;
        world.add(view);
      }

      final prev = prevById[entity.id] ?? entity;
      final worldX = math.lerpDouble(prev.pos.x, entity.pos.x, alpha);
      final worldY = math.lerpDouble(prev.pos.y, entity.pos.y, alpha);
      _snapScratch.setValues(
        math.snapWorldToPixelsInCameraSpace1d(worldX, cameraCenter.x),
        math.snapWorldToPixelsInCameraSpace1d(worldY, cameraCenter.y),
      );
      view.applySnapshot(entity, tickHz: controller.tickHz, pos: _snapScratch);
      view.setStatusVisualMask(entity.statusVisualMask);
    }

    if (_enemies.isEmpty) {
      return;
    }
    final toRemove = _toRemoveScratch..clear();
    for (final id in _enemies.keys) {
      if (!seen.contains(id)) {
        toRemove.add(id);
      }
    }
    for (final id in toRemove) {
      _enemies.remove(id)?.removeFromParent();
    }
  }

  void syncProjectiles(
    List<EntityRenderSnapshot> entities, {
    required Map<int, EntityRenderSnapshot> prevById,
    required double alpha,
    required Vector2 cameraCenter,
    required int tick,
  }) {
    final seen = _seenIdsScratch..clear();

    for (final entity in entities) {
      if (entity.kind != EntityKind.projectile) {
        continue;
      }
      seen.add(entity.id);

      final entry = entity.projectileId == null
          ? null
          : _projectileRenderRegistry.entryFor(entity.projectileId!);

      if (entry != null) {
        var view = _projectileAnimViews[entity.id];
        if (view == null) {
          view = entry.viewFactory(entry.animSet, entry.renderScale)
            ..priority = priorityProjectiles;
          _projectileAnimViews[entity.id] = view;
          _projectileSpawnTicks[entity.id] = tick;
          world.add(view);
        }

        final prev = prevById[entity.id] ?? entity;
        final worldX = math.lerpDouble(prev.pos.x, entity.pos.x, alpha);
        final worldY = math.lerpDouble(prev.pos.y, entity.pos.y, alpha);
        _snapScratch.setValues(
          math.snapWorldToPixelsInCameraSpace1d(worldX, cameraCenter.x),
          math.snapWorldToPixelsInCameraSpace1d(worldY, cameraCenter.y),
        );

        final spawnTick = _projectileSpawnTicks[entity.id] ?? tick;
        final startTicks = entry.spawnAnimTicks(controller.tickHz);
        final ageTicks = tick - spawnTick;
        final animOverride =
            startTicks > 0 && ageTicks >= 0 && ageTicks < startTicks
            ? AnimKey.spawn
            : AnimKey.idle;
        final overrideAnimFrame = animOverride == AnimKey.spawn
            ? ageTicks
            : null;

        view.applySnapshot(
          entity,
          tickHz: controller.tickHz,
          pos: _snapScratch,
          overrideAnim: animOverride,
          overrideAnimFrame: overrideAnimFrame,
        );

        final spinSpeed = entry.spinSpeedRadPerSecond;
        if (spinSpeed == 0.0) {
          view.angle = entity.rotationRad;
        } else {
          final spinSeconds = (ageTicks.toDouble() + alpha) / controller.tickHz;
          view.angle = entity.rotationRad + spinSpeed * spinSeconds;
        }
      } else {
        _projectileAnimViews.remove(entity.id)?.removeFromParent();
        _projectileSpawnTicks.remove(entity.id);
      }
    }

    if (_projectileAnimViews.isEmpty) {
      return;
    }
    final toRemove = _toRemoveScratch..clear();
    for (final id in _projectileAnimViews.keys) {
      if (!seen.contains(id)) {
        toRemove.add(id);
      }
    }
    for (final id in toRemove) {
      _projectileAnimViews.remove(id)?.removeFromParent();
      _projectileSpawnTicks.remove(id);
    }
  }

  void syncCollectibles(
    List<EntityRenderSnapshot> entities, {
    required Map<int, EntityRenderSnapshot> prevById,
    required double alpha,
    required Vector2 cameraCenter,
  }) {
    final seen = _seenIdsScratch..clear();

    for (final entity in entities) {
      if (entity.kind != EntityKind.pickup) {
        continue;
      }
      seen.add(entity.id);

      final variant = entity.pickupVariant ?? PickupVariant.collectible;
      final entry = _pickupRenderRegistry.entryForVariant(variant);

      var view = _pickupAnimViews[entity.id];
      if (view == null) {
        view = entry.viewFactory(entry.animSet, entry.renderScale)
          ..priority = priorityCollectibles;
        _pickupAnimViews[entity.id] = view;
        world.add(view);
      }

      final prev = prevById[entity.id] ?? entity;
      final worldX = math.lerpDouble(prev.pos.x, entity.pos.x, alpha);
      final worldY = math.lerpDouble(prev.pos.y, entity.pos.y, alpha);
      _snapScratch.setValues(
        math.snapWorldToPixelsInCameraSpace1d(worldX, cameraCenter.x),
        math.snapWorldToPixelsInCameraSpace1d(worldY, cameraCenter.y),
      );
      view.applySnapshot(entity, tickHz: controller.tickHz, pos: _snapScratch);
      view.angle = entity.rotationRad;
    }

    if (_pickupAnimViews.isEmpty) {
      return;
    }
    final toRemove = _toRemoveScratch..clear();
    for (final id in _pickupAnimViews.keys) {
      if (!seen.contains(id)) {
        toRemove.add(id);
      }
    }
    for (final id in toRemove) {
      _pickupAnimViews.remove(id)?.removeFromParent();
    }
  }

  void syncTriggerHitboxes(
    List<EntityRenderSnapshot> entities, {
    required Map<int, EntityRenderSnapshot> prevById,
    required double alpha,
    required Vector2 cameraCenter,
  }) {
    final seen = _seenIdsScratch..clear();

    for (final entity in entities) {
      if (entity.kind != EntityKind.trigger) {
        continue;
      }
      seen.add(entity.id);

      var view = _hitboxes[entity.id];
      if (view == null) {
        final size = entity.size;
        view = RectangleComponent(
          size: Vector2(size?.x ?? 8.0, size?.y ?? 8.0),
          anchor: Anchor.center,
          paint: _hitboxPaint,
        )..priority = priorityHitboxes;
        _hitboxes[entity.id] = view;
        world.add(view);
      } else {
        final size = entity.size;
        if (size != null) {
          view.size.setValues(size.x, size.y);
        }
      }

      final prev = prevById[entity.id] ?? entity;
      final worldX = math.lerpDouble(prev.pos.x, entity.pos.x, alpha);
      final worldY = math.lerpDouble(prev.pos.y, entity.pos.y, alpha);
      view.position.setValues(
        math.snapWorldToPixelsInCameraSpace1d(worldX, cameraCenter.x),
        math.snapWorldToPixelsInCameraSpace1d(worldY, cameraCenter.y),
      );
    }

    if (_hitboxes.isEmpty) {
      return;
    }
    final toRemove = _toRemoveScratch..clear();
    for (final id in _hitboxes.keys) {
      if (!seen.contains(id)) {
        toRemove.add(id);
      }
    }
    for (final id in toRemove) {
      _hitboxes.remove(id)?.removeFromParent();
    }
  }

  void clearTriggerHitboxes() {
    if (_hitboxes.isEmpty) {
      return;
    }
    for (final view in _hitboxes.values) {
      view.removeFromParent();
    }
    _hitboxes.clear();
  }
}

class _StaticPrefabSpriteKey {
  const _StaticPrefabSpriteKey({
    required this.assetPath,
    required this.srcX,
    required this.srcY,
    required this.srcWidth,
    required this.srcHeight,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.zIndex,
  });

  factory _StaticPrefabSpriteKey.fromSnapshot(StaticPrefabSpriteSnapshot s) {
    return _StaticPrefabSpriteKey(
      assetPath: s.assetPath,
      srcX: s.srcX,
      srcY: s.srcY,
      srcWidth: s.srcWidth,
      srcHeight: s.srcHeight,
      x: s.x,
      y: s.y,
      width: s.width,
      height: s.height,
      zIndex: s.zIndex,
    );
  }

  final String assetPath;
  final int srcX;
  final int srcY;
  final int srcWidth;
  final int srcHeight;
  final double x;
  final double y;
  final double width;
  final double height;
  final int zIndex;

  @override
  bool operator ==(Object other) {
    return other is _StaticPrefabSpriteKey &&
        other.assetPath == assetPath &&
        other.srcX == srcX &&
        other.srcY == srcY &&
        other.srcWidth == srcWidth &&
        other.srcHeight == srcHeight &&
        other.x == x &&
        other.y == y &&
        other.width == width &&
        other.height == height &&
        other.zIndex == zIndex;
  }

  @override
  int get hashCode => Object.hash(
    assetPath,
    srcX,
    srcY,
    srcWidth,
    srcHeight,
    x,
    y,
    width,
    height,
    zIndex,
  );
}
