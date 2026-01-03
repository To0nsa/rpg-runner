// Renderer-facing entity data extracted from the Core at the end of a tick.
//
// This is a read-only, serializable view of entity state for rendering only.
// It must not leak internal core storage details.
import '../math/vec2.dart';
import '../projectiles/projectile_id.dart';
import 'enums.dart';

/// Render-only view of an entity.
class EntityRenderSnapshot {
  const EntityRenderSnapshot({
    required this.id,
    required this.kind,
    required this.pos,
    required this.facing,
    required this.anim,
    required this.grounded,
    this.vel,
    this.size,
    this.projectileId,
    this.z,
    this.rotationRad = 0.0,
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

  /// Optional full extents in world units (virtual pixels).
  ///
  /// Render-only hint for placeholder shapes (e.g. projectile rectangles).
  final Vec2? size;

  /// Optional projectile archetype id (set when [kind] is [EntityKind.projectile]).
  final ProjectileId? projectileId;

  /// Optional sort key for render ordering.
  final double? z;

  /// Optional rotation (radians) for rendering orientation.
  final double rotationRad;

  /// Facing direction for choosing sprites/poses.
  final Facing facing;

  /// Whether the entity is grounded at the end of the tick.
  ///
  /// This is authoritative collision state from Core (do not infer from anim).
  final bool grounded;

  /// Logical animation selection (renderer maps to assets).
  final AnimKey anim;

  /// Optional frame hint for deterministic animation in replays/networking.
  final int? animFrame;
}
