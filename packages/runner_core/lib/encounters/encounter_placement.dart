import '../collision/terrain/terrain_numeric.dart';
import '../enemies/enemy_catalog.dart';
import '../enemies/enemy_id.dart';
import '../navigation/terrain_spawn_placement.dart';
import '../npcs/npc_catalog.dart';
import '../track/chunk_pattern.dart';
import 'encounter_definition.dart';

/// Complete placement evidence, shared by runtime, Build, and authored Play.
final class EncounterPlacementResult {
  EncounterPlacementResult.accepted(
    Map<String, TerrainSpawnPlacementResult> placements,
  ) : placements = Map.unmodifiable(placements),
      diagnostic = null,
      memberId = null;
  const EncounterPlacementResult.rejected(this.diagnostic, {this.memberId})
    : placements = null;
  final Map<String, TerrainSpawnPlacementResult>? placements;
  final String? diagnostic;
  final String? memberId;
  bool get accepted => placements != null;
}

/// Preflights every required participant without creating entities or using RNG.
/// Authored X is never relocated to make an otherwise invalid roster fit.
EncounterPlacementResult resolveEncounterPlacement({
  required EncounterDefinition definition,
  required double startX,
  required double chunkWidth,
  required double groundTopY,
  required double flyingHoverOffsetY,
  required TerrainSpawnPlacementResult Function(TerrainSpawnPlacementRequest)
  resolve,
  EnemyCatalog enemies = const EnemyCatalog(),
  NpcCatalog npcs = const NpcCatalog(),
}) {
  try {
    definition.validateForChunk(chunkWidth);
  } on ArgumentError catch (error) {
    return EncounterPlacementResult.rejected(error.message.toString());
  }
  final placements = <String, TerrainSpawnPlacementResult>{};
  final members = <EncounterParticipant>[
    ...definition.npcs,
    ...definition.enemies,
  ]..sort((a, b) => a.id.compareTo(b.id));
  for (final member in members) {
    final TerrainActorSpawnPlacementProfile profile;
    final double initialY;
    switch (member) {
      case EncounterNpcPlacement():
        if (!NpcCatalog.supportedIds.contains(member.npcId)) {
          return EncounterPlacementResult.rejected(
            'Unregistered NPC ${member.npcId.name}.',
            memberId: member.id,
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
    final placement = resolve(
      TerrainSpawnPlacementRequest(
        profile: profile,
        desiredBodyCenter: TerrainPoint(
          physicsCoordinateToTicks(startX + member.x),
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
      return EncounterPlacementResult.rejected(
        placement.diagnostic,
        memberId: member.id,
      );
    }
    if (member is EncounterNpcPlacement) {
      final margin =
          profile.capsule.radiusTicks +
          profile.capsule.resolvedOffsetXTicks.abs();
      final x = placement.bodyCenter!.xTicks;
      if (x - margin < physicsCoordinateToTicks(startX) ||
          x + margin > physicsCoordinateToTicks(startX + chunkWidth)) {
        return EncounterPlacementResult.rejected(
          'Full body does not fit its owning chunk.',
          memberId: member.id,
        );
      }
    }
    placements[member.id] = placement;
  }
  return EncounterPlacementResult.accepted(placements);
}
