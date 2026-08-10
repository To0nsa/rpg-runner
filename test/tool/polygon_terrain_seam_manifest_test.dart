import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/collision/terrain/terrain_authoring_seam_signature.dart';

import '../../tool/polygon_terrain_seam_manifest.dart';

const String _fixturePath =
    'test/fixtures/polygon_terrain_generator/reachable_seams.json';

void main() {
  test('staged generator consumes the exact editor adjacency golden', () {
    final manifest = decodePolygonTerrainSeamManifest(
      File(_fixturePath).readAsStringSync(),
      sourcePath: _fixturePath,
    );

    expect(manifest.signature.transitions, hasLength(8));
    expect(
      manifest.signature.canonicalRecord,
      startsWith('$terrainAuthoringSeamSignatureFormat\n'),
    );
    expect(
      manifest.signature.digest,
      '9681ffb17f61812ec63f1522f9da99340fd1a3ba05b0103f7d8a5f0ffd76393b',
    );
  });

  test('manifest rejects derived drift and duplicate transitions', () {
    final original =
        jsonDecode(File(_fixturePath).readAsStringSync())
            as Map<String, Object?>;
    final drifted = Map<String, Object?>.of(original)
      ..['reachableAdjacencyDigest'] = '0' * 64;
    expect(
      () => decodePolygonTerrainSeamManifest(
        jsonEncode(drifted),
        sourcePath: 'drifted.json',
      ),
      throwsFormatException,
    );

    final duplicated = Map<String, Object?>.of(original);
    final transitions = List<Object?>.of(
      duplicated['transitions']! as List<Object?>,
    )..add((duplicated['transitions']! as List<Object?>).first);
    duplicated['transitions'] = transitions;
    expect(
      () => decodePolygonTerrainSeamManifest(
        jsonEncode(duplicated),
        sourcePath: 'duplicated.json',
      ),
      throwsFormatException,
    );
  });
}
