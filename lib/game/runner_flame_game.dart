// Flame rendering layer for the runner (Milestone 0 placeholder).
//
// Reads the latest `GameStateSnapshot` from `GameController` each frame and
// renders a minimal representation (a player dot + debug text). This file is
// intentionally tiny and non-authoritative: gameplay truth lives in Core.
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/commands/command.dart';
import '../core/contracts/v0_render_contract.dart';
import '../core/snapshots/entity_render_snapshot.dart';
import '../core/snapshots/static_solid_snapshot.dart';
import 'components/pixel_parallax_backdrop_component.dart';
import 'components/tiled_ground_band_component.dart';
import 'game_controller.dart';

/// Minimal Flame `Game` that renders from snapshots.
class RunnerFlameGame extends FlameGame with KeyboardEvents {
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
  final List<RectangleComponent> _staticSolids = <RectangleComponent>[];

  // Keyboard input (dev/desktop): schedule tick-stamped commands.
  double _moveAxis = 0;
  double _lastScheduledAxis = 0;
  int _axisScheduledThroughTick = 0;

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
  }

  @override
  void update(double dt) {
    _enqueueHeldMoveAxis();

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

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    final heldLeft = keysPressed.contains(LogicalKeyboardKey.arrowLeft);
    final heldRight = keysPressed.contains(LogicalKeyboardKey.arrowRight);

    if (heldLeft && !heldRight) {
      _moveAxis = -1;
    } else if (heldRight && !heldLeft) {
      _moveAxis = 1;
    } else {
      _moveAxis = 0;
    }

    // Edge-triggered actions.
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        controller.enqueueForNextTick((tick) => JumpPressedCommand(tick: tick));
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        controller.enqueueForNextTick((tick) => DashPressedCommand(tick: tick));
      }
    }

    return KeyEventResult.handled;
  }

  void _enqueueHeldMoveAxis() {
    final axis = _moveAxis;

    // Only emit move commands when actively held; when released, core will
    // decelerate naturally because it resets axis to 0 each tick.
    if (axis == 0) {
      _axisScheduledThroughTick = controller.tick;
      _lastScheduledAxis = 0;
      return;
    }

    // If axis direction changed, re-schedule ahead so future ticks override.
    if (axis != _lastScheduledAxis) {
      _axisScheduledThroughTick = controller.tick;
      _lastScheduledAxis = axis;
    }

    // Cover the maximum number of fixed ticks that could be stepped in one
    // frame due to dt clamping (GameController defaults to 0.1s).
    final maxTicksPerFrame = (controller.tickHz * 0.1).ceil();
    final targetMaxTick =
        controller.tick + controller.inputLead + maxTicksPerFrame;

    final startTick = math.max(
      controller.tick + 1,
      _axisScheduledThroughTick + 1,
    );
    for (var t = startTick; t <= targetMaxTick; t += 1) {
      controller.enqueue(MoveAxisCommand(tick: t, axis: axis));
    }
    _axisScheduledThroughTick = targetMaxTick;
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
