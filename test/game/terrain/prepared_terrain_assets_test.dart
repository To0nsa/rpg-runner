import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/game/terrain/prepared_terrain_assets.dart';
import 'package:runner_core/navigation/terrain_graph_artifact.dart';
import 'package:runner_core/navigation/terrain_graph_artifact_manifest.dart';
import 'package:runner_core/navigation/terrain_runtime_bundle.dart';
import 'package:runner_core/track/staged_authored_terrain.dart';
import 'package:runner_core/track/staged_terrain_catalog.dart';
import 'package:runner_core/track/staged_terrain_stream_candidate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('native asset preparation preserves complete graphs and falls back on corruption or absence', () async {
    final catalog = StagedTerrainArtifactCatalog(
      artifact: stagedAuthoredTerrain,
    );
    final bindings = [
      catalog.bind(
        chunkKey: 'field_default_normal_001',
        chunkIndex: 0,
        worldOriginXTicks: 0,
      ),
    ];
    final profiles = buildDefaultGroundEnemyTerrainGraphProfiles();
    final expected = const StagedTerrainStreamCandidateBuilder()
        .buildFromBindings(
          bindings: bindings,
          geometryVersion: 0,
          groundEnemyProfiles: profiles,
        )
        .runtimeBundle;
    final files = <String, Uint8List>{};
    final entries = <String, TerrainGraphArtifactEntry>{};
    for (final graph in expected.graphPublication.graphs) {
      final key = terrainGraphArtifactKey(
        geometry: expected.geometry,
        surfaces: expected.surfaceSet,
        profile: graph.buildProfile,
      );
      final bytes = TerrainGraphArtifactCodec.encode(key: key, graph: graph);
      files['assets/navigation/$key.rng'] = bytes;
      entries[key] = TerrainGraphArtifactEntry(
        sha256: sha256.convert(bytes).toString(),
        bytes: bytes.length,
      );
    }
    files['assets/navigation/manifest.json'] = Uint8List.fromList(
      utf8.encode(TerrainGraphArtifactManifest(entries).encode()),
    );
    final assets = _Assets(files);
    final prepared = await PreparedTerrainAssets(bundle: assets)
        .prepare(bindings, profiles);
    expect(assets.graphReads, profiles.length);
    expect(prepared.runtimeBundle.graphSignature(), expected.graphSignature());

    files.values.first[0] ^= 1;
    final recovered = await PreparedTerrainAssets(bundle: assets)
        .prepare(bindings, profiles);
    expect(recovered.runtimeBundle.graphSignature(), expected.graphSignature());
    final missing = await PreparedTerrainAssets(bundle: _Assets({}))
        .prepare(bindings, profiles);
    expect(missing.runtimeBundle.graphSignature(), expected.graphSignature());
  });
}

final class _Assets extends CachingAssetBundle {
  _Assets(this.files);
  final Map<String, Uint8List> files;
  int graphReads = 0;

  @override
  Future<ByteData> load(String key) async {
    if (key.endsWith('.rng')) graphReads++;
    final bytes = files[key];
    if (bytes == null) throw FlutterError('Missing test asset $key');
    return ByteData.sublistView(bytes);
  }
}
