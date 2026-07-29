import 'dart:collection';

import '../collision/terrain/terrain_edge_index.dart';
import '../collision/terrain/terrain_geometry.dart';
import '../collision/terrain/terrain_numeric.dart';
import '../enemies/enemy_catalog.dart';
import '../enemies/enemy_id.dart';
import '../tuning/ground_enemy_tuning.dart';
import '../tuning/physics_tuning.dart';
import 'terrain_placement_query.dart';
import 'terrain_surface_extractor.dart';
import 'terrain_surface_graph_builder.dart';
import 'terrain_surface_spatial_index.dart';
import 'types/terrain_navigation_surface.dart';
import 'types/terrain_surface_graph.dart';
import 'utils/jump_template.dart';

/// Immutable, version-coherent terrain data published to runtime consumers.
///
/// Every derived index and enemy graph is built before this object can be
/// observed. A world-motion authority may therefore replace one bundle with
/// another through a single reference write at a tick boundary.
final class TerrainRuntimeBundle {
  factory TerrainRuntimeBundle.build({
    required TerrainGeometry geometry,
    required Iterable<TerrainSurfaceGraphBuildProfile> groundEnemyProfiles,
  }) {
    final profiles = List<TerrainSurfaceGraphBuildProfile>.of(
      groundEnemyProfiles,
    );
    final byKey = <String, TerrainSurfaceGraphBuildProfile>{};
    for (final profile in profiles) {
      if (byKey.containsKey(profile.profileKey)) {
        throw ArgumentError(
          'Terrain runtime graph profile keys must be unique.',
        );
      }
      byKey[profile.profileKey] = profile;
    }
    final grojibProfile = byKey[EnemyId.grojib.name];
    final hashashProfile = byKey[EnemyId.hashash.name];
    if (profiles.length != 2 ||
        grojibProfile == null ||
        hashashProfile == null) {
      throw ArgumentError(
        'Terrain runtime publication requires exactly Grojib and Hashash '
        'graph profiles.',
      );
    }

    final edgeIndex = TerrainEdgeIndex(edges: geometry.edges);
    final surfaceSet = const TerrainSurfaceExtractor().extract(geometry);
    final surfaceIndex = TerrainSurfaceSpatialIndex(surfaceSet: surfaceSet);
    final placementQuery = TerrainPlacementQuery(
      geometry: geometry,
      terrainIndex: edgeIndex,
      surfaceIndex: surfaceIndex,
    );
    final graphBuilder = TerrainSurfaceGraphBuilder(
      placementQuery: placementQuery,
    );
    final graphPublication = TerrainSurfaceGraphPublication(
      <TerrainSurfaceGraph>[
        graphBuilder.build(grojibProfile),
        graphBuilder.build(hashashProfile),
      ],
    );

    if (surfaceSet.geometryVersion != geometry.version ||
        surfaceIndex.geometryVersion != geometry.version ||
        graphPublication.geometryVersion != geometry.version ||
        !identical(surfaceIndex.surfaceSet, surfaceSet) ||
        !identical(graphPublication.surfaceSet, surfaceSet)) {
      throw StateError(
        'Terrain runtime bundle components do not share one version and '
        'surface-set identity.',
      );
    }

    return TerrainRuntimeBundle._(
      geometry: geometry,
      edgeIndex: edgeIndex,
      surfaceSet: surfaceSet,
      surfaceIndex: surfaceIndex,
      graphPublication: graphPublication,
      graphProfiles: UnmodifiableListView<TerrainSurfaceGraphBuildProfile>(
        <TerrainSurfaceGraphBuildProfile>[grojibProfile, hashashProfile]
          ..sort((left, right) => left.profileKey.compareTo(right.profileKey)),
      ),
    );
  }

  const TerrainRuntimeBundle._({
    required this.geometry,
    required this.edgeIndex,
    required this.surfaceSet,
    required this.surfaceIndex,
    required this.graphPublication,
    required this.graphProfiles,
  });

  /// Canonical polygon and exposed-edge source for this publication.
  final TerrainGeometry geometry;

  /// Collision broadphase built from [geometry].
  final TerrainEdgeIndex edgeIndex;

  /// Actor-neutral navigation nodes shared by every graph view.
  final TerrainSurfaceSet surfaceSet;

  /// Navigation broadphase built over the exact [surfaceSet] instance.
  final TerrainSurfaceSpatialIndex surfaceIndex;

  /// Grojib and Hashash graph views sharing [surfaceSet].
  final TerrainSurfaceGraphPublication graphPublication;

  /// Canonically ordered profile inputs retained for deterministic rebuilds.
  final List<TerrainSurfaceGraphBuildProfile> graphProfiles;

  /// Shared runtime version used by collision, support, and graph consumers.
  int get version => geometry.version;

  TerrainSurfaceGraph get grojibGraph => graphPublication[EnemyId.grojib.name];

  TerrainSurfaceGraph get hashashGraph =>
      graphPublication[EnemyId.hashash.name];

  /// Version-independent signature of the shared navigation node set.
  String surfaceSignature() => surfaceSet.signature();

  /// Version-independent signature of both profile graph views.
  String graphSignature() => graphPublication.signature();
}

/// Builds the two canonical ground-enemy graph profiles from runtime tuning.
///
/// The supplied jump templates remain the same templates used by the legacy
/// TrackManager during Phase 3. This keeps graph reachability aligned without
/// making the isolated terrain bundle authoritative for production levels.
List<TerrainSurfaceGraphBuildProfile> buildGroundEnemyTerrainGraphProfiles({
  required EnemyCatalog enemyCatalog,
  required Map<EnemyId, JumpReachabilityTemplate> jumpTemplatesById,
  required int locomotionSpeedTicksPerSecond,
  required int simulationTicksPerSecond,
}) {
  if (locomotionSpeedTicksPerSecond <= 0 || simulationTicksPerSecond <= 0) {
    throw ArgumentError('Terrain graph speed and tick rate must be positive.');
  }
  return List<TerrainSurfaceGraphBuildProfile>.unmodifiable(
    <TerrainSurfaceGraphBuildProfile>[
      for (final enemyId in const <EnemyId>[EnemyId.grojib, EnemyId.hashash])
        _buildGroundEnemyProfile(
          enemyId: enemyId,
          enemyCatalog: enemyCatalog,
          jumpTemplate:
              jumpTemplatesById[enemyId] ??
              (throw ArgumentError(
                'Missing ${enemyId.name} jump template for terrain graph.',
              )),
          locomotionSpeedTicksPerSecond: locomotionSpeedTicksPerSecond,
          simulationTicksPerSecond: simulationTicksPerSecond,
        ),
    ],
  );
}

/// Baseline profiles used by direct authority harnesses that omit tuning.
///
/// GameCore always supplies level-derived profiles. These values mirror the
/// repository's default 60 Hz enemy locomotion and physics tuning so focused
/// authority tests do not need to construct the wider GameCore tuning graph.
List<TerrainSurfaceGraphBuildProfile>
buildDefaultGroundEnemyTerrainGraphProfiles({
  EnemyCatalog enemyCatalog = const EnemyCatalog(),
}) {
  const tickHz = 60;
  const locomotion = GroundEnemyLocomotionTuning();
  const physics = PhysicsTuning();
  final baseAirSeconds = physics.gravityY <= 0
      ? 1.0
      : (2 * locomotion.jumpSpeed.abs()) / physics.gravityY;
  final maxAirTicks = (baseAirSeconds * 1.5 * tickHz).ceil();
  final templates = <EnemyId, JumpReachabilityTemplate>{};
  for (final enemyId in const <EnemyId>[EnemyId.grojib, EnemyId.hashash]) {
    final terrain = enemyCatalog.terrainContactProfile(enemyId);
    final capsule = terrain.capsule;
    templates[enemyId] = JumpReachabilityTemplate.build(
      JumpProfile(
        jumpSpeed: locomotion.jumpSpeed,
        gravityY: physics.gravityY,
        maxAirTicks: maxAirTicks,
        airSpeedX: locomotion.speedX,
        dtSeconds: 1 / tickHz,
        agentHalfWidth: capsule.radiusTicks / terrainPhysicsTicksPerWorldUnit,
        agentHalfHeight:
            (capsule.radiusTicks + capsule.verticalHalfSegmentTicks) /
            terrainPhysicsTicksPerWorldUnit,
        requiredSupportFraction: 1 / 3,
        collideCeilings: terrain.traversal.collideCeilings,
        collideLeftWalls: terrain.traversal.collideLeftWalls,
        collideRightWalls: terrain.traversal.collideRightWalls,
      ),
    );
  }
  return buildGroundEnemyTerrainGraphProfiles(
    enemyCatalog: enemyCatalog,
    jumpTemplatesById: templates,
    locomotionSpeedTicksPerSecond: physicsCoordinateToTicks(
      locomotion.speedX,
      name: 'defaultGroundEnemyLocomotionSpeed',
    ),
    simulationTicksPerSecond: tickHz,
  );
}

TerrainSurfaceGraphBuildProfile _buildGroundEnemyProfile({
  required EnemyId enemyId,
  required EnemyCatalog enemyCatalog,
  required JumpReachabilityTemplate jumpTemplate,
  required int locomotionSpeedTicksPerSecond,
  required int simulationTicksPerSecond,
}) {
  final terrain = enemyCatalog.terrainContactProfile(enemyId);
  final capsule = terrain.capsule;
  return TerrainSurfaceGraphBuildProfile(
    profileKey: enemyId.name,
    traversalProfile: terrain.traversal,
    radiusTicks: capsule.radiusTicks,
    verticalHalfSegmentTicks: capsule.verticalHalfSegmentTicks,
    authoredOffsetXTicks: capsule.offsetXTicks,
    offsetYTicks: capsule.offsetYTicks,
    supportRequirement: const TerrainSupportRequirement.groundedEnemyRuntime(),
    locomotionSpeedTicksPerSecond: locomotionSpeedTicksPerSecond,
    jumpTemplate: jumpTemplate,
    simulationTicksPerSecond: simulationTicksPerSecond,
  );
}
