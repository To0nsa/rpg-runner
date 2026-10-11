import 'dart:isolate';

import '../navigation/types/terrain_surface_graph.dart';
import 'staged_terrain_catalog.dart';
import 'staged_terrain_stream_candidate.dart';

/// Startup workers: two native isolates overlap independent candidates.
const startupPreparationConcurrency = 2;

/// Transfers a complete candidate from an isolated, immutable-input build.
Future<StagedTerrainStreamCandidate> prepareTerrainCandidate(
  List<StagedTerrainChunkBinding> bindings,
  List<TerrainSurfaceGraphBuildProfile> profiles,
) => Isolate.run(
  () => const StagedTerrainStreamCandidateBuilder().buildFromBindings(
    bindings: bindings,
    geometryVersion: 0,
    groundEnemyProfiles: profiles,
  ),
  debugName: 'terrain-preparation',
);
