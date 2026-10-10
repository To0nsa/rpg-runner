import '../enemies/enemy_catalog.dart';
import '../npcs/npc_navigation_profiles.dart';
import '../tuning/ground_enemy_tuning.dart';
import '../tuning/physics_tuning.dart';
import 'terrain_runtime_bundle.dart';
import 'types/terrain_surface_graph.dart';

/// Complete navigation workload for a run, including dormant enemies and allies.
/// Profiles depend on catalog and simulation tuning, never live actor presence.
List<TerrainSurfaceGraphBuildProfile> buildActorNavigationProfiles({
  required EnemyCatalog enemyCatalog,
  required GroundEnemyLocomotionTuning locomotion,
  required PhysicsTuning physics,
  required int tickHz,
}) => List.unmodifiable([
  ...buildGroundEnemyTerrainGraphProfilesForTuning(
    enemyCatalog: enemyCatalog,
    locomotion: locomotion,
    physics: physics,
    tickHz: tickHz,
  ),
  ...buildNpcNavigationProfiles(tickHz: tickHz, physics: physics),
]);
