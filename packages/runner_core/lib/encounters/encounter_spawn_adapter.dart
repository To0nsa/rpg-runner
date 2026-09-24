import '../collision/terrain/terrain_numeric.dart';
import '../ecs/actor_facing.dart';
import '../ecs/entity_factory.dart';
import '../ecs/entity_id.dart';
import '../ecs/systems/world_motion_authority.dart';
import '../ecs/world.dart';
import '../enemies/enemy_catalog.dart';
import '../enemies/enemy_id.dart';
import '../npcs/npc_catalog.dart';
import '../spawn_service.dart';
import 'encounter_definition.dart';
import 'encounter_instance.dart';
import 'encounter_placement.dart';

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
    final preflight = resolveEncounterPlacement(
      definition: occurrence.definition,
      startX: occurrence.startX,
      chunkWidth: occurrence.endX - occurrence.startX,
      groundTopY: groundTopY,
      flyingHoverOffsetY: flyingHoverOffsetY,
      resolve: motion.resolveSpawnPlacement,
      enemies: enemies,
      npcs: npcs,
    );
    if (!preflight.accepted) {
      return EncounterSpawnRejected(
        '${preflight.memberId ?? occurrence.definition.id}: ${preflight.diagnostic}',
      );
    }
    final placements = preflight.placements!;
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
