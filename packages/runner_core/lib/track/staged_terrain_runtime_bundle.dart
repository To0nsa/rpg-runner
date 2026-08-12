/// Builds an atomic terrain-runtime candidate from staged chunk bindings.
library;

import '../collision/terrain/terrain_geometry.dart';
import '../navigation/terrain_runtime_bundle.dart';
import '../navigation/types/terrain_surface_graph.dart';
import 'staged_terrain_catalog.dart';
import 'staged_terrain_world_geometry.dart';

/// Produces the complete Phase 3 terrain bundle needed for one future
/// tick-boundary publication.
///
/// It first builds world-space geometry, then derives collision indexing,
/// support lookup, and both ground-enemy graph views before returning. This
/// adapter neither schedules a publication nor imports generated terrain into
/// normal Core construction; the future streamer owns those decisions.
final class StagedTerrainRuntimeBundleBuilder {
  const StagedTerrainRuntimeBundleBuilder({
    StagedTerrainWorldGeometryBuilder worldGeometryBuilder =
        const StagedTerrainWorldGeometryBuilder(),
  }) : _worldGeometryBuilder = worldGeometryBuilder;

  final StagedTerrainWorldGeometryBuilder _worldGeometryBuilder;

  /// Builds all geometry-derived runtime structures synchronously.
  ///
  /// [geometryVersion] must be assigned by the eventual owner of atomic
  /// publication. [groundEnemyProfiles] are explicit so this boundary cannot
  /// invent locomotion or jump tuning while assembling generated terrain.
  TerrainRuntimeBundle build({
    required Iterable<StagedTerrainChunkBinding> bindings,
    required int geometryVersion,
    required Iterable<TerrainSurfaceGraphBuildProfile> groundEnemyProfiles,
  }) {
    final geometry = _worldGeometryBuilder.build(
      bindings: bindings,
      geometryVersion: geometryVersion,
    );
    return buildFromGeometry(
      geometry: geometry,
      groundEnemyProfiles: groundEnemyProfiles,
    );
  }

  /// Derives collision and navigation structures from one already-built
  /// world-space geometry instance.
  ///
  /// Callers composing render data into the same publication must use this
  /// method so every consumer retains object identity, not merely equal
  /// geometry values.
  TerrainRuntimeBundle buildFromGeometry({
    required TerrainGeometry geometry,
    required Iterable<TerrainSurfaceGraphBuildProfile> groundEnemyProfiles,
  }) {
    return TerrainRuntimeBundle.build(
      geometry: geometry,
      groundEnemyProfiles: groundEnemyProfiles,
    );
  }
}
