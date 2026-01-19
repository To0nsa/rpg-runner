// Flame rendering layer for the runner (Milestone 0 placeholder).
//
// Reads the latest `GameStateSnapshot` from `GameController` each frame and
// renders a minimal representation (a player dot + debug text). This file is
// intentionally tiny and non-authoritative: gameplay truth lives in Core.
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../core/contracts/render_contract.dart';
import '../core/events/game_event.dart';
import '../core/players/player_character_definition.dart';
import '../core/snapshots/entity_render_snapshot.dart';
import '../core/snapshots/enums.dart';
import '../core/snapshots/static_solid_snapshot.dart';
import 'debug/debug_aabb_overlay.dart';
import 'debug/render_debug_flags.dart';
import 'components/player/player_animations.dart';
import 'components/player/player_view_component.dart';
import 'components/enemies/enemy_render_registry.dart';
import 'components/projectiles/projectile_render_registry.dart';
import 'components/sprite_anim/deterministic_anim_view_component.dart';
import 'tuning/player_render_tuning.dart';
import 'input/runner_input_router.dart';
import 'input/aim_preview.dart';
import 'components/pixel_parallax_backdrop_component.dart';
import 'components/tiled_ground_band_component.dart';
import 'components/aim_ray_component.dart';
import 'game_controller.dart';
import 'themes/parallax_theme_registry.dart';
import 'util/math_util.dart' as math;

// ─────────────────────────────────────────────────────────────────────────────
// Render priorities
// ─────────────────────────────────────────────────────────────────────────────

const _priorityBackgroundParallax = -30;
const _priorityGroundTiles = -20;
const _priorityForegroundParallax = -10;
const _priorityStaticSolids = -5;
const _priorityPlayer = -3;
const _priorityEnemies = -2;
const _priorityProjectiles = -1;
const _priorityCollectibles = -1;
const _priorityHitboxes = 1;
const _priorityActorHitboxes = 2;
const _priorityProjectileAimRay = 5;
const _priorityMeleeAimRay = 6;
const _priorityRangedAimRay = 7;
const PlayerRenderTuning _playerRenderTuning = PlayerRenderTuning();

/// Minimal Flame `Game` that renders from snapshots.
class RunnerFlameGame extends FlameGame {
  RunnerFlameGame({
    required this.controller,
    required this.input,
    required this.projectileAimPreview,
    required this.meleeAimPreview,
    required this.rangedAimPreview,
    required this.playerCharacter,
  }) : _enemyRenderRegistry = EnemyRenderRegistry(
         enemyCatalog: controller.enemyCatalog,
       ),
       _projectileRenderRegistry = ProjectileRenderRegistry(),
       super(
         camera: CameraComponent.withFixedResolution(
           width: virtualWidth.toDouble(),
           height: virtualHeight.toDouble(),
         ),
       );

  /// Bridge/controller that owns the simulation and produces snapshots.
  final GameController controller;

  /// Input scheduler/aggregator (touch + keyboard + mouse).
  final RunnerInputRouter input;

  /// UI-driven aim preview (render-only).
  final ValueListenable<AimPreviewState> projectileAimPreview;
  final ValueListenable<AimPreviewState> meleeAimPreview;
  final ValueListenable<AimPreviewState> rangedAimPreview;

  /// The selected player character definition for this run (render-only usage).
  final PlayerCharacterDefinition playerCharacter;

  late final PlayerViewComponent _player;
  final EnemyRenderRegistry _enemyRenderRegistry;
  final ProjectileRenderRegistry _projectileRenderRegistry;
  final List<RectangleComponent> _staticSolids = <RectangleComponent>[];
  List<StaticSolidSnapshot>? _lastStaticSolidsSnapshot;

  /// Entity view pools, keyed by entity ID.
  final Map<int, DeterministicAnimViewComponent> _projectileAnimViews =
      <int, DeterministicAnimViewComponent>{};
  final Map<int, RectangleComponent> _projectileRects =
      <int, RectangleComponent>{};
  final Map<int, RectangleComponent> _collectibles =
      <int, RectangleComponent>{};
  final Map<int, DeterministicAnimViewComponent> _enemies =
      <int, DeterministicAnimViewComponent>{};
  final Map<int, RectangleComponent> _hitboxes = <int, RectangleComponent>{};
  final Map<int, RectangleComponent> _actorHitboxes =
      <int, RectangleComponent>{};

  final Paint _projectilePaint = Paint()..color = const Color(0xFF60A5FA);
  final Map<int, Paint> _pickupPaints = <int, Paint>{
    PickupVariant.collectible: Paint()..color = const Color(0xFFFFEB3B),
    PickupVariant.restorationHealth: Paint()..color = const Color(0xFFEF4444),
    PickupVariant.restorationMana: Paint()..color = const Color(0xFF3B82F6),
    PickupVariant.restorationStamina: Paint()..color = const Color(0xFF22C55E),
  };
  final Paint _hitboxPaint = Paint()..color = const Color(0x66EF4444);
  final Paint _actorHitboxPaint = Paint()
    ..color = const Color(0xFF22C55E)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  final Map<int, EntityRenderSnapshot> _prevEntitiesById =
      <int, EntityRenderSnapshot>{};
  final Map<int, int> _projectileSpawnTicks = <int, int>{};
  final Set<int> _seenIdsScratch = <int>{};
  final List<int> _toRemoveScratch = <int>[];
  final Vector2 _cameraCenterScratch = Vector2.zero();
  final Vector2 _snapScratch = Vector2.zero();
  final List<EnemyKilledEvent> _pendingEnemyKilledEvents = <EnemyKilledEvent>[];
  final List<ProjectileHitEvent> _pendingProjectileHitEvents =
      <ProjectileHitEvent>[];

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    assert(() {
      playerCharacter.assertValid();
      return true;
    }());
    controller.addEventListener(_handleGameEvent);
    final theme = ParallaxThemeRegistry.forThemeId(controller.snapshot.themeId);

    // Background parallax layers (sky, distant mountains, etc.)
    camera.backdrop.add(
      PixelParallaxBackdropComponent(
        virtualWidth: virtualWidth,
        virtualHeight: virtualHeight,
        snapScrollToPixels: false,
        layers: theme.backgroundLayers,
      )..priority = _priorityBackgroundParallax,
    );

    // Ground tiles (with gap support)
    camera.backdrop.add(
      TiledGroundBandComponent(
        assetPath: theme.groundLayerAsset,
        controller: controller,
        virtualWidth: virtualWidth,
        virtualHeight: virtualHeight,
        renderInBackdrop: true,
      )..priority = _priorityGroundTiles,
    );

    // Foreground parallax layers (grass, bushes, etc.)
    camera.backdrop.add(
      PixelParallaxBackdropComponent(
        virtualWidth: virtualWidth,
        virtualHeight: virtualHeight,
        snapScrollToPixels: false,
        layers: theme.foregroundLayers,
      )..priority = _priorityForegroundParallax,
    );

    final playerAnimations = await loadPlayerAnimations(
      images,
      renderAnim: playerCharacter.renderAnim,
    );
    await _enemyRenderRegistry.load(images);
    await _projectileRenderRegistry.load(images);
    _player = PlayerViewComponent(
      animationSet: playerAnimations,
      renderScale: Vector2.all(_playerRenderTuning.scale),
    )..priority = _priorityPlayer;
    world.add(_player);

    world.add(
      AimRayComponent(
        controller: controller,
        preview: projectileAimPreview,
        length: projectileAimRayLength,
        playerRenderPos: () => _player.position,
        drawWhenNoAim: false,
      )..priority = _priorityProjectileAimRay,
    );

    world.add(
      AimRayComponent(
        controller: controller,
        preview: meleeAimPreview,
        length: meleeAimRayLength,
        playerRenderPos: () => _player.position,
        drawWhenNoAim: false,
        paint: Paint()
          ..color = const Color(0xFFDC4440)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      )..priority = _priorityMeleeAimRay,
    );

    world.add(
      AimRayComponent(
        controller: controller,
        preview: rangedAimPreview,
        length: projectileAimRayLength,
        playerRenderPos: () => _player.position,
        drawWhenNoAim: false,
        paint: Paint()
          ..color = const Color(0xFFF59E0B)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      )..priority = _priorityRangedAimRay,
    );

    _mountStaticSolids(controller.snapshot.staticSolids);
    _lastStaticSolidsSnapshot = controller.snapshot.staticSolids;
  }

  @override
  void update(double dt) {
    final snapshot = controller.snapshot;
    if (!snapshot.paused && !snapshot.gameOver) {
      input.pumpHeldInputs();
    }

    // Step the deterministic core using the frame delta, then render the newest
    // snapshot. This order is critical: Flame components (parallax, etc.) read
    // the camera during their own update(), so Core + camera + view sync must
    // run BEFORE super.update(dt).
    controller.advanceFrame(dt);

    final prevSnapshot = controller.prevSnapshot;
    final currSnapshot = controller.snapshot;
    final alpha = controller.alpha;

    _prevEntitiesById.clear();
    for (final e in prevSnapshot.entities) {
      _prevEntitiesById[e.id] = e;
    }

    final camX = math.lerpDouble(
      prevSnapshot.cameraCenterX,
      currSnapshot.cameraCenterX,
      alpha,
    );
    final camY = math.lerpDouble(
      prevSnapshot.cameraCenterY,
      currSnapshot.cameraCenterY,
      alpha,
    );
    _cameraCenterScratch.setValues(camX, camY);
    camera.viewfinder.position = _cameraCenterScratch;

    _syncStaticSolids(currSnapshot.staticSolids);
    _snapStaticSolids(
      currSnapshot.staticSolids,
      cameraCenter: _cameraCenterScratch,
    );

    final player = currSnapshot.playerEntity;
    if (player != null) {
      final prev = _prevEntitiesById[player.id] ?? player;
      final worldX = math.lerpDouble(prev.pos.x, player.pos.x, alpha);
      final worldY = math.lerpDouble(prev.pos.y, player.pos.y, alpha);
      _snapScratch.setValues(
        math.snapWorldToPixelsInCameraSpace1d(worldX, _cameraCenterScratch.x),
        math.snapWorldToPixelsInCameraSpace1d(worldY, _cameraCenterScratch.y),
      );
      _player.applySnapshot(
        player,
        tickHz: controller.tickHz,
        pos: _snapScratch,
      );
    }

    _syncEnemies(
      currSnapshot.entities,
      prevById: _prevEntitiesById,
      alpha: alpha,
      cameraCenter: _cameraCenterScratch,
    );
    _syncProjectiles(
      currSnapshot.entities,
      prevById: _prevEntitiesById,
      alpha: alpha,
      cameraCenter: _cameraCenterScratch,
      tick: currSnapshot.tick,
    );
    _syncCollectibles(
      currSnapshot.entities,
      prevById: _prevEntitiesById,
      alpha: alpha,
      cameraCenter: _cameraCenterScratch,
    );
    _syncHitboxes(
      currSnapshot.entities,
      prevById: _prevEntitiesById,
      alpha: alpha,
      cameraCenter: _cameraCenterScratch,
    );
    syncDebugAabbOverlays(
      entities: currSnapshot.entities,
      enabled:
          RenderDebugFlags.canUseRenderDebug &&
          RenderDebugFlags.drawActorHitboxes,
      parent: world,
      pool: _actorHitboxes,
      priority: _priorityActorHitboxes,
      paint: _actorHitboxPaint,
      include: (e) => e.kind == EntityKind.player || e.kind == EntityKind.enemy,
      prevById: _prevEntitiesById,
      offsetXFor: (e) {
        switch (e.kind) {
          case EntityKind.player:
            return playerCharacter.catalog.colliderOffsetX;
          case EntityKind.enemy:
            final enemyId = e.enemyId;
            if (enemyId == null) return 0.0;
            return controller.enemyCatalog.get(enemyId).collider.offsetX;
          default:
            return 0.0;
        }
      },
      offsetYFor: (e) {
        switch (e.kind) {
          case EntityKind.player:
            return playerCharacter.catalog.colliderOffsetY;
          case EntityKind.enemy:
            final enemyId = e.enemyId;
            if (enemyId == null) return 0.0;
            return controller.enemyCatalog.get(enemyId).collider.offsetY;
          default:
            return 0.0;
        }
      },
      alpha: alpha,
      cameraCenter: _cameraCenterScratch,
    );

    _flushPendingEnemyKilledEvents(cameraCenter: _cameraCenterScratch);
    _flushPendingProjectileHitEvents(cameraCenter: _cameraCenterScratch);

    super.update(dt);
  }

  /// Mounts static solid rectangles into the world.
  ///
  /// Called once on load and whenever the static solids list changes.
  /// One-way platforms are rendered with a green tint, solid platforms with
  /// purple.
  void _mountStaticSolids(List<StaticSolidSnapshot> solids) {
    if (solids.isEmpty) return;

    for (final solid in solids) {
      final color = solid.oneWayTop
          ? const Color(0x6648BB78) // green-ish translucent
          : const Color(0x668B5CF6); // purple translucent

      final rect = RectangleComponent(
        position: Vector2(solid.minX, solid.minY),
        size: Vector2(solid.maxX - solid.minX, solid.maxY - solid.minY),
        paint: Paint()..color = color,
      );
      rect.priority = _priorityStaticSolids;
      _staticSolids.add(rect);
      world.add(rect);
    }
  }

  /// Synchronizes enemy view components with the snapshot.
  ///
  /// Creates view components for new enemies, updates existing ones, and
  /// removes components for despawned enemies.
  void _syncEnemies(
    List<EntityRenderSnapshot> entities, {
    required Map<int, EntityRenderSnapshot> prevById,
    required double alpha,
    required Vector2 cameraCenter,
  }) {
    final seen = _seenIdsScratch..clear();

    for (final e in entities) {
      if (e.kind != EntityKind.enemy) continue;

      final entry = e.enemyId == null
          ? null
          : _enemyRenderRegistry.entryFor(e.enemyId!);
      if (entry == null) {
        _enemies.remove(e.id)?.removeFromParent();
        continue;
      }

      seen.add(e.id);

      var view = _enemies[e.id];
      if (view == null) {
        view = entry.viewFactory(entry.animSet, entry.renderScale)
          ..priority = _priorityEnemies;
        _enemies[e.id] = view;
        world.add(view);
      }

      final prev = prevById[e.id] ?? e;
      final worldX = math.lerpDouble(prev.pos.x, e.pos.x, alpha);
      final worldY = math.lerpDouble(prev.pos.y, e.pos.y, alpha);
      final snappedX = math.snapWorldToPixelsInCameraSpace1d(
        worldX,
        cameraCenter.x,
      );
      final snappedY = math.snapWorldToPixelsInCameraSpace1d(
        worldY,
        cameraCenter.y,
      );

      _snapScratch.setValues(snappedX, snappedY);
      view.applySnapshot(e, tickHz: controller.tickHz, pos: _snapScratch);
    }

    if (_enemies.isEmpty) return;
    final toRemove = _toRemoveScratch..clear();
    for (final id in _enemies.keys) {
      if (!seen.contains(id)) toRemove.add(id);
    }
    for (final id in toRemove) {
      _enemies.remove(id)?.removeFromParent();
    }
  }

  void _handleGameEvent(GameEvent event) {
    if (event is EnemyKilledEvent) {
      _pendingEnemyKilledEvents.add(event);
      return;
    }
    if (event is ProjectileHitEvent) {
      _pendingProjectileHitEvents.add(event);
    }
  }

  void _flushPendingEnemyKilledEvents({required Vector2 cameraCenter}) {
    if (_pendingEnemyKilledEvents.isEmpty) return;

    for (final event in _pendingEnemyKilledEvents) {
      final entry = _enemyRenderRegistry.entryFor(event.enemyId);
      if (entry == null) continue;
      if (entry.deathAnimPolicy == EnemyDeathAnimPolicy.none) continue;

      final deathAnim = entry.animSet.animations[AnimKey.death];
      if (deathAnim == null) continue;

      final component = _CameraSpaceSnappedSpriteAnimationComponent(
        animation: deathAnim,
        size: entry.animSet.frameSize.clone(),
        worldPosX: event.pos.x,
        worldPosY: event.pos.y,
        anchor: entry.animSet.anchor,
        paint: Paint()..filterQuality = FilterQuality.none,
        removeOnFinish: true,
      )..priority = _priorityEnemies;

      final sign = event.facing == event.artFacingDir ? 1.0 : -1.0;
      component.scale.setValues(
        entry.renderScale.x * sign,
        entry.renderScale.y,
      );
      component.snapToCamera(cameraCenter);
      world.add(component);
    }

    _pendingEnemyKilledEvents.clear();
  }

  void _flushPendingProjectileHitEvents({required Vector2 cameraCenter}) {
    if (_pendingProjectileHitEvents.isEmpty) return;

    for (final event in _pendingProjectileHitEvents) {
      final entry = _projectileRenderRegistry.entryFor(event.projectileId);
      if (entry == null) continue;

      final hitAnim = entry.animSet.animations[AnimKey.hit];
      if (hitAnim == null) continue;

      final component = _CameraSpaceSnappedSpriteAnimationComponent(
        animation: hitAnim,
        size: entry.animSet.frameSize.clone(),
        worldPosX: event.pos.x,
        worldPosY: event.pos.y,
        anchor: entry.animSet.anchor,
        paint: Paint()..filterQuality = FilterQuality.none,
        removeOnFinish: true,
      )..priority = _priorityProjectiles;

      component.scale.setValues(entry.renderScale.x, entry.renderScale.y);
      component.angle = event.rotationRad;
      component.snapToCamera(cameraCenter);
      world.add(component);
    }

    _pendingProjectileHitEvents.clear();
  }

  /// Synchronizes projectile view components with the snapshot.
  ///
  /// Creates rectangle components for new projectiles, updates position/size
  /// for existing ones, and removes components for despawned projectiles.
  void _syncProjectiles(
    List<EntityRenderSnapshot> entities, {
    required Map<int, EntityRenderSnapshot> prevById,
    required double alpha,
    required Vector2 cameraCenter,
    required int tick,
  }) {
    final seen = _seenIdsScratch..clear();

    for (final e in entities) {
      if (e.kind != EntityKind.projectile) continue;
      seen.add(e.id);

      final projectileId = e.projectileId;
      final entry = projectileId == null
          ? null
          : _projectileRenderRegistry.entryFor(projectileId);

      if (entry != null) {
        _projectileRects.remove(e.id)?.removeFromParent();

        var view = _projectileAnimViews[e.id];
        if (view == null) {
          view = entry.viewFactory(entry.animSet, entry.renderScale);
          view.priority = _priorityProjectiles;
          _projectileAnimViews[e.id] = view;
          _projectileSpawnTicks[e.id] = tick;
          world.add(view);
        }

        final prev = prevById[e.id] ?? e;
        final worldX = math.lerpDouble(prev.pos.x, e.pos.x, alpha);
        final worldY = math.lerpDouble(prev.pos.y, e.pos.y, alpha);
        _snapScratch.setValues(
          math.snapWorldToPixelsInCameraSpace1d(worldX, cameraCenter.x),
          math.snapWorldToPixelsInCameraSpace1d(worldY, cameraCenter.y),
        );

        final spawnTick = _projectileSpawnTicks[e.id] ?? tick;
        final startTicks = entry.spawnAnimTicks(controller.tickHz);
        final ageTicks = tick - spawnTick;
        final animOverride =
            startTicks > 0 && ageTicks >= 0 && ageTicks < startTicks
                ? AnimKey.spawn
                : AnimKey.idle;
        final overrideAnimFrame =
            animOverride == AnimKey.spawn ? ageTicks : null;

        view.applySnapshot(
          e,
          tickHz: controller.tickHz,
          pos: _snapScratch,
          overrideAnim: animOverride,
          overrideAnimFrame: overrideAnimFrame,
        );
        view.angle = e.rotationRad;
      } else {
        _projectileAnimViews.remove(e.id)?.removeFromParent();
        _projectileSpawnTicks.remove(e.id);

        var view = _projectileRects[e.id];
        if (view == null) {
          final size = e.size;
          view = RectangleComponent(
            size: Vector2(size?.x ?? 8.0, size?.y ?? 8.0),
            anchor: Anchor.center,
            paint: _projectilePaint,
          );
          view.priority = _priorityProjectiles;
          _projectileRects[e.id] = view;
          world.add(view);
        } else {
          final size = e.size;
          if (size != null) {
            view.size.setValues(size.x, size.y);
          }
        }

        final prev = prevById[e.id] ?? e;
        final worldX = math.lerpDouble(prev.pos.x, e.pos.x, alpha);
        final worldY = math.lerpDouble(prev.pos.y, e.pos.y, alpha);
        view.position.setValues(
          math.snapWorldToPixelsInCameraSpace1d(worldX, cameraCenter.x),
          math.snapWorldToPixelsInCameraSpace1d(worldY, cameraCenter.y),
        );
        view.angle = e.rotationRad;
      }
    }

    if (_projectileAnimViews.isNotEmpty) {
      final toRemove = _toRemoveScratch..clear();
      for (final id in _projectileAnimViews.keys) {
        if (!seen.contains(id)) toRemove.add(id);
      }
      for (final id in toRemove) {
        _projectileAnimViews.remove(id)?.removeFromParent();
        _projectileSpawnTicks.remove(id);
      }
    }

    if (_projectileRects.isEmpty) return;
    final toRemove = _toRemoveScratch..clear();
    for (final id in _projectileRects.keys) {
      if (!seen.contains(id)) toRemove.add(id);
    }
    for (final id in toRemove) {
      _projectileRects.remove(id)?.removeFromParent();
    }
  }

  /// Synchronizes collectible/pickup view components with the snapshot.
  ///
  /// Creates rectangle components for new pickups, updates position/paint for
  /// existing ones, and removes components for collected pickups.
  void _syncCollectibles(
    List<EntityRenderSnapshot> entities, {
    required Map<int, EntityRenderSnapshot> prevById,
    required double alpha,
    required Vector2 cameraCenter,
  }) {
    final seen = _seenIdsScratch..clear();

    for (final e in entities) {
      if (e.kind != EntityKind.pickup) continue;
      seen.add(e.id);

      var view = _collectibles[e.id];
      final variant = e.pickupVariant ?? PickupVariant.collectible;
      final paint =
          _pickupPaints[variant] ?? _pickupPaints[PickupVariant.collectible]!;
      if (view == null) {
        final size = e.size;
        view = RectangleComponent(
          size: Vector2(size?.x ?? 8.0, size?.y ?? 8.0),
          anchor: Anchor.center,
          paint: paint,
        );
        view.priority = _priorityCollectibles;
        _collectibles[e.id] = view;
        world.add(view);
      } else {
        final size = e.size;
        if (size != null) {
          view.size.setValues(size.x, size.y);
        }
        if (view.paint != paint) {
          view.paint = paint;
        }
      }

      final prev = prevById[e.id] ?? e;
      final worldX = math.lerpDouble(prev.pos.x, e.pos.x, alpha);
      final worldY = math.lerpDouble(prev.pos.y, e.pos.y, alpha);
      view.position.setValues(
        math.snapWorldToPixelsInCameraSpace1d(worldX, cameraCenter.x),
        math.snapWorldToPixelsInCameraSpace1d(worldY, cameraCenter.y),
      );
      view.angle = e.rotationRad;
    }

    if (_collectibles.isEmpty) return;
    final toRemove = _toRemoveScratch..clear();
    for (final id in _collectibles.keys) {
      if (!seen.contains(id)) toRemove.add(id);
    }
    for (final id in toRemove) {
      _collectibles.remove(id)?.removeFromParent();
    }
  }

  /// Synchronizes trigger/hitbox view components with the snapshot.
  ///
  /// Creates translucent red rectangle components for new triggers, updates
  /// position/size for existing ones, and removes components for despawned
  /// triggers.
  void _syncHitboxes(
    List<EntityRenderSnapshot> entities, {
    required Map<int, EntityRenderSnapshot> prevById,
    required double alpha,
    required Vector2 cameraCenter,
  }) {
    final seen = _seenIdsScratch..clear();

    for (final e in entities) {
      if (e.kind != EntityKind.trigger) continue;
      seen.add(e.id);

      var view = _hitboxes[e.id];
      if (view == null) {
        final size = e.size;
        view = RectangleComponent(
          size: Vector2(size?.x ?? 8.0, size?.y ?? 8.0),
          anchor: Anchor.center,
          paint: _hitboxPaint,
        );
        view.priority = _priorityHitboxes;
        _hitboxes[e.id] = view;
        world.add(view);
      } else {
        final size = e.size;
        if (size != null) {
          view.size.setValues(size.x, size.y);
        }
      }

      final prev = prevById[e.id] ?? e;
      final worldX = math.lerpDouble(prev.pos.x, e.pos.x, alpha);
      final worldY = math.lerpDouble(prev.pos.y, e.pos.y, alpha);
      view.position.setValues(
        math.snapWorldToPixelsInCameraSpace1d(worldX, cameraCenter.x),
        math.snapWorldToPixelsInCameraSpace1d(worldY, cameraCenter.y),
      );
    }

    if (_hitboxes.isEmpty) return;
    final toRemove = _toRemoveScratch..clear();
    for (final id in _hitboxes.keys) {
      if (!seen.contains(id)) toRemove.add(id);
    }
    for (final id in toRemove) {
      _hitboxes.remove(id)?.removeFromParent();
    }
  }

  /// Synchronizes static solid views with the snapshot.
  ///
  /// Uses identity comparison as a cheap version check since Core rebuilds
  /// the list only when geometry actually changes (spawn/cull).
  void _syncStaticSolids(List<StaticSolidSnapshot> solids) {
    // Core rebuilds the list only when geometry changes (spawn/cull),
    // so identity check is a cheap "version" check.
    if (identical(solids, _lastStaticSolidsSnapshot)) return;
    _lastStaticSolidsSnapshot = solids;

    for (final c in _staticSolids) {
      c.removeFromParent();
    }
    _staticSolids.clear();

    _mountStaticSolids(solids);
  }

  void _snapStaticSolids(
    List<StaticSolidSnapshot> solids, {
    required Vector2 cameraCenter,
  }) {
    if (solids.isEmpty) return;
    if (_staticSolids.length != solids.length) return;

    for (var i = 0; i < solids.length; i++) {
      final solid = solids[i];
      final view = _staticSolids[i];
      view.position.setValues(
        math.snapWorldToPixelsInCameraSpace1d(solid.minX, cameraCenter.x),
        math.snapWorldToPixelsInCameraSpace1d(solid.minY, cameraCenter.y),
      );
    }
  }

  @override
  void onRemove() {
    controller.removeEventListener(_handleGameEvent);
    images.clearCache();
    super.onRemove();
  }
}

class _CameraSpaceSnappedSpriteAnimationComponent
    extends SpriteAnimationComponent
    with HasGameReference<FlameGame> {
  _CameraSpaceSnappedSpriteAnimationComponent({
    required SpriteAnimation super.animation,
    required Vector2 super.size,
    required this.worldPosX,
    required this.worldPosY,
    this.anchor = Anchor.center,
    super.paint,
    super.removeOnFinish,
  }) : super(anchor: anchor);

  final double worldPosX;
  final double worldPosY;
  final Anchor anchor;

  void snapToCamera(Vector2 cameraCenter) {
    position.setValues(
      math.snapWorldToPixelsInCameraSpace1d(worldPosX, cameraCenter.x),
      math.snapWorldToPixelsInCameraSpace1d(worldPosY, cameraCenter.y),
    );
  }

  @override
  void update(double dt) {
    snapToCamera(game.camera.viewfinder.position);
    super.update(dt);
  }
}
