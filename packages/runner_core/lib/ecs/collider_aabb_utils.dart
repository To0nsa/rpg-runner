import 'entity_id.dart';
import 'world.dart';

/// Returns collider X offset mirrored by the entity's authored art-facing.
///
/// Colliders are authored relative to an "art-facing" direction.
/// When runtime facing differs from that authored direction, horizontal offset
/// is mirrored so collider placement flips with the sprite.
double colliderEffectiveOffsetX(
  EcsWorld world, {
  required EntityId entity,
  required int colliderIndex,
}) {
  final authoredOffsetX = world.colliderAabb.offsetX[colliderIndex];
  if (authoredOffsetX == 0.0) return authoredOffsetX;

  if (_isFacingMirrored(world, entity)) {
    return -authoredOffsetX;
  }
  return authoredOffsetX;
}

/// Returns the world-space collider center X for [entity].
double colliderCenterX(
  EcsWorld world, {
  required EntityId entity,
  required int transformIndex,
  required int colliderIndex,
}) {
  return world.transform.posX[transformIndex] +
      colliderEffectiveOffsetX(
        world,
        entity: entity,
        colliderIndex: colliderIndex,
      );
}

/// Returns the world-space collider center Y.
double colliderCenterY(
  EcsWorld world, {
  required int transformIndex,
  required int colliderIndex,
}) {
  return world.transform.posY[transformIndex] +
      world.colliderAabb.offsetY[colliderIndex];
}

bool _isFacingMirrored(EcsWorld world, EntityId entity) {
  final enemyIndex = world.enemy.tryIndexOf(entity);
  if (enemyIndex != null) {
    return world.enemy.facing[enemyIndex] != world.enemy.artFacing[enemyIndex];
  }

  final movementIndex = world.movement.tryIndexOf(entity);
  if (movementIndex != null) {
    return world.movement.facing[movementIndex] !=
        world.movement.artFacing[movementIndex];
  }

  return false;
}
