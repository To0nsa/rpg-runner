import '../collision/terrain/terrain_numeric.dart';
import '../ecs/entity_id.dart';
import '../ecs/systems/world_motion_authority.dart';
import '../spawn_service.dart';
import '../track/track_streamer.dart';
import 'boss_arena_placement.dart';

/// Creates the required boss only after complete terrain admission.
final class BossArenaSpawnAdapter {
  BossArenaSpawnAdapter({
    required this.motion,
    required this.spawns,
    required this.groundTopY,
  });
  final WorldMotionAuthority motion;
  final SpawnService spawns;
  final double groundTopY;

  EntityId? spawn(ActiveTrackChunkSnapshot chunk, int tick) {
    final def = chunk.bossArena!;
    final placement = resolveBossArenaPlacement(
      arena: def,
      startX: chunk.startX,
      groundTopY: groundTopY,
      resolve: motion.resolveSpawnPlacement,
    );
    if (placement == null) return null;
    final body = placement.bodyCenter!;
    return spawns.spawnGroundEnemy(
      enemyId: def.enemyId,
      spawnX: body.xTicks / terrainPhysicsTicksPerWorldUnit,
      groundTopY: groundTopY,
      spawnBodyY: body.yTicks / terrainPhysicsTicksPerWorldUnit,
    );
  }
}
