import 'dart:convert';
import 'dart:io';

import 'package:runner_core/collision/terrain/terrain_authoring_seam_signature.dart';

import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:test/test.dart';

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
      '77e6fa33bfe9dddd6b056804d0b4614576be33929b504d6b75679b6b931ec2e2',
    );
  });

  test('manifest rejects derived drift and duplicate transitions', () {
    final original = jsonDecode(
      File(_fixturePath).readAsStringSync(),
    ) as Map<String, Object?>;
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
