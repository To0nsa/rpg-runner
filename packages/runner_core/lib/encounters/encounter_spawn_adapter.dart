import '../collision/terrain/terrain_numeric.dart';
import '../ecs/actor_facing.dart';
import '../ecs/entity_factory.dart';
import '../ecs/entity_id.dart';
import '../ecs/systems/world_motion_authority.dart';
import '../ecs/world.dart';
import '../enemies/enemy_catalog.dart';
import '../enemies/enemy_id.dart';
import '../navigation/terrain_spawn_placement.dart';
import '../npcs/npc_catalog.dart';
import '../spawn_service.dart';
import '../track/chunk_pattern.dart';
import 'encounter_definition.dart';
import 'encounter_instance.dart';

/// Atomically admits a complete roster against the currently published terrain.
final class EncounterSpawnAdapter {
  EncounterSpawnAdapter({
    required this.world,
    required this.motion,
    required this.spawns,
    required this.groundTopY,
    required this.flyingHoverOffsetY,
    this.enemies = const EnemyCatalog(),
    this.npcs = const NpcCatalog(),
  });
  final EcsWorld world;
  final WorldMotionAuthority motion;
  final SpawnService spawns;
  final double groundTopY;
  final double flyingHoverOffsetY;
  final EnemyCatalog enemies;
  final NpcCatalog npcs;

  EncounterSpawnResult spawn(
    EncounterOccurrence occurrence, {
    required int tick,
  }) {
    final placements = <String, TerrainSpawnPlacementResult>{};
    for (final member in occurrence.participants) {
      final TerrainActorSpawnPlacementProfile profile;
      final double initialY;
      switch (member) {
        case EncounterNpcPlacement():
          if (!NpcCatalog.supportedIds.contains(member.npcId)) {
            return EncounterSpawnRejected(
              'Unregistered NPC ${member.npcId.name}.',
            );
          }
          final actor = npcs.get(member.npcId);
          profile = TerrainNpcSpawnPlacementProfile.fromCatalog(
            catalog: npcs,
            npcId: member.npcId,
            facing: member.facing,
          );
          initialY = groundTopY - actor.collider.halfY - actor.collider.offsetY;
        case EncounterEnemyPlacement():
          final actor = enemies.get(member.enemyId);
          profile = TerrainEnemySpawnPlacementProfile.fromCatalog(
            catalog: enemies,
            enemyId: member.enemyId,
            facing: member.facing,
          );
          initialY = member.enemyId == EnemyId.unocoDemon
              ? groundTopY - flyingHoverOffsetY
              : groundTopY - actor.collider.halfY - actor.collider.offsetY;
      }
      final placement = motion.resolveSpawnPlacement(
        TerrainSpawnPlacementRequest(
          profile: profile,
          desiredBodyCenter: TerrainPoint(
            physicsCoordinateToTicks(occurrence.startX + member.x),
            physicsCoordinateToTicks(initialY),
          ),
          supportSelection: switch (member.placement) {
            SpawnPlacementMode.ground => TerrainSpawnSupportSelection.ground,
            SpawnPlacementMode.highestSurfaceAtX =>
              TerrainSpawnSupportSelection.highestSurfaceAtX,
            SpawnPlacementMode.obstacleTop =>
              TerrainSpawnSupportSelection.obstacleTop,
          },
          allowSameSupportClamp: false,
        ),
      );
      if (!placement.accepted) {
        return EncounterSpawnRejected('${member.id}: ${placement.diagnostic}');
      }
      if (member is EncounterNpcPlacement) {
        final body = placement.bodyCenter!;
        final margin =
            profile.capsule.radiusTicks +
            profile.capsule.resolvedOffsetXTicks.abs();
        if (body.xTicks - margin <
                physicsCoordinateToTicks(occurrence.startX) ||
            body.xTicks + margin > physicsCoordinateToTicks(occurrence.endX)) {
          return EncounterSpawnRejected(
            '${member.id}: full body does not fit its owning chunk.',
          );
        }
      }
      placements[member.id] = placement;
    }
    final entities = <String, EntityId>{};
    for (final member in occurrence.participants) {
      final placement = placements[member.id]!;
      final body = placement.bodyCenter!;
      final x = body.xTicks / terrainPhysicsTicksPerWorldUnit;
      final y = body.yTicks / terrainPhysicsTicksPerWorldUnit;
      final supportY = placement.supportPoint == null
          ? groundTopY
          : placement.supportPoint!.yTicks / terrainPhysicsTicksPerWorldUnit;
      final EntityId entity;
      switch (member) {
        case EncounterNpcPlacement():
          entity = EntityFactory(world).createNpc(
            npcId: member.npcId,
            posX: x,
            posY: y,
            facing: member.facing,
            catalog: npcs,
            chunkStartX: occurrence.startX,
            chunkEndX: occurrence.endX,
          );
        case EncounterEnemyPlacement():
          entity = member.enemyId == EnemyId.unocoDemon
              ? spawns.spawnUnocoDemon(
                  spawnX: x,
                  groundTopY: supportY,
                  spawnBodyY: y,
                )
              : spawns.spawnGroundEnemy(
                  enemyId: member.enemyId,
                  spawnX: x,
                  groundTopY: supportY,
                  spawnBodyY: y,
                  spawnTick: member.enemyId == EnemyId.hashash ? tick : null,
                );
          setActorFacing(world, entity, member.facing);
      }
      entities[member.id] = entity;
    }
    return EncounterSpawned(entities);
  }
}
