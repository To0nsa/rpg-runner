import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:runner_core/collision/terrain/terrain_authoring_seam_signature.dart';

import 'package:runner_content_pipeline/runner_content_pipeline.dart';

const String polygonTerrainSignatureProbeFormat =
    'polygon-terrain-signature-probe-v1';
const String _defaultFixtureDirectory =
    'test/fixtures/polygon_terrain_generator';
const String _chunkSourcePath = 'chunks/forest/fixture_chunk.json';

/// Rebuilds every staged-generator signature from checked-in source bytes.
Map<String, Object?> buildPolygonTerrainSignatureProbe({
  String fixtureDirectory = _defaultFixtureDirectory,
}) {
  String fixture(String name) =>
      File('$fixtureDirectory/$name').readAsStringSync();

  final prefabs = decodePolygonTerrainPrefabs(
    fixture('prefab_defs.json'),
    sourcePath: 'prefab_defs.json',
  );
  final chunk = decodePolygonTerrainChunk(
    fixture('chunk.json'),
    sourcePath: _chunkSourcePath,
  );
  final compilation = compilePolygonTerrainChunk(
    chunk: chunk,
    prefabSources: prefabs,
    sourcePath: _chunkSourcePath,
  );
  if (compilation.issues.isNotEmpty || compilation.compiled == null) {
    throw StateError(
      'Signature probe compilation failed: '
      '${compilation.issues.map((issue) => issue.code).join(', ')}.',
    );
  }
  final compiled = compilation.compiled!;
  final seamManifest = decodePolygonTerrainSeamManifest(
    fixture('reachable_seams.json'),
    sourcePath: '$fixtureDirectory/reachable_seams.json',
  );
  final isolatedManifest = PolygonTerrainSeamManifest(
    signature: TerrainAuthoringSeamSignature(const []),
    sourcePath: 'fixture:isolated-compiler',
  );
  final validation = validatePolygonTerrainSeams(
    chunks: <PolygonTerrainCompiledChunk>[compiled],
    manifest: isolatedManifest,
  );
  if (validation.issues.isNotEmpty || validation.batch == null) {
    throw StateError(
      'Signature probe seam validation failed: '
      '${validation.issues.map((issue) => issue.code).join(', ')}.',
    );
  }
  final stagedSource = renderStagedPolygonTerrainDart(validation.batch!);

  return <String, Object?>{
    'format': polygonTerrainSignatureProbeFormat,
    'authoringPolygonSignature': compiled.authoringPolygonSignature(),
    'sourceSignature': compiled.geometry.sourceSignature(),
    'edgeSignature': compiled.geometry.edgeSignature(),
    'placementSignature': compiled.placementSignature(),
    'triangleSignature': compiled.triangleSignature(),
    'seamSignature': seamManifest.signature.digest,
    'isolatedSeamSignature': isolatedManifest.signature.digest,
    'stagedArtifactSignature': sha256
        .convert(utf8.encode(stagedSource))
        .toString(),
  };
}

void main(List<String> arguments) {
  if (arguments.length > 1 ||
      (arguments.isNotEmpty && !arguments.single.startsWith('--fixtures='))) {
    stderr.writeln(
      'Usage: dart run tool/polygon_terrain_signature_probe.dart '
      '[--fixtures=<directory>]',
    );
    exitCode = 64;
    return;
  }
  final fixtureDirectory = arguments.isEmpty
      ? _defaultFixtureDirectory
      : arguments.single.substring('--fixtures='.length);
  if (fixtureDirectory.isEmpty) {
    stderr.writeln('Fixture directory must not be empty.');
    exitCode = 64;
    return;
  }
  stdout.writeln(
    jsonEncode(
      buildPolygonTerrainSignatureProbe(fixtureDirectory: fixtureDirectory),
    ),
  );
}
