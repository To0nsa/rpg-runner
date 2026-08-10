import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Canonical record label for deterministic render-triangle lineage.
const String terrainAuthoringTriangleSignatureFormat = 'authoring-triangles-v1';

/// One triangle referencing a compiled polygon's canonical vertex indices.
///
/// Chunk, optional placement, and shape identity bind the index triple to its
/// source polygon. Collision edges remain a separate compiler-owned contract.
final class TerrainAuthoringTriangleRecord
    implements Comparable<TerrainAuthoringTriangleRecord> {
  TerrainAuthoringTriangleRecord({
    required this.chunkKey,
    required this.placementKey,
    required this.shapeId,
    required this.first,
    required this.second,
    required this.third,
  }) {
    if (chunkKey.isEmpty || shapeId.isEmpty) {
      throw ArgumentError('Triangle chunk and shape keys must not be empty.');
    }
    if (placementKey != null && placementKey!.isEmpty) {
      throw ArgumentError.value(
        placementKey,
        'placementKey',
        'A present value must not be empty.',
      );
    }
    if (first < 0 || second < 0 || third < 0) {
      throw ArgumentError('Triangle vertex indices must not be negative.');
    }
  }

  final String chunkKey;
  final String? placementKey;
  final String shapeId;
  final int first;
  final int second;
  final int third;

  /// Length-prefixed UTF-8 record for
  /// [terrainAuthoringTriangleSignatureFormat].
  String canonicalRecord() => _canonicalRecord(<String>[
    terrainAuthoringTriangleSignatureFormat,
    chunkKey,
    placementKey ?? '',
    shapeId,
    first.toString(),
    second.toString(),
    third.toString(),
  ]);

  @override
  int compareTo(TerrainAuthoringTriangleRecord other) {
    var order = chunkKey.compareTo(other.chunkKey);
    if (order != 0) return order;
    order = _compareNullable(placementKey, other.placementKey);
    if (order != 0) return order;
    order = shapeId.compareTo(other.shapeId);
    if (order != 0) return order;
    order = first.compareTo(other.first);
    if (order != 0) return order;
    order = second.compareTo(other.second);
    return order != 0 ? order : third.compareTo(other.third);
  }
}

/// Returns triangle records in canonical source-identity and index order.
///
/// Exact duplicates fail closed instead of changing a digest through repeated
/// derived data.
List<String> canonicalTerrainAuthoringTriangleRecords(
  Iterable<TerrainAuthoringTriangleRecord> records,
) {
  final ordered = List<TerrainAuthoringTriangleRecord>.of(records)..sort();
  for (var index = 1; index < ordered.length; index += 1) {
    if (ordered[index - 1].compareTo(ordered[index]) == 0) {
      final duplicate = ordered[index];
      throw ArgumentError(
        'Duplicate triangle ${duplicate.chunkKey}/'
        '${duplicate.placementKey ?? ''}/${duplicate.shapeId} '
        '${duplicate.first},${duplicate.second},${duplicate.third}.',
      );
    }
  }
  return List<String>.unmodifiable(
    ordered.map((record) => record.canonicalRecord()),
  );
}

/// SHA-256 digest of sorted [terrainAuthoringTriangleSignatureFormat] records.
String terrainAuthoringTriangleSignature(
  Iterable<TerrainAuthoringTriangleRecord> records,
) => sha256
    .convert(
      utf8.encode(canonicalTerrainAuthoringTriangleRecords(records).join('\n')),
    )
    .toString();

String _canonicalRecord(List<String> fields) =>
    fields.map((field) => '${utf8.encode(field).length}:$field').join('|');

int _compareNullable(String? left, String? right) {
  if (identical(left, right)) return 0;
  if (left == null) return -1;
  if (right == null) return 1;
  return left.compareTo(right);
}
