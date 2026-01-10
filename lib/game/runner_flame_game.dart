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
import '../core/snapshots/entity_render_snapshot.dart';
import '../core/snapshots/enums.dart';
import '../core/snapshots/static_solid_snapshot.dart';
import 'components/player/player_animations.dart';
import 'components/player/player_view_component.dart';
import 'tuning/player_render_tuning.dart';
import 'input/runner_input_router.dart';
import 'input/aim_preview.dart';
import 'components/pixel_parallax_backdrop_component.dart';
import 'components/tiled_ground_band_component.dart';
import 'components/aim_ray_component.dart';
import 'game_controller.dart';
import 'themes/parallax_theme_registry.dart';


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
  }) : super(
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

  late final PlayerViewComponent _player;
  final List<RectangleComponent> _staticSolids = <RectangleComponent>[];
  List<StaticSolidSnapshot>? _lastStaticSolidsSnapshot;

  /// Entity view pools, keyed by entity ID.
  final Map<int, RectangleComponent> _projectiles = <int, RectangleComponent>{};
  final Map<int, RectangleComponent> _collectibles = <int, RectangleComponent>{};
  final Map<int, CircleComponent> _enemies = <int, CircleComponent>{};
  final Map<int, RectangleComponent> _hitboxes = <int, RectangleComponent>{};

  final Paint _projectilePaint = Paint()..color = const Color(0xFF60A5FA);
  final Map<int, Paint> _pickupPaints = <int, Paint>{
    PickupVariant.collectible: Paint()..color = const Color(0xFFFFEB3B),
    PickupVariant.restorationHealth: Paint()..color = const Color(0xFFEF4444),
    PickupVariant.restorationMana: Paint()..color = const Color(0xFF3B82F6),
    PickupVariant.restorationStamina: Paint()..color = const Color(0xFF22C55E),
  };
  final List<Paint> _enemyPaints = <Paint>[
    Paint()..color = const Color(0xFFA855F7), // purple
    Paint()..color = const Color(0xFFF97316), // orange
  ];
  final Paint _hitboxPaint = Paint()..color = const Color(0x66EF4444);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
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

    final playerAnimations = await loadPlayerAnimations(images);
    _player = PlayerViewComponent(
      animationSet: playerAnimations,
      renderScale: Vector2.all(_playerRenderTuning.scale),
    )
      ..priority = _priorityPlayer;
    world.add(_player);

    world.add(
      AimRayComponent(
        controller: controller,
        preview: projectileAimPreview,
        length: projectileAimRayLength,
        drawWhenNoAim: false,
      )..priority = _priorityProjectileAimRay,
    );

    world.add(
      AimRayComponent(
        controller: controller,
        preview: meleeAimPreview,
        length: meleeAimRayLength,
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

    super.update(dt);

    // Step the deterministic core using the frame delta, then render the
    // newest snapshot.
    controller.advanceFrame(dt);
    final updatedSnapshot = controller.snapshot;
    _syncStaticSolids(updatedSnapshot.staticSolids);

    final player = updatedSnapshot.playerEntity;
    if (player != null) {
      _player.applySnapshot(player, tickHz: controller.tickHz);
    }
    camera.viewfinder.position = Vector2(
      updatedSnapshot.cameraCenterX.roundToDouble(),
      updatedSnapshot.cameraCenterY.roundToDouble(),
    );

    _syncEnemies(updatedSnapshot.entities);
    _syncProjectiles(updatedSnapshot.entities);
    _syncCollectibles(updatedSnapshot.entities);
    _syncHitboxes(updatedSnapshot.entities);
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
  /// Creates circle components for new enemies, updates position/rotation for
  /// existing ones, and removes components for despawned enemies.
  void _syncEnemies(List<EntityRenderSnapshot> entities) {
    final seen = <int>{};

    for (final e in entities) {
      if (e.kind != EntityKind.enemy) continue;
      seen.add(e.id);

      var view = _enemies[e.id];
      if (view == null) {
        final size = e.size;
        final radius =
            ((size != null) ? (size.x < size.y ? size.x : size.y) : 16.0) * 0.5;
        final paint = _enemyPaints[e.id % _enemyPaints.length];
        view = CircleComponent(
          radius: radius,
          anchor: Anchor.center,
          paint: paint,
        );
        view.priority = _priorityEnemies;
        _enemies[e.id] = view;
        world.add(view);
      } else {
        final size = e.size;
        if (size != null) {
          final radius = (size.x < size.y ? size.x : size.y) * 0.5;
          view.radius = radius;
        }
      }

      view.position.setValues(e.pos.x.roundToDouble(), e.pos.y.roundToDouble());
      view.angle = e.rotationRad;
    }

    if (_enemies.isEmpty) return;
    final toRemove = <int>[];
    for (final id in _enemies.keys) {
      if (!seen.contains(id)) toRemove.add(id);
    }
    for (final id in toRemove) {
      _enemies.remove(id)?.removeFromParent();
    }
  }

  /// Synchronizes projectile view components with the snapshot.
  ///
  /// Creates rectangle components for new projectiles, updates position/size
  /// for existing ones, and removes components for despawned projectiles.
  void _syncProjectiles(List<EntityRenderSnapshot> entities) {
    final seen = <int>{};

    for (final e in entities) {
      if (e.kind != EntityKind.projectile) continue;
      seen.add(e.id);

      var view = _projectiles[e.id];
      if (view == null) {
        final size = e.size;
        view = RectangleComponent(
          size: Vector2(size?.x ?? 8.0, size?.y ?? 8.0),
          anchor: Anchor.center,
          paint: _projectilePaint,
        );
        view.priority = _priorityProjectiles;
        _projectiles[e.id] = view;
        world.add(view);
      } else {
        final size = e.size;
        if (size != null) {
          view.size.setValues(size.x, size.y);
        }
      }

      view.position.setValues(e.pos.x.roundToDouble(), e.pos.y.roundToDouble());
      view.angle = e.rotationRad;
    }

    if (_projectiles.isEmpty) return;
    final toRemove = <int>[];
    for (final id in _projectiles.keys) {
      if (!seen.contains(id)) toRemove.add(id);
    }
    for (final id in toRemove) {
      _projectiles.remove(id)?.removeFromParent();
    }
  }

  /// Synchronizes collectible/pickup view components with the snapshot.
  ///
  /// Creates rectangle components for new pickups, updates position/paint for
  /// existing ones, and removes components for collected pickups.
  void _syncCollectibles(List<EntityRenderSnapshot> entities) {
    final seen = <int>{};

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

      view.position.setValues(e.pos.x.roundToDouble(), e.pos.y.roundToDouble());
      view.angle = e.rotationRad;
    }

    if (_collectibles.isEmpty) return;
    final toRemove = <int>[];
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
  void _syncHitboxes(List<EntityRenderSnapshot> entities) {
    final seen = <int>{};

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

      view.position.setValues(e.pos.x.roundToDouble(), e.pos.y.roundToDouble());
    }

    if (_hitboxes.isEmpty) return;
    final toRemove = <int>[];
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

  @override
  void onRemove() {
    images.clearCache();
    super.onRemove();
  }
}
