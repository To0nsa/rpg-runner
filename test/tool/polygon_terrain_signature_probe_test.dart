import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/polygon_terrain_signature_probe.dart';

const String _fixtureDirectory = 'test/fixtures/polygon_terrain_generator';

void main() {
  test('probe binds every staged signature to reviewed fixture values', () {
    final probe = buildPolygonTerrainSignatureProbe();
    final compilationGolden =
        jsonDecode(File('$_fixtureDirectory/golden.json').readAsStringSync())
            as Map<String, Object?>;
    final seamGolden =
        jsonDecode(
              File(
                '$_fixtureDirectory/reachable_seams.json',
              ).readAsStringSync(),
            )
            as Map<String, Object?>;

    expect(probe['format'], polygonTerrainSignatureProbeFormat);
    for (final key in const <String>[
      'authoringPolygonSignature',
      'sourceSignature',
      'edgeSignature',
      'placementSignature',
      'triangleSignature',
    ]) {
      expect(probe[key], compilationGolden[key], reason: key);
    }
    expect(probe['seamSignature'], seamGolden['reachableAdjacencyDigest']);
    expect(
      probe['isolatedSeamSignature'],
      compilationGolden['isolatedSeamSignature'],
    );
    expect(
      probe['stagedArtifactSignature'],
      compilationGolden['stagedArtifactSignature'],
    );
  });

  test('two standalone Dart processes reproduce the exact probe', () {
    Map<String, Object?> runProbe() {
      final result = Process.runSync(
        _standaloneDartExecutable(),
        const <String>['run', 'tool/polygon_terrain_signature_probe.dart'],
        workingDirectory: Directory.current.path,
      );
      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(result.stderr, isEmpty);
      return jsonDecode((result.stdout as String).trim())
          as Map<String, Object?>;
    }

    final inProcess = buildPolygonTerrainSignatureProbe();
    expect(runProbe(), inProcess);
    expect(runProbe(), inProcess);
  });
}

String _standaloneDartExecutable() {
  final resolved = File(Platform.resolvedExecutable);
  if (_basenameWithoutExtension(resolved.path) == 'dart') return resolved.path;
  var directory = resolved.parent;
  while (true) {
    final candidate = File(
      '${directory.path}${Platform.pathSeparator}dart-sdk'
      '${Platform.pathSeparator}bin${Platform.pathSeparator}'
      '${Platform.isWindows ? 'dart.exe' : 'dart'}',
    );
    if (candidate.existsSync()) return candidate.path;
    final parent = directory.parent;
    if (parent.path == directory.path) break;
    directory = parent;
  }
  throw StateError(
    'Could not locate standalone Dart from ${Platform.resolvedExecutable}.',
  );
}

String _basenameWithoutExtension(String path) {
  final slash = path.lastIndexOf(RegExp(r'[/\\]'));
  final name = slash < 0 ? path : path.substring(slash + 1);
  final dot = name.lastIndexOf('.');
  return dot < 0 ? name : name.substring(0, dot);
}
