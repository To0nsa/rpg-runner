import '../collision/terrain/terrain_edge_id.dart';
import 'entity_id.dart';
import 'world.dart';

/// Read-only staged facade over terrain support and legacy collision flags.
///
/// An entity with [EcsWorld.terrainContact] is terrain-integrated; every other
/// entity keeps reading [EcsWorld.collision]. Supplying [geometryVersion]
/// rejects stale terrain support without mutating ECS state.
class WorldSupportView {
  const WorldSupportView(this.world);

  final EcsWorld world;

  bool usesTerrainContact(EntityId entity) => world.terrainContact.has(entity);

  bool isGrounded(EntityId entity, {int? geometryVersion}) {
    final terrainIndex = world.terrainContact.tryIndexOf(entity);
    if (terrainIndex != null) {
      return world.terrainContact.grounded[terrainIndex] &&
          (geometryVersion == null ||
              world.terrainContact.supportGeometryVersion[terrainIndex] ==
                  geometryVersion);
    }
    final collisionIndex = world.collision.tryIndexOf(entity);
    return collisionIndex != null && world.collision.grounded[collisionIndex];
  }

  bool hitCeiling(EntityId entity) {
    final terrainIndex = world.terrainContact.tryIndexOf(entity);
    if (terrainIndex != null) {
      return world.terrainContact.hitCeiling[terrainIndex];
    }
    final collisionIndex = world.collision.tryIndexOf(entity);
    return collisionIndex != null && world.collision.hitCeiling[collisionIndex];
  }

  bool hitLeft(EntityId entity) {
    final terrainIndex = world.terrainContact.tryIndexOf(entity);
    if (terrainIndex != null) {
      return world.terrainContact.hitLeft[terrainIndex];
    }
    final collisionIndex = world.collision.tryIndexOf(entity);
    return collisionIndex != null && world.collision.hitLeft[collisionIndex];
  }

  bool hitRight(EntityId entity) {
    final terrainIndex = world.terrainContact.tryIndexOf(entity);
    if (terrainIndex != null) {
      return world.terrainContact.hitRight[terrainIndex];
    }
    final collisionIndex = world.collision.tryIndexOf(entity);
    return collisionIndex != null && world.collision.hitRight[collisionIndex];
  }

  TerrainEdgeId? supportEdgeId(EntityId entity, {int? geometryVersion}) {
    final index = world.terrainContact.tryIndexOf(entity);
    if (index == null ||
        !isGrounded(entity, geometryVersion: geometryVersion)) {
      return null;
    }
    return world.terrainContact.supportEdgeId[index];
  }
}
