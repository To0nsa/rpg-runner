// Flame rendering layer for the runner (Milestone 0 placeholder).
//
// Reads the latest `GameStateSnapshot` from `GameController` each frame and
// renders a minimal representation (a player dot + debug text). This file is
// intentionally tiny and non-authoritative: gameplay truth lives in Core.
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import '../core/contracts/v0_render_contract.dart';
import '../core/snapshots/entity_render_snapshot.dart';
import 'components/pixel_parallax_backdrop_component.dart';
import 'components/tiled_ground_band_component.dart';
import 'game_controller.dart';

/// Minimal Flame `Game` that renders from snapshots.
class RunnerFlameGame extends FlameGame {
  RunnerFlameGame({required this.controller})
      : super(
          camera: CameraComponent.withFixedResolution(
            width: v0VirtualWidth.toDouble(),
            height: v0VirtualHeight.toDouble(),
          ),
        );

  /// Bridge/controller that owns the simulation and produces snapshots.
  final GameController controller;

  late final CircleComponent _player;
  late final TextComponent _debugText;

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
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Step the deterministic core using the frame delta, then render the
    // newest snapshot.
    controller.advanceFrame(dt);
    final snapshot = controller.snapshot;

    final player = _findPlayer(snapshot.entities);
    if (player != null) {
      _player.position = _snapToPixels(Vector2(player.pos.x, player.pos.y));
      camera.viewfinder.position = _snapToPixels(
        Vector2(player.pos.x, v0CameraFixedY),
      );
    }

    assert(() {
      _debugText.text =
          'tick=${snapshot.tick} seed=${snapshot.seed} x=${player?.pos.x.toStringAsFixed(1) ?? '-'}';
      return true;
    }());
  }

  /// Finds the player entity in the snapshot (placeholder: first entity).
  EntityRenderSnapshot? _findPlayer(List<EntityRenderSnapshot> entities) {
    if (entities.isEmpty) return null;
    return entities.first;
  }

  Vector2 _snapToPixels(Vector2 value) {
    return Vector2(
      value.x.roundToDouble(),
      value.y.roundToDouble(),
    );
  }
}
