/// Renderer-facing entity data extracted from Core at the end of each tick.
///
/// This is a read-only, serializable view of entity state. It intentionally
/// hides internal ECS storage details and provides only what the renderer needs.
library;

import '../enemies/enemy_id.dart';
import '../util/vec2.dart';
import '../projectiles/projectile_id.dart';
import 'enums.dart';

/// Render-only snapshot of a single entity.
///
/// Created by [GameCore] after each simulation tick. Contains position,
/// animation state, and optional metadata for specialized rendering.
class EntityRenderSnapshot {
  const EntityRenderSnapshot({
    required this.id,
    required this.kind,
    required this.pos,
    required this.facing,
    required this.anim,
    required this.grounded,
    this.artFacingDir,
    this.vel,
    this.size,
    this.enemyId,
    this.projectileId,
    this.pickupVariant,
    this.z,
    this.rotationRad = 0.0,
    this.animFrame,
    this.statusVisualMask = EntityStatusVisualMask.none,
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

  /// Optional enemy archetype id (set when [kind] is [EntityKind.enemy]).
  final EnemyId? enemyId;

  /// Optional projectile archetype id (set when [kind] is [EntityKind.projectile]).
  final ProjectileId? projectileId;

  /// Optional pickup variant for render-only pickup styling.
  final int? pickupVariant;

  /// Optional sort key for render ordering.
  final double? z;

  /// Optional rotation (radians) for rendering orientation.
  final double rotationRad;

  /// Facing direction for choosing sprites/poses.
  final Facing facing;

  /// Direction the authored art faces when not mirrored.
  ///
  /// When null, render should assume `Facing.right`.
  final Facing? artFacingDir;

  /// Whether the entity is grounded at the end of the tick.
  ///
  /// This is authoritative collision state from Core (do not infer from anim).
  final bool grounded;

  /// Logical animation selection (renderer maps to assets).
  final AnimKey anim;

  /// Optional frame hint for deterministic animation in replays/networking.
  final int? animFrame;

  /// Bitmask of always-on status visuals for this entity.
  final int statusVisualMask;
}

/// Bitmask flags for persistent status visuals.
abstract class EntityStatusVisualMask {
  static const int none = 0;
  static const int slow = 1 << 0;
  static const int haste = 1 << 1;
  static const int vulnerable = 1 << 2;
  static const int weaken = 1 << 3;
  static const int drench = 1 << 4;
  static const int stun = 1 << 5;
  static const int silence = 1 << 6;
}

/// Variant codes for pickup rendering.
///
/// Maps to visual styles (colors, icons) in the renderer.
abstract class PickupVariant {
  static const int collectible = 0;
  static const int restorationHealth = 1;
  static const int restorationMana = 2;
  static const int restorationStamina = 3;
}
