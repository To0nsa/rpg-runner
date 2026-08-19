import 'dart:convert';

import 'package:runner_core/collision/terrain/terrain_authoring_seam_signature.dart';

/// Strict scheduler-adjacency evidence consumed by staged terrain generation.
final class PolygonTerrainSeamManifest {
  const PolygonTerrainSeamManifest({
    required this.signature,
    required this.sourcePath,
  });

  final TerrainAuthoringSeamSignature signature;
  final String sourcePath;
}

/// Decodes a checked-in editor scheduler golden and verifies its derived data.
PolygonTerrainSeamManifest decodePolygonTerrainSeamManifest(
  String content, {
  required String sourcePath,
}) {
  final Object? decoded;
  try {
    decoded = jsonDecode(content);
  } on FormatException catch (error) {
    throw FormatException('$sourcePath: invalid JSON: ${error.message}.');
  }
  final root = _object(decoded, sourcePath);
  _requireExactKeys(root, const <String>{
    'format',
    'transitions',
    'reachableAdjacencyRecord',
    'reachableAdjacencyDigest',
  }, sourcePath);
  final format = _string(root['format'], '$sourcePath.format');
  if (format != terrainAuthoringSeamSignatureFormat) {
    throw FormatException(
      '$sourcePath.format: expected '
      '$terrainAuthoringSeamSignatureFormat, found $format.',
    );
  }
  final rawTransitions = _list(root['transitions'], '$sourcePath.transitions');
  final transitions = <TerrainAuthoringSeamTransition>[];
  for (var index = 0; index < rawTransitions.length; index += 1) {
    final path = '$sourcePath.transitions[$index]';
    final value = _object(rawTransitions[index], path);
    _requireExactKeys(value, const <String>{
      'levelId',
      'transitionId',
      'leftChunkKey',
      'rightChunkKey',
    }, path);
    try {
      transitions.add(
        TerrainAuthoringSeamTransition(
          levelId: _string(value['levelId'], '$path.levelId'),
          transitionId: _string(value['transitionId'], '$path.transitionId'),
          leftChunkKey: _string(value['leftChunkKey'], '$path.leftChunkKey'),
          rightChunkKey: _string(value['rightChunkKey'], '$path.rightChunkKey'),
        ),
      );
    } on ArgumentError catch (error) {
      throw FormatException('$path: $error');
    }
  }

  final TerrainAuthoringSeamSignature signature;
  try {
    signature = TerrainAuthoringSeamSignature(transitions);
  } on ArgumentError catch (error) {
    throw FormatException('$sourcePath.transitions: $error');
  }
  final expectedRecord = _string(
    root['reachableAdjacencyRecord'],
    '$sourcePath.reachableAdjacencyRecord',
  );
  final expectedDigest = _string(
    root['reachableAdjacencyDigest'],
    '$sourcePath.reachableAdjacencyDigest',
  );
  if (signature.canonicalRecord != expectedRecord) {
    throw FormatException(
      '$sourcePath.reachableAdjacencyRecord: does not match transitions.',
    );
  }
  if (signature.digest != expectedDigest) {
    throw FormatException(
      '$sourcePath.reachableAdjacencyDigest: does not match transitions.',
    );
  }
  return PolygonTerrainSeamManifest(
    signature: signature,
    sourcePath: sourcePath,
  );
}

Map<String, Object?> _object(Object? value, String path) {
  if (value is! Map<String, Object?>) {
    throw FormatException('$path: expected an object.');
  }
  return value;
}

List<Object?> _list(Object? value, String path) {
  if (value is! List<Object?>) {
    throw FormatException('$path: expected an array.');
  }
  return value;
}

String _string(Object? value, String path) {
  if (value is! String || value.isEmpty) {
    throw FormatException('$path: expected a non-empty string.');
  }
  return value;
}

void _requireExactKeys(
  Map<String, Object?> value,
  Set<String> expected,
  String path,
) {
  final actual = value.keys.toSet();
  if (actual.length == expected.length && actual.containsAll(expected)) return;
  final missing = expected.difference(actual).toList()..sort();
  final unexpected = actual.difference(expected).toList()..sort();
  throw FormatException(
    '$path: schema mismatch; missing=$missing, unexpected=$unexpected.',
  );
}
