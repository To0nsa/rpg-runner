// Flame rendering layer for the runner (Milestone 0 placeholder).
//
// Reads the latest `GameStateSnapshot` from `GameController` each frame and
// renders a minimal representation (a player dot + debug text). This file is
// intentionally tiny and non-authoritative: gameplay truth lives in Core.
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';

import '../core/contracts/v0_render_contract.dart';
import '../core/snapshots/entity_render_snapshot.dart';
import '../core/snapshots/static_solid_snapshot.dart';
import 'input/runner_input_router.dart';
import 'components/pixel_parallax_backdrop_component.dart';
import 'components/tiled_ground_band_component.dart';
import 'components/hud_bars_component.dart';
import 'game_controller.dart';

/// Minimal Flame `Game` that renders from snapshots.
class RunnerFlameGame extends FlameGame {
  RunnerFlameGame({required this.controller, required this.input})
    : super(
        camera: CameraComponent.withFixedResolution(
          width: v0VirtualWidth.toDouble(),
          height: v0VirtualHeight.toDouble(),
        ),
      );

  /// Bridge/controller that owns the simulation and produces snapshots.
  final GameController controller;

  /// Input scheduler/aggregator (touch + keyboard + mouse).
  final RunnerInputRouter input;

  late final CircleComponent _player;
  late final TextComponent _debugText;
  final List<RectangleComponent> _staticSolids = <RectangleComponent>[];

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

    _mountStaticSolids(controller.snapshot.staticSolids);

    _debugText = TextComponent(
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
    camera.viewport.add(_debugText);

    camera.viewport.add(
      HudBarsComponent(
        controller: controller,
        position: Vector2(8, 8),
        anchor: Anchor.topLeft,
      )..priority = 100,
    );
  }

  @override
  void update(double dt) {
    input.pumpHeldInputs();

    super.update(dt);

    // Step the deterministic core using the frame delta, then render the
    // newest snapshot.
    controller.advanceFrame(dt);
    final snapshot = controller.snapshot;

    final player = _findPlayer(snapshot.entities);
    if (player != null) {
      final snappedX = player.pos.x.roundToDouble();
      final snappedY = player.pos.y.roundToDouble();
      _player.position.setValues(snappedX, snappedY);
      camera.viewfinder.position = Vector2(
        snappedX,
        v0CameraFixedY.roundToDouble(),
      );
    }

    assert(() {
      _debugText.text =
          'tick=${snapshot.tick} seed=${snapshot.seed} x=${player?.pos.x.toStringAsFixed(1) ?? '-'} y=${player?.pos.y.toStringAsFixed(1) ?? '-'} anim=${player?.anim.name ?? '-'}';
      return true;
    }());
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

  /// Finds the player entity in the snapshot (placeholder: first entity).
  EntityRenderSnapshot? _findPlayer(List<EntityRenderSnapshot> entities) {
    if (entities.isEmpty) return null;
    return entities.first;
  }

  @override
  void onRemove() {
    images.clearCache();
    super.onRemove();
  }
}
