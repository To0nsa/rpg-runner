import 'package:runner_core/collision/terrain/terrain_edge_index.dart';
import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/navigation/terrain_placement_query.dart';
import 'package:runner_core/navigation/terrain_surface_extractor.dart';
import 'package:runner_core/navigation/terrain_surface_spatial_index.dart';
import 'package:runner_core/navigation/terrain_trajectory_predictor.dart';
import 'package:runner_core/players/player_catalog.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/snapshots/staged_terrain_render_snapshot.dart';
import 'package:runner_core/snapshots/terrain_player_debug_snapshot.dart';
import 'package:runner_core/track/staged_authored_terrain.dart';
import 'package:runner_core/track/staged_terrain_catalog.dart';
import 'package:runner_core/track/staged_terrain_world_geometry.dart';

/// Read-only obstacle lookahead for the untimed Éloïse recording fixture.
///
/// Rehydrates the published chunk occurrences with Core's generated catalog and
/// geometry builder, including prefab collision omitted from render edges.
/// Core's own predictor decides landing clearance; no simulated result is ever
/// applied to the recorded player.
final class ReplayBenchmarkTerrain {
  final _catalog = StagedTerrainArtifactCatalog(
    artifact: stagedAuthoredTerrain,
  );
  final _prediction = TerrainLandingPrediction();
  TerrainGeometry? _geometry;
  TerrainTrajectoryPredictor? _predictor;

  /// Requests an early jump only when Core predicts a forward landing.
  bool shouldJump(GameCore core, TerrainPlayerDebugSnapshot contact) {
    _refresh(core);
    // A 60-world-unit approach gives enough ascent before overhanging roofs.
    // Filter faces less than 16 units high or above the 100-unit jump arc;
    // smaller obstacles still trigger the recorder's wall-contact response.
    final nearObstacle = _geometry!.edges.any((edge) {
      final ahead = edge.bounds.minX - contact.capsuleCenterXTicks;
      return edge.outwardNormal.x < 0 &&
          ahead >= 0 &&
          ahead <= 60 * terrainPhysicsTicksPerWorldUnit &&
          edge.bounds.minY <
              contact.supportPointYTicks -
                  16 * terrainPhysicsTicksPerWorldUnit &&
          edge.bounds.maxY >
              contact.supportPointYTicks -
                  100 * terrainPhysicsTicksPerWorldUnit;
    });
    if (!nearObstacle || core.playerVelX <= 0) return false;
    return canJumpForward(core, contact);
  }

  /// Wait at a pit approach until the arc can reach its next foothold.
  /// Current speed includes stamina exhaustion and other movement modifiers.
  bool canJumpForward(GameCore core, TerrainPlayerDebugSnapshot contact) {
    _refresh(core);
    return _predictJump(core, contact, core.playerVelX) &&
        // Require a forward landing beyond one capsule diameter.
        _prediction.bodyCenterXTicks >
            contact.finalBodyXTicks + 2 * contact.capsuleRadiusTicks;
  }

  /// A missed stepping stone may leave a wall too high for a floor takeoff.
  /// Recover only when Core predicts an elevated foothold behind the player.
  bool canRetreat(GameCore core, TerrainPlayerDebugSnapshot contact) {
    _refresh(core);
    return _predictJump(
          core,
          contact,
          -PlayerCharacterRegistry.eloise.tuning.movement.maxSpeedX / 2,
        ) &&
        _prediction.bodyCenterXTicks <
            contact.finalBodyXTicks - 2 * contact.capsuleRadiusTicks &&
        _prediction.supportPointYTicks <
            contact.supportPointYTicks - 16 * terrainPhysicsTicksPerWorldUnit;
  }

  bool _predictJump(
    GameCore core,
    TerrainPlayerDebugSnapshot contact,
    double speedX,
  ) {
    final movement = PlayerCharacterRegistry.eloise.tuning.movement;
    return _predictor!.predictLanding(
      startBodyCenter: TerrainPoint(
        contact.finalBodyXTicks,
        contact.finalBodyYTicks,
      ),
      capsule: TerrainPlacementCapsule(
        radiusTicks: contact.capsuleRadiusTicks,
        verticalHalfSegmentTicks: contact.capsuleVerticalHalfSegmentTicks,
        resolvedOffsetXTicks:
            contact.capsuleCenterXTicks - contact.finalBodyXTicks,
        offsetYTicks: contact.capsuleCenterYTicks - contact.finalBodyYTicks,
      ),
      velocityX: speedX,
      velocityY: -movement.jumpSpeed,
      gravityY: LevelRegistry.byId(core.levelIdentity.requireRegisteredId())
          .tuning
          .physics
          .gravityY,
      maximumFallSpeed: movement.maxVelY,
      out: _prediction,
    );
  }

  void _refresh(GameCore core) {
    final snapshot = core.buildSnapshot().stagedTerrainRenderSnapshot!;
    if (_geometry?.version == snapshot.geometryVersion) return;
    final geometry = _rehydrate(snapshot);
    final character = PlayerCharacterRegistry.eloise;
    final archetype = PlayerCatalogDerived.from(
      character.catalog,
      movement: MovementTuningDerived.from(
        character.tuning.movement,
        tickHz: core.tickHz,
      ),
      resources: ResourceTuningDerived.from(character.tuning.resource),
    ).archetype;
    _predictor = TerrainTrajectoryPredictor(
      placementQuery: TerrainPlacementQuery(
        geometry: geometry,
        terrainIndex: TerrainEdgeIndex(edges: geometry.edges),
        surfaceIndex: TerrainSurfaceSpatialIndex(
          surfaceSet: const TerrainSurfaceExtractor().extract(geometry),
        ),
      ),
      traversalProfile: archetype.terrainTraversalProfile,
      supportRequirement:
          const TerrainSupportRequirement.groundedEnemyRuntime(),
      dtSeconds: 1 / core.tickHz,
      maxTicks: 2 * core.tickHz,
    );
    _geometry = geometry;
  }

  TerrainGeometry _rehydrate(StagedTerrainRenderSnapshot snapshot) {
    final bindings = <int, StagedTerrainChunkBinding>{};
    for (final polygon in snapshot.polygons) {
      final source = polygon.sourceId;
      if (bindings.containsKey(source.chunkIndex)) continue;
      final chunk = _catalog.requireChunk(source.chunkKey);
      final local = chunk.polygons.firstWhere(
        (candidate) =>
            candidate.id.shapeId == source.shapeId &&
            candidate.id.placementKey == source.placementKey,
      );
      bindings[source.chunkIndex] = _catalog.bind(
        chunkKey: source.chunkKey,
        chunkIndex: source.chunkIndex,
        worldOriginXTicks:
            polygon.vertices.first.xTicks - local.vertices.first.xTicks,
      );
    }
    return const StagedTerrainWorldGeometryBuilder().build(
      bindings: bindings.values,
      geometryVersion: snapshot.geometryVersion,
    );
  }
}
