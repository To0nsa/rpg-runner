// Renderer-facing entity data extracted from the Core at the end of a tick.
//
// This is a read-only, serializable view of entity state for rendering only.
// It must not leak internal core storage details.
import '../math/vec2.dart';
import 'enums.dart';

/// Render-only view of an entity.
class EntityRenderSnapshot {
  const EntityRenderSnapshot({
    required this.id,
    required this.kind,
    required this.pos,
    required this.facing,
    required this.anim,
    this.vel,
    this.z,
    this.animFrame,
  });

  /// Stable entity identifier (protocol-stable).
  final int id;

  /// Broad entity classification for choosing visuals/behavior.
  final EntityKind kind;

  /// World position in virtual pixels.
  final Vec2 pos;

  /// Optional world velocity (useful for facing/animation).
  final Vec2? vel;

  /// Optional sort key for render ordering.
  final double? z;

  /// Facing direction for choosing sprites/poses.
  final Facing facing;

  /// Logical animation selection (renderer maps to assets).
  final AnimKey anim;

  /// Optional frame hint for deterministic animation in replays/networking.
  final int? animFrame;
}
