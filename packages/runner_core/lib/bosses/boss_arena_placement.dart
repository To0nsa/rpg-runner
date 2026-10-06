import '../collision/terrain/terrain_numeric.dart';
import '../encounters/encounter_definition.dart';
import '../encounters/encounter_placement.dart';
import '../navigation/terrain_spawn_placement.dart';
import 'boss_arena_definition.dart';

/// Shared full-body arena preflight for Build, captured Play and live activation.
TerrainSpawnPlacementResult? resolveBossArenaPlacement({
  required BossArenaDefinition arena,
  required double startX,
  required double groundTopY,
  required TerrainSpawnPlacementResult Function(TerrainSpawnPlacementRequest)
  resolve,
}) {
  final request = createEncounterSpawnRequest(
    member: EncounterEnemyPlacement(
      id: arena.id,
      enemyId: arena.enemyId,
      x: arena.spawnX,
    ),
    startX: startX,
    groundTopY: groundTopY,
    flyingHoverOffsetY: 0,
  );
  final placement = resolve(request);
  if (!placement.accepted) return null;
  final capsule =
      (request.profile as TerrainActorSpawnPlacementProfile).capsule;
  final margin = capsule.radiusTicks + capsule.resolvedOffsetXTicks.abs();
  final x = placement.bodyCenter!.xTicks;
  if (x - margin < physicsCoordinateToTicks(startX + arena.minX) ||
      x + margin > physicsCoordinateToTicks(startX + arena.maxX)) {
    return null;
  }
  return placement;
}
