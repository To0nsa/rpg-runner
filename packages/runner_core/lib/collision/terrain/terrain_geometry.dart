import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'terrain_edge.dart';
import 'terrain_edge_id.dart';
import 'terrain_polygon.dart';

/// Immutable ordered output of one deterministic terrain compilation.
class TerrainGeometry {
  factory TerrainGeometry({
    required int version,
    required Iterable<TerrainPolygon> polygons,
    required Iterable<TerrainEdge> edges,
    Iterable<TerrainDiagnostic> diagnostics = const [],
  }) {
    if (version < 0) {
      throw ArgumentError.value(version, 'version', 'Must be non-negative.');
    }
    final polygonList = List<TerrainPolygon>.of(polygons)
      ..sort((left, right) {
        final identityOrder = left.identity.compareTo(right.identity);
        return identityOrder != 0
            ? identityOrder
            : left.sourcePath.compareTo(right.sourcePath);
      });
    final edgeList = List<TerrainEdge>.of(edges)
      ..sort((left, right) => left.id.compareTo(right.id));
    for (var index = 1; index < edgeList.length; index += 1) {
      if (edgeList[index - 1].id == edgeList[index].id) {
        throw ArgumentError.value(
          edgeList[index].id,
          'edges',
          'Edge IDs must be unique.',
        );
      }
    }
    final diagnosticList = List<TerrainDiagnostic>.of(diagnostics)..sort();
    return TerrainGeometry._(
      version: version,
      polygons: UnmodifiableListView<TerrainPolygon>(polygonList),
      edges: UnmodifiableListView<TerrainEdge>(edgeList),
      diagnostics: UnmodifiableListView<TerrainDiagnostic>(diagnosticList),
      edgeById: Map<TerrainEdgeId, TerrainEdge>.unmodifiable(
        <TerrainEdgeId, TerrainEdge>{
          for (final edge in edgeList) edge.id: edge,
        },
      ),
    );
  }

  const TerrainGeometry._({
    required this.version,
    required this.polygons,
    required this.edges,
    required this.diagnostics,
    required this.edgeById,
  });

  /// Caller-supplied monotonic geometry version.
  final int version;

  /// Canonically ordered normalized source polygons.
  final List<TerrainPolygon> polygons;

  /// Canonically ordered exposed runtime edges.
  final List<TerrainEdge> edges;

  /// Stable non-blocking normalization diagnostics.
  final List<TerrainDiagnostic> diagnostics;

  /// Diagnostic lookup kept outside hot candidate iteration.
  final Map<TerrainEdgeId, TerrainEdge> edgeById;

  /// SHA-256 digest of canonical `source-v1` UTF-8 records.
  String sourceSignature() => sha256
      .convert(utf8.encode(canonicalSourceRecords().join('\n')))
      .toString();

  /// SHA-256 digest of canonical `edges-v1` UTF-8 records.
  ///
  /// [indexMembershipRecords] must already be ordered by edge ID and cell.
  String edgeSignature({Iterable<String> indexMembershipRecords = const []}) {
    final records = <String>[
      ...canonicalEdgeRecords(),
      ...indexMembershipRecords,
    ];
    return sha256.convert(utf8.encode(records.join('\n'))).toString();
  }

  /// Canonical source records containing stable IDs and integer source ticks.
  List<String> canonicalSourceRecords() {
    final records = <String>[];
    for (final polygon in polygons) {
      final identity = polygon.identity;
      final fields = <String>[
        'source-v1',
        polygon.sourcePath,
        identity.chunkIndex.toString(),
        identity.chunkKey,
        identity.placementKey ?? '',
        identity.shapeId,
        polygon.collisionMode.name,
        polygon.surfaceKind ?? '',
        polygon.materialKey ?? '',
        polygon.sourceVertices.length.toString(),
      ];
      for (final vertex in polygon.sourceVertices) {
        fields
          ..add(vertex.xTicks.toString())
          ..add(vertex.yTicks.toString());
      }
      records.add(_canonicalRecord(fields));
    }
    return List<String>.unmodifiable(records);
  }

  /// Canonical exposed-edge records containing quantized integer fields only.
  List<String> canonicalEdgeRecords() {
    final records = <String>[];
    for (final edge in edges) {
      records.add(
        _canonicalRecord(<String>[
          'edges-v1',
          version.toString(),
          edge.id.canonicalKey,
          edge.start.xTicks.toString(),
          edge.start.yTicks.toString(),
          edge.end.xTicks.toString(),
          edge.end.yTicks.toString(),
          edge.tangent.xTicks.toString(),
          edge.tangent.yTicks.toString(),
          edge.outwardNormal.xTicks.toString(),
          edge.outwardNormal.yTicks.toString(),
          edge.collisionMode.name,
          edge.surfaceKind ?? '',
          edge.materialKey ?? '',
          edge.previousId?.canonicalKey ?? '',
          edge.nextId?.canonicalKey ?? '',
          edge.startJoin.name,
          edge.endJoin.name,
        ]),
      );
    }
    return List<String>.unmodifiable(records);
  }
}

String _canonicalRecord(List<String> fields) =>
    fields.map((field) => '${utf8.encode(field).length}:$field').join('|');
