import '../collision/terrain/terrain_edge_index.dart';
import '../collision/terrain/terrain_numeric.dart';
import '../navigation/terrain_placement_query.dart';
import '../navigation/terrain_surface_extractor.dart';
import '../navigation/terrain_surface_spatial_index.dart';
import '../players/player_catalog.dart';
import '../players/player_character_registry.dart';
import '../players/player_tuning.dart';
import '../track/staged_terrain_world_geometry.dart';
import 'campaign_mission_definition.dart';

/// The exact support marker must accommodate each playable capsule; editor Play
/// and generated admission must not rely on spawn-time correction to repair it.
void validateCampaignStart(CampaignMissionDefinition mission) {
  final geometry = const StagedTerrainWorldGeometryBuilder().build(
    bindings: [
      for (var i = 0; i < mission.route.length; i++)
        mission.terrainCatalog.bind(
          chunkKey: mission.route.missionChunks[i].pattern.chunkKey!,
          chunkIndex: i,
          worldOriginXTicks: physicsCoordinateToTicks(i * 600.0),
        ),
    ],
    geometryVersion: 0,
  );
  final query = TerrainPlacementQuery(
    geometry: geometry,
    terrainIndex: TerrainEdgeIndex(edges: geometry.edges),
    surfaceIndex: TerrainSurfaceSpatialIndex(
      surfaceSet: const TerrainSurfaceExtractor().extract(geometry),
    ),
  );
  for (final character in PlayerCharacterRegistry.playable) {
    final actor = PlayerCatalogDerived.from(
      character.catalog,
      movement: MovementTuningDerived.from(
        character.tuning.movement,
        tickHz: 60,
      ),
      resources: ResourceTuningDerived.from(character.tuning.resource),
    ).archetype;
    final capsule = actor.worldContactCapsule;
    final x = physicsCoordinateToTicks(mission.worldX(mission.start));
    if (x + capsule.offsetXTicks - capsule.radiusTicks < 0 ||
        x + capsule.offsetXTicks + capsule.radiusTicks >
            physicsCoordinateToTicks(mission.worldWidth)) {
      throw ArgumentError('Player start capsule must fit the finite world.');
    }
    final result = query.resolveGrounded(
      TerrainGroundPlacementRequest(
        desiredBodyCenterXTicks: x,
        minimumSupportYTicks: physicsCoordinateToTicks(mission.start.y),
        maximumSupportYTicks: physicsCoordinateToTicks(mission.start.y),
        capsule: TerrainPlacementCapsule(
          radiusTicks: capsule.radiusTicks,
          verticalHalfSegmentTicks: capsule.verticalHalfSegmentTicks,
          resolvedOffsetXTicks: capsule.offsetXTicks,
          offsetYTicks: capsule.offsetYTicks,
        ),
        traversalProfile: actor.terrainTraversalProfile,
        supportRequirement: const TerrainSupportRequirement.groundedSpawn(),
      ),
    );
    if (!result.isValid) {
      throw ArgumentError(
        'Player start: ${result.validity.name} (${character.displayName}).',
      );
    }
  }
}
