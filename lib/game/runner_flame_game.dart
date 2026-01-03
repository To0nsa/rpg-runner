// Flame rendering layer for the runner (Milestone 0 placeholder).
//
// Reads the latest `GameStateSnapshot` from `GameController` each frame and
// renders a minimal representation (a player dot + debug text). This file is
// intentionally tiny and non-authoritative: gameplay truth lives in Core.
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../core/contracts/v0_render_contract.dart';
import '../core/snapshots/entity_render_snapshot.dart';
import '../core/snapshots/enums.dart';
import '../core/snapshots/static_solid_snapshot.dart';
import 'input/runner_input_router.dart';
import 'input/aim_preview.dart';
import 'components/pixel_parallax_backdrop_component.dart';
import 'components/tiled_ground_band_component.dart';
import 'components/aim_ray_component.dart';
import 'game_controller.dart';

/// Minimal Flame `Game` that renders from snapshots.
class RunnerFlameGame extends FlameGame {
  RunnerFlameGame({
    required this.controller,
    required this.input,
    required this.projectileAimPreview,
    required this.meleeAimPreview,
  }) : super(
         camera: CameraComponent.withFixedResolution(
           width: v0VirtualWidth.toDouble(),
           height: v0VirtualHeight.toDouble(),
         ),
       );

  /// Bridge/controller that owns the simulation and produces snapshots.
  final GameController controller;

  /// Input scheduler/aggregator (touch + keyboard + mouse).
  final RunnerInputRouter input;

  /// UI-driven aim preview (render-only).
  final ValueListenable<AimPreviewState> projectileAimPreview;
  final ValueListenable<AimPreviewState> meleeAimPreview;

  late final CircleComponent _player;
  //late final TextComponent _debugText;
  final List<RectangleComponent> _staticSolids = <RectangleComponent>[];
  List<StaticSolidSnapshot>? _lastStaticSolidsSnapshot;
  final Map<int, RectangleComponent> _projectiles = <int, RectangleComponent>{};
  final Paint _projectilePaint = Paint()..color = const Color(0xFF60A5FA);
  final Map<int, CircleComponent> _enemies = <int, CircleComponent>{};
  final List<Paint> _enemyPaints = <Paint>[
    Paint()..color = const Color(0xFFA855F7), // purple
    Paint()..color = const Color(0xFFF97316), // orange
  ];
  final Map<int, RectangleComponent> _hitboxes = <int, RectangleComponent>{};
  final Paint _hitboxPaint = Paint()..color = const Color(0x66EF4444);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    camera.backdrop.add(
      PixelParallaxBackdropComponent(
        virtualWidth: v0VirtualWidth,
        virtualHeight: v0VirtualHeight,
        snapScrollToPixels: false,
        layers: const [
          PixelParallaxLayerSpec(
            assetPath: 'parallax/field/Field Layer 01.png',
            parallaxFactor: 0.10,
          ),
          PixelParallaxLayerSpec(
            assetPath: 'parallax/field/Field Layer 02.png',
            parallaxFactor: 0.15,
          ),
          PixelParallaxLayerSpec(
            assetPath: 'parallax/field/Field Layer 03.png',
            parallaxFactor: 0.20,
          ),
          PixelParallaxLayerSpec(
            assetPath: 'parallax/field/Field Layer 04.png',
            parallaxFactor: 0.30,
          ),
          PixelParallaxLayerSpec(
            assetPath: 'parallax/field/Field Layer 05.png',
            parallaxFactor: 0.40,
          ),
          PixelParallaxLayerSpec(
            assetPath: 'parallax/field/Field Layer 06.png',
            parallaxFactor: 0.50,
          ),
          PixelParallaxLayerSpec(
            assetPath: 'parallax/field/Field Layer 07.png',
            parallaxFactor: 0.60,
          ),
          PixelParallaxLayerSpec(
            assetPath: 'parallax/field/Field Layer 08.png',
            parallaxFactor: 0.70,
          ),
        ],
      )..priority = -30,
    );

    camera.backdrop.add(
      TiledGroundBandComponent(
        assetPath: 'parallax/field/Field Layer 09.png',
        virtualWidth: v0VirtualWidth,
        virtualHeight: v0VirtualHeight,
        renderInBackdrop: true,
      )..priority = -20,
    );

    camera.backdrop.add(
      PixelParallaxBackdropComponent(
        virtualWidth: v0VirtualWidth,
        virtualHeight: v0VirtualHeight,
        snapScrollToPixels: false,
        layers: const [
          PixelParallaxLayerSpec(
            assetPath: 'parallax/field/Field Layer 10.png',
            parallaxFactor: 1.0,
          ),
        ],
      )..priority = -10,
    );

    _player = CircleComponent(
      radius: 8,
      paint: Paint()..color = const Color(0xFF4ADE80),
      anchor: Anchor.center,
    );
    world.add(_player);

    world.add(
      AimRayComponent(
        controller: controller,
        preview: projectileAimPreview,
        length: v0ProjectileAimRayLength,
      )..priority = 5,
    );

    world.add(
      AimRayComponent(
        controller: controller,
        preview: meleeAimPreview,
        length: v0MeleeAimRayLength,
        drawWhenNoAim: false,
        paint: Paint()
          ..color = const Color(0xFFDC4440)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      )..priority = 6,
    );

    _mountStaticSolids(controller.snapshot.staticSolids);
    _lastStaticSolidsSnapshot = controller.snapshot.staticSolids;

    /*     _debugText = TextComponent(
      text: '',
      position: Vector2(8, 8),
      anchor: Anchor.topLeft,
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 14,
          color: Color.fromARGB(255, 255, 0, 0),
        ),
      ),
    );
    camera.viewport.add(_debugText); */
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

    final player = _findPlayer(updatedSnapshot.entities);
    if (player != null) {
      final snappedX = player.pos.x.roundToDouble();
      final snappedY = player.pos.y.roundToDouble();
      _player.position.setValues(snappedX, snappedY);
    }
    camera.viewfinder.position = Vector2(
      updatedSnapshot.cameraCenterX.roundToDouble(),
      updatedSnapshot.cameraCenterY.roundToDouble(),
    );

    _syncEnemies(updatedSnapshot.entities);
    _syncProjectiles(updatedSnapshot.entities);
    _syncHitboxes(updatedSnapshot.entities);

    /*     assert(() {
      _debugText.text =
          'tick=${snapshot.tick} seed=${snapshot.seed} x=${player?.pos.x.toStringAsFixed(1) ?? '-'} y=${player?.pos.y.toStringAsFixed(1) ?? '-'} anim=${player?.anim.name ?? '-'}';
      return true;
    }()); */
  }

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
      rect.priority = -5;
      _staticSolids.add(rect);
      world.add(rect);
    }
  }

  /// Finds the player entity in the snapshot.
  EntityRenderSnapshot? _findPlayer(List<EntityRenderSnapshot> entities) {
    for (final e in entities) {
      if (e.kind == EntityKind.player) return e;
    }
    return null;
  }

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
        view.priority = -2;
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
        view.priority = -1;
        _projectiles[e.id] = view;
        world.add(view);
      } else {
        final size = e.size;
        if (size != null) {
          view.size.setValues(size.x, size.y);
        }
      }

      view.position.setValues(e.pos.x.roundToDouble(), e.pos.y.roundToDouble());
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
        view.priority = 1;
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
