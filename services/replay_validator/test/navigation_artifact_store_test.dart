import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:replay_validator/src/navigation_artifact_store.dart';
import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/navigation/terrain_graph_artifact.dart';
import 'package:runner_core/navigation/terrain_graph_artifact_manifest.dart';
import 'package:runner_core/navigation/terrain_runtime_bundle.dart';
import 'package:test/test.dart';

void main() {
  test('trusted disk artifacts hit across versions, evict, and fail open to Core construction', () {
    final directory = Directory.systemTemp.createTempSync('navigation-store-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final geometry = const TerrainCompiler().compile([
      TerrainPolygonInput.fromWorld(
        sourcePath: 'artifact/ground',
        identity: TerrainSourceIdentity(
          chunkIndex: 0,
          chunkKey: 'artifact',
          shapeId: 'ground',
        ),
        vertices: [(0, 100), (600, 100), (600, 200), (0, 200)],
      ),
    ], geometryVersion: 1);
    final bundle = TerrainRuntimeBundle.build(
      geometry: geometry,
      groundEnemyProfiles: buildDefaultGroundEnemyTerrainGraphProfiles(),
    );
    final entries = <String, TerrainGraphArtifactEntry>{};
    for (final graph in bundle.graphPublication.graphs) {
      final key = terrainGraphArtifactKey(
        geometry: geometry,
        surfaces: bundle.surfaceSet,
        profile: graph.buildProfile,
      );
      final bytes = TerrainGraphArtifactCodec.encode(key: key, graph: graph);
      File('${directory.path}/$key.rng').writeAsBytesSync(bytes);
      entries[key] = TerrainGraphArtifactEntry(
        sha256: sha256.convert(bytes).toString(),
        bytes: bytes.length,
      );
    }
    File('${directory.path}/manifest.json')
        .writeAsStringSync(TerrainGraphArtifactManifest(entries).encode());
    final store = NavigationArtifactStore(
      directory: directory.path,
      maxCachedBytes: 200,
    );
    final decoded = TerrainRuntimeBundle.build(
      geometry: geometry.withVersion(9),
      groundEnemyProfiles: bundle.graphProfiles,
      graphMaterializer: store.materializer,
    );
    expect(store.hits, 0);
    expect(decoded.graphSignature(), bundle.graphSignature());
    expect(store.hits, bundle.graphProfiles.length);
    expect(store.cachedBytes, lessThanOrEqualTo(200));
    final profile = bundle.graphProfiles.first;
    final key = terrainGraphArtifactKey(
      geometry: geometry,
      surfaces: bundle.surfaceSet,
      profile: profile,
    );
    File('${directory.path}/$key.rng').writeAsBytesSync([0]);
    final fresh = NavigationArtifactStore(directory: directory.path);
    expect(fresh.lookup(geometry, bundle.surfaceSet, profile), isNull);
    expect(fresh.invalid, 1);
    final fallback = TerrainRuntimeBundle.build(
      geometry: geometry,
      groundEnemyProfiles: bundle.graphProfiles,
      graphMaterializer: fresh.materializer,
    );
    expect(fallback.graphSignature(), bundle.graphSignature());
    final absent = NavigationArtifactStore(
      directory: '${directory.path}/absent',
    );
    expect(absent.lookup(geometry, bundle.surfaceSet, profile), isNull);
    expect(absent.misses, 1);
  });
}
