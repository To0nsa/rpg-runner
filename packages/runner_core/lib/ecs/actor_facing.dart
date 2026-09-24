import '../snapshots/enums.dart';
import 'entity_id.dart';
import 'world.dart';

/// Shared actor facing for capsule offsets, placement and attack origins.
Facing actorFacing(EcsWorld world, EntityId entity) {
  final npc = world.npc.tryIndexOf(entity);
  if (npc != null) return world.npc.facing[npc];
  final enemy = world.enemy.tryIndexOf(entity);
  if (enemy != null) return world.enemy.facing[enemy];
  final movement = world.movement.tryIndexOf(entity);
  return movement == null ? Facing.right : world.movement.facing[movement];
}

Facing actorArtFacing(EcsWorld world, EntityId entity) {
  final npc = world.npc.tryIndexOf(entity);
  if (npc != null) return world.npc.artFacing[npc];
  final enemy = world.enemy.tryIndexOf(entity);
  if (enemy != null) return world.enemy.artFacing[enemy];
  final movement = world.movement.tryIndexOf(entity);
  return movement == null ? Facing.right : world.movement.artFacing[movement];
}

void setActorFacing(EcsWorld world, EntityId entity, Facing facing) {
  final npc = world.npc.tryIndexOf(entity);
  if (npc != null) {
    world.npc.facing[npc] = facing;
    return;
  }
  final enemy = world.enemy.tryIndexOf(entity);
  if (enemy != null) {
    world.enemy.facing[enemy] = facing;
    return;
  }
  final movement = world.movement.tryIndexOf(entity);
  if (movement != null) world.movement.facing[movement] = facing;
}
