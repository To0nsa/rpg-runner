import '../debug/combat_capsule_overlay.dart';

import 'package:flame/components.dart';
import 'package:flutter/widgets.dart';

import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/snapshots/entity_render_snapshot.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/snapshots/static_prefab_sprite_snapshot.dart';

import '../components/static_prefab_sprite_component.dart';
import '../components/player/player_view.dart';
import '../components/enemies/enemy_render_registry.dart';
import '../components/npcs/npc_render_registry.dart';
import '../components/npcs/npc_health_indicator.dart';
import '../components/pickups/pickup_render_registry.dart';
import '../components/projectiles/projectile_render_registry.dart';
import '../components/sprite_anim/deterministic_anim_view.dart';
import '../components/sprite_anim/sprite_anim_set.dart';
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
    required NpcRenderRegistry npcRenderRegistry,
    required ProjectileRenderRegistry projectileRenderRegistry,
    required PickupRenderRegistry pickupRenderRegistry,
    required CombatFeedbackTuning combatFeedbackTuning,
  }) : _enemyRenderRegistry = enemyRenderRegistry,
       _npcRenderRegistry = npcRenderRegistry,
       _projectileRenderRegistry = projectileRenderRegistry,
       _pickupRenderRegistry = pickupRenderRegistry,
       _combatFeedbackTuning = combatFeedbackTuning;

  final GameController controller;
  final Component world;
  final PlayerCharacterDefinition playerCharacter;

  final EnemyRenderRegistry _enemyRenderRegistry;
  final NpcRenderRegistry _npcRenderRegistry;
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

  final Map<int, DeterministicAnimView> _projectileAnimViews =
      <int, DeterministicAnimView>{};
  final Map<int, DeterministicAnimView> _pickupAnimViews =
      <int, DeterministicAnimView>{};
  final Map<int, DeterministicAnimView> _actors =
      <int, DeterministicAnimView>{};
  final Map<int, CombatCapsuleOverlay> _hitboxes =
      <int, CombatCapsuleOverlay>{};
  final Map<int, NpcHealthIndicator> _npcHealth = {};
  final Map<int, CombatCapsuleOverlay> _actorHitboxes =
      <int, CombatCapsuleOverlay>{};
  final Set<int> _seenIdsScratch = <int>{};
  final List<int> _toRemoveScratch = <int>[];
  final Vector2 _snapScratch = Vector2.zero();

  final Paint _hitboxPaint = Paint()..color = const Color(0x66EF4444);
  final Paint _actorHitboxPaint = Paint()
    ..color = const Color(0xFF22C55E)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  PlayerView get playerView => _player;

  Map<int, DeterministicAnimView> get actorViews => _actors;

  Map<int, CombatCapsuleOverlay> get actorHitboxes => _actorHitboxes;

  Paint get actorHitboxPaint => _actorHitboxPaint;

  bool get hasTriggerHitboxes => _hitboxes.isNotEmpty;

  /// Mounts the initial player view and completes after Flame loads it.
  Future<void> mountPlayer(SpriteAnimSet playerAnimations) async {
    _player = PlayerView(
      animationSet: playerAnimations,
      renderScale: Vector2.all(runnerPlayerRenderTuning.scale),
      feedbackTuning: _combatFeedbackTuning,
    )..priority = priorityPlayer;
    await world.add(_player);
  }

  /// Mounts the first static-prefab set and awaits every referenced image.
  Future<void> mountStaticPrefabSprites(
    List<StaticPrefabSpriteSnapshot> sprites,
  ) async {
    syncStaticPrefabSprites(sprites);
    await Future.wait<void>(
      _staticPrefabSpritesByKey.values.map((view) => view.loaded),
    );
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
        flipX: sprite.flipX,
        flipY: sprite.flipY,
        rotationDegrees: sprite.rotationDegrees,
      )..priority = priorityStaticPrefabs + sprite.zIndex;
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
      // Rotated module tiles share subpixel geometry. Snap the camera offset,
      // rather than each tile independently, to preserve their common pivot.
      if (sprite.rotationDegrees != 0) {
        view.position.setValues(
          sprite.x + math.snapWorldToPixelsInViewX(0, transform),
          sprite.y + math.snapWorldToPixelsInViewY(0, transform),
        );
        continue;
      }
      view.position.setValues(
        math.snapWorldToPixelsInViewX(sprite.x, transform),
        math.snapWorldToPixelsInViewY(sprite.y, transform),
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

  void syncActors(
    List<EntityRenderSnapshot> entities, {
    required Map<int, EntityRenderSnapshot> prevById,
    required double alpha,
    required Vector2 cameraCenter,
  }) {
    final seen = _seenIdsScratch..clear();

    for (final entity in entities) {
      if (entity.kind != EntityKind.enemy && entity.kind != EntityKind.npc) {
        continue;
      }

      final entry = entity.kind == EntityKind.npc
          ? (entity.npcId == null
                ? null
                : _npcRenderRegistry.entryFor(entity.npcId!))
          : (entity.enemyId == null
                ? null
                : _enemyRenderRegistry.entryFor(entity.enemyId!));
      if (entry == null) {
        _actors.remove(entity.id)?.removeFromParent();
        continue;
      }

      seen.add(entity.id);

      var view = _actors[entity.id];
      if (view == null) {
        view = entry.createView()
          ..priority = priorityEnemies
          ..setFeedbackTuning(_combatFeedbackTuning);
        _actors[entity.id] = view;
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
      if (entity.kind == EntityKind.npc) {
        final indicator = _npcHealth.putIfAbsent(entity.id, () {
          final value = NpcHealthIndicator()..priority = priorityEnemies + 1;
          world.add(value);
          return value;
        });
        indicator.health = entity.npcHealth;
        indicator.position.setValues(
          _snapScratch.x,
          _snapScratch.y - (entity.size?.y ?? 54) / 2 - 12,
        );
      }
    }

    if (_actors.isEmpty) {
      return;
    }
    final toRemove = _toRemoveScratch..clear();
    for (final id in _actors.keys) {
      if (!seen.contains(id)) {
        toRemove.add(id);
      }
    }
    for (final id in toRemove) {
      _actors.remove(id)?.removeFromParent();
      _npcHealth.remove(id)?.removeFromParent();
    }
  }

  void syncProjectiles(
    List<EntityRenderSnapshot> entities, {
    required Map<int, EntityRenderSnapshot> prevById,
    required double alpha,
    required Vector2 cameraCenter,
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
          world.add(view);
        }

        final prev = prevById[entity.id] ?? entity;
        final worldX = math.lerpDouble(prev.pos.x, entity.pos.x, alpha);
        final worldY = math.lerpDouble(prev.pos.y, entity.pos.y, alpha);
        _snapScratch.setValues(
          math.snapWorldToPixelsInCameraSpace1d(worldX, cameraCenter.x),
          math.snapWorldToPixelsInCameraSpace1d(worldY, cameraCenter.y),
        );

        view.applySnapshot(
          entity,
          tickHz: controller.tickHz,
          pos: _snapScratch,
        );
      } else {
        _projectileAnimViews.remove(entity.id)?.removeFromParent();
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
    syncCombatCapsuleOverlays(
      entities: entities,
      enabled: true,
      parent: world,
      pool: _hitboxes,
      priority: priorityHitboxes,
      paint: _hitboxPaint,
      prevById: prevById,
      alpha: alpha,
      cameraCenter: cameraCenter,
      include: (e) => e.kind == EntityKind.trigger,
    );
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
    required this.flipX,
    required this.flipY,
    required this.rotationDegrees,
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
      flipX: s.flipX,
      flipY: s.flipY,
      rotationDegrees: s.rotationDegrees,
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
  final bool flipX;
  final bool flipY;
  final double rotationDegrees;

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
        other.zIndex == zIndex &&
        other.flipX == flipX &&
        other.flipY == flipY &&
        other.rotationDegrees == rotationDegrees;
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
    flipX,
    flipY,
    rotationDegrees,
  );
}
