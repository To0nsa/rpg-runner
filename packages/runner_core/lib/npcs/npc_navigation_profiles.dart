import '../collision/terrain/terrain_numeric.dart';
import '../navigation/terrain_placement_query.dart';
import '../navigation/types/terrain_surface_graph.dart';
import '../navigation/utils/jump_template.dart';
import '../tuning/physics_tuning.dart';
import 'npc_catalog.dart';
import 'npc_id.dart';

String npcNavigationProfileKey(NpcId id) => 'npc_${id.name}';

/// Builds allied navigation from the same capsule, speed and gravity as motion.
List<TerrainSurfaceGraphBuildProfile> buildNpcNavigationProfiles({
  required int tickHz,
  required PhysicsTuning physics,
  NpcCatalog catalog = const NpcCatalog(),
}) => [
  for (final id in NpcCatalog.supportedIds)
    _profile(id, catalog, tickHz, physics),
];

TerrainSurfaceGraphBuildProfile _profile(
  NpcId id,
  NpcCatalog catalog,
  int tickHz,
  PhysicsTuning physics,
) {
  final actor = catalog.get(id);
  final terrain = catalog.terrainContactProfile(id);
  final capsule = terrain.capsule;
  final jump = JumpReachabilityTemplate.build(
    JumpProfile(
      jumpSpeed: actor.jumpSpeed,
      gravityY: physics.gravityY,
      maxAirTicks: (3 * actor.jumpSpeed / physics.gravityY * tickHz).ceil(),
      airSpeedX: actor.speedX,
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
  return TerrainSurfaceGraphBuildProfile(
    profileKey: npcNavigationProfileKey(id),
    traversalProfile: terrain.traversal,
    radiusTicks: capsule.radiusTicks,
    verticalHalfSegmentTicks: capsule.verticalHalfSegmentTicks,
    authoredOffsetXTicks: capsule.offsetXTicks,
    offsetYTicks: capsule.offsetYTicks,
    supportRequirement: const TerrainSupportRequirement.groundedEnemyRuntime(),
    locomotionSpeedTicksPerSecond: physicsCoordinateToTicks(actor.speedX),
    jumpTemplate: jump,
    simulationTicksPerSecond: tickHz,
  );
}
