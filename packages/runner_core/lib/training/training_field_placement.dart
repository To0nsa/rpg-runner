import '../collision/terrain/terrain_edge_index.dart';
import '../collision/terrain/terrain_numeric.dart';
import '../enemies/enemy_catalog.dart';
import '../enemies/enemy_id.dart';
import '../navigation/terrain_placement_query.dart';
import '../navigation/terrain_spawn_placement.dart';
import '../navigation/terrain_surface_extractor.dart';
import '../navigation/terrain_surface_spatial_index.dart';
import '../players/player_catalog.dart';
import '../players/player_character_registry.dart';
import '../players/player_tuning.dart';
import '../snapshots/enums.dart';
import '../track/staged_terrain_world_geometry.dart';
import '../tuning/flying_enemy_tuning.dart';
import 'training_field_definition.dart';

/// Source admission uses the same capsule/support rules as runtime spawning.
/// One marker must accommodate the complete regular roster, including Derf.
void validateTrainingFieldPlacement(TrainingFieldDefinition field) {
  final catalog = field.terrainCatalog;
  final queries = [
    for (var i = 0; i < 2; i++)
      (() {
        final geometry = const StagedTerrainWorldGeometryBuilder().build(
          bindings: [
            catalog.bind(
              chunkKey: field.chunks[i].chunkKey!,
              chunkIndex: i,
              worldOriginXTicks: 0,
            ),
          ],
          geometryVersion: 0,
        );
        return TerrainPlacementQuery(
          geometry: geometry,
          terrainIndex: TerrainEdgeIndex(edges: geometry.edges),
          surfaceIndex: TerrainSurfaceSpatialIndex(
            surfaceSet: const TerrainSurfaceExtractor().extract(geometry),
          ),
        );
      })(),
  ];
  for (final character in PlayerCharacterRegistry.all) {
    final player = PlayerCatalogDerived.from(
      character.catalog,
      movement: MovementTuningDerived.from(
        character.tuning.movement,
        tickHz: 60,
      ),
      resources: ResourceTuningDerived.from(character.tuning.resource),
    ).archetype;
    final capsule = player.worldContactCapsule;
    final placement = queries.first.resolveGrounded(
      TerrainGroundPlacementRequest(
        desiredBodyCenterXTicks: physicsCoordinateToTicks(field.playerStartX),
        minimumSupportYTicks: physicsCoordinateToTicks(field.playerStartY),
        maximumSupportYTicks: physicsCoordinateToTicks(field.playerStartY),
        capsule: TerrainPlacementCapsule(
          radiusTicks: capsule.radiusTicks,
          verticalHalfSegmentTicks: capsule.verticalHalfSegmentTicks,
          resolvedOffsetXTicks: capsule.offsetXTicks,
          offsetYTicks: capsule.offsetYTicks,
        ),
        traversalProfile: player.terrainTraversalProfile,
        supportRequirement: const TerrainSupportRequirement.groundedSpawn(),
      ),
    );
    if (!placement.isValid) {
      throw ArgumentError(
        'Player start: ${placement.validity.name} (${character.displayName}).',
      );
    }
  }
  const enemies = EnemyCatalog();
  final resolver = TerrainSpawnPlacementResolver(
    placementQuery: queries[field.enemyChunkIndex],
  );
  for (final id in EnemyId.values.where((id) => !id.isArenaOnly)) {
    final collider = enemies.get(id).collider;
    final y =
        field.enemySpawnY -
        (id == EnemyId.unocoDemon
            ? const UnocoDemonTuning().unocoDemonHoverOffsetY
            : collider.offsetY + collider.halfY);
    final placement = resolver.resolve(
      TerrainSpawnPlacementRequest(
        profile: TerrainEnemySpawnPlacementProfile.fromCatalog(
          catalog: enemies,
          enemyId: id,
          facing: Facing.left,
        ),
        desiredBodyCenter: TerrainPoint(
          physicsCoordinateToTicks(field.enemySpawnX),
          physicsCoordinateToTicks(y),
        ),
        supportSelection: TerrainSpawnSupportSelection.ground,
        requestedSupportYTicks: physicsCoordinateToTicks(field.enemySpawnY),
        allowSameSupportClamp: id != EnemyId.unocoDemon,
      ),
    );
    if (!placement.accepted) {
      throw ArgumentError(
        'Enemy spawn: ${id.displayName}: ${placement.diagnostic}.',
      );
    }
  }
}
