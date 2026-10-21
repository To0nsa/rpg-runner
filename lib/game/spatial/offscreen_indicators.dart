import 'dart:math' as math;
import 'dart:ui';

import 'package:runner_core/snapshots/entity_render_snapshot.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/snapshots/game_state_snapshot.dart';
import 'package:runner_core/tuning/score_tuning.dart';

import 'world_view_transform.dart';

/// Live actors at the renderer's interpolation time, excluding ghosts and death
/// poses. Coordinates are world units; camera shake is deliberately excluded so
/// screen-edge labels do not vibrate or appear during impact feedback.
class OffscreenIndicatorFrame {
  OffscreenIndicatorFrame({
    required this.runId,
    required this.camera,
    required Iterable<OffscreenIndicatorTarget> targets,
  }) : targets = List.unmodifiable(targets);

  factory OffscreenIndicatorFrame.fromSnapshots({
    required GameStateSnapshot current,
    required Map<int, EntityRenderSnapshot> previousById,
    required double alpha,
    required WorldViewTransform camera,
  }) {
    return OffscreenIndicatorFrame(
      runId: current.runId,
      camera: camera,
      targets: current.gameOver
          ? const []
          : [
              for (final entity in current.entities)
                if ((entity.kind == EntityKind.player ||
                        entity.kind == EntityKind.enemy) &&
                    entity.anim != AnimKey.death &&
                    entity.anim != AnimKey.casterDeath)
                  OffscreenIndicatorTarget(
                    id: entity.id,
                    isPlayer: entity.kind == EntityKind.player,
                    body: _interpolatedBody(
                      previousById[entity.id] ?? entity,
                      entity,
                      alpha,
                    ),
                  ),
            ],
    );
  }

  final int runId;
  final WorldViewTransform camera;
  final List<OffscreenIndicatorTarget> targets;

  static Rect _interpolatedBody(
    EntityRenderSnapshot previous,
    EntityRenderSnapshot current,
    double alpha,
  ) => Rect.fromCenter(
    center: Offset(
      lerpDouble(previous.pos.x, current.pos.x, alpha)!,
      lerpDouble(previous.pos.y, current.pos.y, alpha)!,
    ),
    width: current.size?.x ?? 0,
    height: current.size?.y ?? 0,
  );
}

/// Body bounds are a visibility hint from the snapshot, not collision authority.
class OffscreenIndicatorTarget {
  const OffscreenIndicatorTarget({
    required this.id,
    required this.isPlayer,
    required this.body,
  });

  final int id;
  final bool isPlayer;
  final Rect body;
}

enum OffscreenIndicatorEdge { left, top, topLeft }

/// One off-screen actor before HUD placement/grouping. [anchor] is in world
/// coordinates on the visible boundary; distance is body-to-viewport in metres.
class OffscreenIndicator {
  const OffscreenIndicator({
    required this.id,
    required this.isPlayer,
    required this.edge,
    required this.anchor,
    required this.distanceMeters,
  });

  final int id;
  final bool isPlayer;
  final OffscreenIndicatorEdge edge;
  final Offset anchor;
  final double distanceMeters;
}

/// Run-local presentation hysteresis. A new marker needs two world units of
/// clearance; an existing one hides as soon as its body touches the view.
/// Pass the actual cropped world rectangle, before HUD/safe-area insets.
class OffscreenIndicatorProjector {
  final Set<int> _visible = {};
  int? _runId;

  List<OffscreenIndicator> project(
    OffscreenIndicatorFrame frame,
    Rect visibleWorld,
  ) {
    if (_runId != frame.runId || visibleWorld.isEmpty) _visible.clear();
    _runId = frame.runId;
    if (visibleWorld.isEmpty) return const [];
    final result = <OffscreenIndicator>[];
    final retained = <int>{};
    for (final target in frame.targets) {
      final body = target.body;
      final leftGap = visibleWorld.left - body.right;
      final topGap = visibleWorld.top - body.bottom;
      final left = leftGap > 0;
      final top = topGap > 0;
      if (!left && !top) continue;
      if (!_visible.contains(target.id) && math.max(leftGap, topGap) < 2) {
        continue;
      }
      retained.add(target.id);
      final dx = math.max(
        0.0,
        math.max(leftGap, body.left - visibleWorld.right),
      );
      final dy = math.max(
        0.0,
        math.max(topGap, body.top - visibleWorld.bottom),
      );
      result.add(
        OffscreenIndicator(
          id: target.id,
          isPlayer: target.isPlayer,
          edge: left && top
              ? OffscreenIndicatorEdge.topLeft
              : left
              ? OffscreenIndicatorEdge.left
              : OffscreenIndicatorEdge.top,
          anchor: Offset(
            body.center.dx.clamp(visibleWorld.left, visibleWorld.right),
            body.center.dy.clamp(visibleWorld.top, visibleWorld.bottom),
          ),
          distanceMeters: math.sqrt(dx * dx + dy * dy) / kWorldUnitsPerMeter,
        ),
      );
    }
    _visible
      ..clear()
      ..addAll(retained);
    return result;
  }
}
