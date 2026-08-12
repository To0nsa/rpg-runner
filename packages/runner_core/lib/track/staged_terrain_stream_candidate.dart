/// Composes one inactive, atomically publishable staged terrain candidate.
library;

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
/// [runtimeBundle] and [renderSnapshot] share the exact [geometry] object and
/// [geometryVersion]. The class has no tick scheduling or gameplay side
/// effect; a future `TrackManager` integration must replace this whole
/// candidate through one tick-boundary reference write.
final class StagedTerrainStreamCandidate {
  StagedTerrainStreamCandidate._({
    required this.bindings,
    required this.geometry,
    required this.runtimeBundle,
    required this.renderSnapshot,
  });

  /// Canonically ordered staged records selected by the existing scheduler.
  final List<StagedTerrainChunkBinding> bindings;

  /// One world-space collision source shared by every other candidate output.
  final TerrainGeometry geometry;

  /// Collision index, support query, and ground-enemy graph views.
  final TerrainRuntimeBundle runtimeBundle;

  /// Generated fill triangles over [geometry]'s exact world-space polygons.
  final StagedTerrainRenderSnapshot renderSnapshot;
}

/// Builds a complete staged terrain candidate without selecting it at runtime.
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
  /// No result is installed into `TrackManager`, `GameCore`, or a renderer.
  /// Errors from admission, binding, geometry, graphs, or generated triangles
  /// prevent creation of the entire candidate.
  StagedTerrainStreamCandidate build({
    required StagedTerrainArtifactCatalog catalog,
    required Iterable<ActiveTrackChunkSnapshot> activeChunks,
    required int geometryVersion,
    required Iterable<TerrainSurfaceGraphBuildProfile> groundEnemyProfiles,
  }) {
    final bindings = _streamBindingBuilder.build(
      catalog: catalog,
      activeChunks: activeChunks,
    );
    final geometry = _worldGeometryBuilder.build(
      bindings: bindings,
      geometryVersion: geometryVersion,
    );
    final runtimeBundle = _runtimeBundleBuilder.buildFromGeometry(
      geometry: geometry,
      groundEnemyProfiles: groundEnemyProfiles,
    );
    final renderSnapshot = _renderSnapshotBuilder.build(
      bindings: bindings,
      geometry: geometry,
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
    );
  }
}
