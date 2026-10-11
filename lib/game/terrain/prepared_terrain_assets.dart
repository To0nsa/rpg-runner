import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:runner_core/navigation/terrain_graph_artifact.dart';
import 'package:runner_core/navigation/terrain_graph_artifact_manifest.dart';
import 'package:runner_core/navigation/terrain_graph_materializer.dart';
import 'package:runner_core/navigation/terrain_runtime_bundle.dart';
import 'package:runner_core/navigation/types/terrain_surface_graph.dart';
import 'package:runner_core/track/staged_terrain_catalog.dart';
import 'package:runner_core/track/staged_terrain_stream_candidate.dart';
import 'package:runner_core/track/staged_terrain_world_geometry.dart';

/// Run-owned loader for the release's short prepared prefix. The existing Core
/// lookahead bounds candidate lifetime. No whole-course memory cache is kept.
/// Missing assets retain the normal native/cooperative preparation behavior.
final class PreparedTerrainAssets {
  PreparedTerrainAssets({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;
  final AssetBundle _bundle;
  Future<TerrainGraphArtifactManifest?>? _manifest;

  Future<TerrainGraphArtifactManifest?> _loadManifest() async {
    try {
      return TerrainGraphArtifactManifest.decode(
        await _bundle.loadString(
          'assets/navigation/manifest.json',
          cache: false,
        ),
      );
    } on FlutterError {
      return null;
    } on FormatException {
      return null;
    }
  }

  /// Loads only the exact selection's graph pieces, then builds off the frame
  /// path. Native construction runs in an isolate; web construction yields.
  Future<StagedTerrainStreamCandidate> prepare(
    List<StagedTerrainChunkBinding> bindings,
    List<TerrainSurfaceGraphBuildProfile> profiles,
  ) async {
    final manifest = await (_manifest ??= _loadManifest());
    final pieces = <String, Uint8List>{};
    final digests = <String, String>{};
    if (manifest != null) {
      final geometry = const StagedTerrainWorldGeometryBuilder().build(
        bindings: bindings,
        geometryVersion: 0,
      );
      final bundle = TerrainRuntimeBundle.build(
        geometry: geometry,
        groundEnemyProfiles: profiles,
        graphMaterializer: const TerrainGraphMaterializer.onDemand(),
      );
      // Serial loads bound in-flight bytes to this small active selection.
      for (final profile in profiles) {
        final key = terrainGraphArtifactKey(
          geometry: geometry,
          surfaces: bundle.surfaceSet,
          profile: profile,
        );
        final entry = manifest.entries[key];
        if (entry == null) continue;
        try {
          final data = await _bundle.load('assets/navigation/$key.rng');
          if (data.lengthInBytes != entry.bytes) continue;
          pieces[key] = data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          );
          digests[key] = entry.sha256;
        } on FlutterError {
          /* Normal preparation covers unavailable pieces. */
        }
      }
    }
    final request = _PreparedRequest(bindings, profiles, pieces, digests);
    if (kIsWeb) return _prepareCooperatively(request);
    return compute(_prepareNative, request, debugLabel: 'prepared-terrain');
  }
}

final class _PreparedRequest {
  const _PreparedRequest(
    this.bindings,
    this.profiles,
    this.pieces,
    this.digests,
  );
  final List<StagedTerrainChunkBinding> bindings;
  final List<TerrainSurfaceGraphBuildProfile> profiles;
  final Map<String, Uint8List> pieces;
  final Map<String, String> digests;

  TerrainGraphLookup get lookup => (geometry, surfaces, profile) {
    if (pieces.isEmpty) return null;
    final key = terrainGraphArtifactKey(
      geometry: geometry,
      surfaces: surfaces,
      profile: profile,
    );
    final bytes = pieces[key];
    if (bytes == null) return null;
    try {
      return TerrainGraphArtifactCodec.decode(
        bytes: bytes,
        expectedSha256: digests[key]!,
        key: key,
        surfaces: surfaces,
        profile: profile,
      );
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  };
}

StagedTerrainStreamCandidate _prepareNative(_PreparedRequest request) =>
    const StagedTerrainStreamCandidateBuilder().buildFromBindings(
      bindings: request.bindings,
      geometryVersion: 0,
      groundEnemyProfiles: request.profiles,
      graphMaterializer: TerrainGraphMaterializer.eager(lookup: request.lookup),
    );

Future<StagedTerrainStreamCandidate> _prepareCooperatively(
  _PreparedRequest request,
) => const StagedTerrainStreamCandidateBuilder().buildFromBindingsCooperatively(
  bindings: request.bindings,
  geometryVersion: 0,
  groundEnemyProfiles: request.profiles,
  graphLookup: request.lookup,
);
