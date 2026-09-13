/// Composes one complete, atomically publishable terrain candidate.
library;

import '../terrain/water_region.dart';
import '../collision/terrain/terrain_polygon.dart';
import '../collision/terrain/terrain_geometry.dart';
import '../navigation/terrain_runtime_bundle.dart';
import '../navigation/types/terrain_surface_graph.dart';
import '../snapshots/staged_terrain_render_snapshot.dart';
import 'staged_terrain_catalog.dart';
import 'staged_terrain_render_snapshot_builder.dart';
import 'staged_terrain_runtime_bundle.dart';
import 'staged_terrain_stream_bindings.dart';
import 'staged_terrain_world_geometry.dart';
import 'track_streamer.dart';

/// All immutable Core outputs required to publish staged terrain together.
///
/// [runtimeBundle] and [renderSnapshot] share one [geometryVersion]. The
/// render snapshot retains direct terrain boundaries separately so placed
/// Prefab collision cannot alter material decoration. The class has no tick
/// scheduling or gameplay side
/// effect. Normal streaming replaces this whole candidate whenever the
/// scheduler's active selection changes; terrain authority publication retains
/// the same atomic boundary. The `Staged` type prefix is the retained artifact
/// format name, not a non-production authority state.
final class StagedTerrainStreamCandidate {
  StagedTerrainStreamCandidate._({
    required this.bindings,
    required this.geometry,
    required this.runtimeBundle,
    required this.renderSnapshot,
    required this.waterRegions,
  });

  /// Canonically ordered generated records selected by the scheduler.
  final List<StagedTerrainChunkBinding> bindings;

  /// One world-space collision source shared by every other candidate output.
  final TerrainGeometry geometry;

  /// Collision index, support query, and ground-enemy graph views.
  final TerrainRuntimeBundle runtimeBundle;

  /// Direct Chunk terrain fills and boundaries paired with [geometry].
  final StagedTerrainRenderSnapshot renderSnapshot;

  /// Fluid query volumes published atomically with collision and rendering.
  final List<WaterRegion> waterRegions;

  /// Publishes a prepared selection under its actual monotonic Core version.
  ///
  /// Preparation never predicts how many intermediate selections a tick will
  /// skip. Rebinding changes only the version; geometry, navigation decisions,
  /// and generated render records retain their exact values.
  StagedTerrainStreamCandidate withGeometryVersion(int geometryVersion) {
    if (geometryVersion == geometry.version) return this;
    final bundle = runtimeBundle.withGeometryVersion(geometryVersion);
    return StagedTerrainStreamCandidate._(
      bindings: bindings,
      geometry: bundle.geometry,
      runtimeBundle: bundle,
      waterRegions: waterRegions,
      renderSnapshot: StagedTerrainRenderSnapshot(
        geometryVersion: geometryVersion,
        polygons: renderSnapshot.polygons,
        edges: renderSnapshot.edges,
        waterRegions: waterRegions,
      ),
    );
  }
}

/// Builds a complete terrain candidate from a selected runtime stream.
final class StagedTerrainStreamCandidateBuilder {
  const StagedTerrainStreamCandidateBuilder({
    StagedTerrainStreamBindingBuilder streamBindingBuilder =
        const StagedTerrainStreamBindingBuilder(),
    StagedTerrainWorldGeometryBuilder worldGeometryBuilder =
        const StagedTerrainWorldGeometryBuilder(),
    StagedTerrainRuntimeBundleBuilder runtimeBundleBuilder =
        const StagedTerrainRuntimeBundleBuilder(),
    StagedTerrainRenderSnapshotBuilder renderSnapshotBuilder =
        const StagedTerrainRenderSnapshotBuilder(),
  }) : _streamBindingBuilder = streamBindingBuilder,
       _worldGeometryBuilder = worldGeometryBuilder,
       _runtimeBundleBuilder = runtimeBundleBuilder,
       _renderSnapshotBuilder = renderSnapshotBuilder;

  final StagedTerrainStreamBindingBuilder _streamBindingBuilder;
  final StagedTerrainWorldGeometryBuilder _worldGeometryBuilder;
  final StagedTerrainRuntimeBundleBuilder _runtimeBundleBuilder;
  final StagedTerrainRenderSnapshotBuilder _renderSnapshotBuilder;

  /// Assembles all consumer outputs from the real active scheduler selection.
  ///
  /// Errors from admission, binding, geometry, graphs, or generated triangles
  /// prevent creation of the entire candidate before `GameCore` can publish
  /// its render snapshot or a terrain authority can consume its bundle.
  StagedTerrainStreamCandidate build({
    required StagedTerrainCatalog catalog,
    required Iterable<ActiveTrackChunkSnapshot> activeChunks,
    required int geometryVersion,
    required Iterable<TerrainSurfaceGraphBuildProfile> groundEnemyProfiles,
  }) {
    final bindings = _streamBindingBuilder.build(
      catalog: catalog,
      activeChunks: activeChunks,
    );
    return buildFromBindings(
      bindings: bindings,
      geometryVersion: geometryVersion,
      groundEnemyProfiles: groundEnemyProfiles,
    );
  }

  /// Builds from admitted bindings captured before background preparation.
  ///
  /// This shares the synchronous construction path, so prewarming cannot
  /// introduce different collision, navigation, or rendering rules.
  StagedTerrainStreamCandidate buildFromBindings({
    required List<StagedTerrainChunkBinding> bindings,
    required int geometryVersion,
    required Iterable<TerrainSurfaceGraphBuildProfile> groundEnemyProfiles,
  }) {
    bindings = List<StagedTerrainChunkBinding>.unmodifiable(bindings);
    final geometry = _worldGeometryBuilder.build(
      bindings: bindings,
      geometryVersion: geometryVersion,
    );
    final runtimeBundle = _runtimeBundleBuilder.buildFromGeometry(
      geometry: geometry,
      groundEnemyProfiles: groundEnemyProfiles,
    );
    final terrainSnapshot = _renderSnapshotBuilder.build(
      bindings: bindings,
      geometry: geometry,
    );
    final waterRegions = List<WaterRegion>.unmodifiable([
      for (final binding in bindings)
        for (final data in binding.chunk.waterRegions)
          WaterRegion(
            sourceId: TerrainSourceIdentity(
              chunkIndex: binding.chunkIndex,
              chunkKey: binding.chunk.chunkKey,
              shapeId: data.id,
            ),
            data: data,
            worldOriginXTicks: binding.worldOriginXTicks,
          ),
    ]);
    final renderSnapshot = StagedTerrainRenderSnapshot(
      geometryVersion: geometryVersion,
      polygons: terrainSnapshot.polygons,
      edges: terrainSnapshot.edges,
      waterRegions: waterRegions,
    );
    if (!identical(runtimeBundle.geometry, geometry) ||
        renderSnapshot.geometryVersion != geometry.version) {
      throw StateError(
        'Staged terrain candidate consumers do not share one geometry '
        'publication.',
      );
    }
    return StagedTerrainStreamCandidate._(
      bindings: bindings,
      geometry: geometry,
      runtimeBundle: runtimeBundle,
      renderSnapshot: renderSnapshot,
      waterRegions: waterRegions,
    );
  }
}
