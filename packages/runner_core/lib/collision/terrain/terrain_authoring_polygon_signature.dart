import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'terrain_numeric.dart';
import 'terrain_polygon.dart';

/// Canonical record label for exact authored polygon source.
const String terrainAuthoringPolygonSignatureFormat = 'authoring-polygons-v1';

/// Source owner domains covered by [terrainAuthoringPolygonSignature].
enum TerrainAuthoringPolygonOwnerKind { chunk, prefab }

/// One exact, owner-local polygon before placement expansion or compilation.
///
/// The record intentionally includes only collision-authoring facts: stable
/// owner identity/revision, stable shape identity, collision metadata, and
/// ordered half-world-unit source ticks. Placement transforms have their own
/// signature contract.
final class TerrainAuthoringPolygonRecord
    implements Comparable<TerrainAuthoringPolygonRecord> {
  TerrainAuthoringPolygonRecord({
    required this.ownerKind,
    required this.ownerKey,
    required this.ownerId,
    required this.ownerRevision,
    required this.shapeId,
    required Iterable<SourceTerrainPoint> vertices,
    required this.collisionMode,
    required this.surfaceKind,
    required this.materialKey,
  }) : vertices = UnmodifiableListView<SourceTerrainPoint>(
         List<SourceTerrainPoint>.of(vertices),
       ) {
    if (ownerKey.isEmpty || ownerId.isEmpty || shapeId.isEmpty) {
      throw ArgumentError(
        'Terrain authoring owner keys, IDs, and shape IDs must not be empty.',
      );
    }
    if (ownerRevision <= 0) {
      throw ArgumentError.value(
        ownerRevision,
        'ownerRevision',
        'Must be positive.',
      );
    }
    if (this.vertices.length < 3) {
      throw ArgumentError.value(
        this.vertices,
        'vertices',
        'An authored polygon must contain at least three vertices.',
      );
    }
    if (surfaceKind?.isEmpty ?? false) {
      throw ArgumentError.value(
        surfaceKind,
        'surfaceKind',
        'A present value must not be empty.',
      );
    }
    if (materialKey?.isEmpty ?? false) {
      throw ArgumentError.value(
        materialKey,
        'materialKey',
        'A present value must not be empty.',
      );
    }
  }

  final TerrainAuthoringPolygonOwnerKind ownerKind;
  final String ownerKey;
  final String ownerId;
  final int ownerRevision;
  final String shapeId;
  final List<SourceTerrainPoint> vertices;
  final TerrainCollisionMode collisionMode;
  final String? surfaceKind;
  final String? materialKey;

  /// Length-prefixed UTF-8 record for [terrainAuthoringPolygonSignatureFormat].
  String canonicalRecord() {
    final fields = <String>[
      terrainAuthoringPolygonSignatureFormat,
      ownerKind.name,
      ownerKey,
      ownerId,
      ownerRevision.toString(),
      shapeId,
      collisionMode.name,
      surfaceKind ?? '',
      materialKey ?? '',
      vertices.length.toString(),
    ];
    for (final vertex in vertices) {
      fields
        ..add(vertex.xTicks.toString())
        ..add(vertex.yTicks.toString());
    }
    return _canonicalRecord(fields);
  }

  /// Orders unique source identities independently from input collection order.
  @override
  int compareTo(TerrainAuthoringPolygonRecord other) {
    var order = ownerKind.index.compareTo(other.ownerKind.index);
    if (order != 0) return order;
    order = ownerKey.compareTo(other.ownerKey);
    return order != 0 ? order : shapeId.compareTo(other.shapeId);
  }
}

/// Returns canonical records sorted by owner domain, owner key, and shape ID.
///
/// Duplicate owner-local shape identities are rejected instead of being
/// silently hashed into an invalid source set.
List<String> canonicalTerrainAuthoringPolygonRecords(
  Iterable<TerrainAuthoringPolygonRecord> records,
) {
  final ordered = List<TerrainAuthoringPolygonRecord>.of(records)..sort();
  for (var index = 1; index < ordered.length; index += 1) {
    if (ordered[index - 1].compareTo(ordered[index]) == 0) {
      final duplicate = ordered[index];
      throw ArgumentError(
        'Duplicate ${duplicate.ownerKind.name} polygon identity '
        '${duplicate.ownerKey}/${duplicate.shapeId}.',
      );
    }
  }
  return List<String>.unmodifiable(
    ordered.map((record) => record.canonicalRecord()),
  );
}

/// SHA-256 digest of sorted [terrainAuthoringPolygonSignatureFormat] records.
String terrainAuthoringPolygonSignature(
  Iterable<TerrainAuthoringPolygonRecord> records,
) => sha256
    .convert(
      utf8.encode(canonicalTerrainAuthoringPolygonRecords(records).join('\n')),
    )
    .toString();

String _canonicalRecord(List<String> fields) =>
    fields.map((field) => '${utf8.encode(field).length}:$field').join('|');
