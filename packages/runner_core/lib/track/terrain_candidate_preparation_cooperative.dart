import '../navigation/types/terrain_surface_graph.dart';
import 'staged_terrain_catalog.dart';
import 'staged_terrain_stream_candidate.dart';

/// Startup workers: one cooperative lane avoids competing UI-thread work.
const startupPreparationConcurrency = 1;

/// Prepares exact terrain in event-queue slices on platforms without isolates.
Future<StagedTerrainStreamCandidate> prepareTerrainCandidate(
  List<StagedTerrainChunkBinding> bindings,
  List<TerrainSurfaceGraphBuildProfile> profiles,
) => const StagedTerrainStreamCandidateBuilder().buildFromBindingsCooperatively(
  bindings: bindings,
  geometryVersion: 0,
  groundEnemyProfiles: profiles,
);
