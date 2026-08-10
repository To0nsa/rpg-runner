import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'terrain_edge.dart';
import 'terrain_geometry.dart';
import 'terrain_numeric.dart';
import 'terrain_polygon.dart';

/// Canonical evidence format for one side of compiled local terrain.
const String terrainBoundarySignatureFormat = 'authoring-boundary-v1';

/// Side of chunk-local compiled terrain.
enum TerrainBoundarySide { left, right }

/// One normalized positive-length interval occupied on a terrain boundary.
final class TerrainBoundaryInterval
    implements Comparable<TerrainBoundaryInterval> {
  const TerrainBoundaryInterval({
    required this.collisionMode,
    required this.minYTicks,
    required this.maxYTicks,
  });

  final TerrainCollisionMode collisionMode;
  final int minYTicks;
  final int maxYTicks;

  String get canonicalRecord => '${collisionMode.name}:$minYTicks..$maxYTicks';

  @override
  int compareTo(TerrainBoundaryInterval other) {
    var order = collisionMode.index.compareTo(other.collisionMode.index);
    if (order != 0) return order;
    order = minYTicks.compareTo(other.minYTicks);
    return order != 0 ? order : maxYTicks.compareTo(other.maxYTicks);
  }

  @override
  bool operator ==(Object other) =>
      other is TerrainBoundaryInterval &&
      collisionMode == other.collisionMode &&
      minYTicks == other.minYTicks &&
      maxYTicks == other.maxYTicks;

  @override
  int get hashCode => Object.hash(collisionMode, minYTicks, maxYTicks);
}

/// One boundary endpoint that must find compatible terrain continuation.
final class TerrainBoundaryVertex implements Comparable<TerrainBoundaryVertex> {
  const TerrainBoundaryVertex({
    required this.collisionMode,
    required this.surfaceKind,
    required this.yTicks,
  });

  final TerrainCollisionMode collisionMode;
  final String? surfaceKind;
  final int yTicks;

  String get canonicalRecord =>
      '${collisionMode.name}:${surfaceKind ?? ''}:$yTicks';

  @override
  int compareTo(TerrainBoundaryVertex other) {
    var order = collisionMode.index.compareTo(other.collisionMode.index);
    if (order != 0) return order;
    order = (surfaceKind ?? '').compareTo(other.surfaceKind ?? '');
    return order != 0 ? order : yTicks.compareTo(other.yTicks);
  }

  @override
  bool operator ==(Object other) =>
      other is TerrainBoundaryVertex &&
      collisionMode == other.collisionMode &&
      surfaceKind == other.surfaceKind &&
      yTicks == other.yTicks;

  @override
  int get hashCode => Object.hash(collisionMode, surfaceKind, yTicks);
}

/// Canonical evidence for one side of accepted compiled chunk geometry.
///
/// Physical compatibility uses normalized [coverageIntervals] and
/// [continuationVertices]. [edgeRecords] preserve exact compiled geometry and
/// material metadata without making render material phase a blocking rule.
final class TerrainBoundarySignature {
  TerrainBoundarySignature({
    required this.chunkKey,
    required this.side,
    required Iterable<TerrainBoundaryInterval> coverageIntervals,
    required Iterable<TerrainBoundaryVertex> continuationVertices,
    required Iterable<String> edgeRecords,
    required Map<TerrainBoundaryVertex, Iterable<String?>> materialKeysByVertex,
  }) : coverageIntervals = List<TerrainBoundaryInterval>.unmodifiable(
         List<TerrainBoundaryInterval>.of(coverageIntervals)..sort(),
       ),
       continuationVertices = List<TerrainBoundaryVertex>.unmodifiable(
         List<TerrainBoundaryVertex>.of(continuationVertices)..sort(),
       ),
       edgeRecords = List<String>.unmodifiable(
         List<String>.of(edgeRecords)..sort(),
       ),
       materialKeysByVertex =
           Map<TerrainBoundaryVertex, List<String?>>.unmodifiable(<
             TerrainBoundaryVertex,
             List<String?>
           >{
             for (final entry in materialKeysByVertex.entries)
               entry.key: List<String?>.unmodifiable(
                 entry.value.toSet().toList()
                   ..sort((left, right) => (left ?? '').compareTo(right ?? '')),
               ),
           }) {
    canonicalRecord = <String>[
      terrainBoundarySignatureFormat,
      'side=${side.name}',
      if (isEmpty) 'empty',
      for (final interval in this.coverageIntervals)
        'coverage=${interval.canonicalRecord}',
      for (final vertex in this.continuationVertices)
        'vertex=${vertex.canonicalRecord}',
      for (final record in this.edgeRecords) 'edge=$record',
    ].join('\n');
    digest = sha256.convert(utf8.encode(canonicalRecord)).toString();
  }

  final String chunkKey;
  final TerrainBoundarySide side;
  final List<TerrainBoundaryInterval> coverageIntervals;
  final List<TerrainBoundaryVertex> continuationVertices;
  final List<String> edgeRecords;
  final Map<TerrainBoundaryVertex, List<String?>> materialKeysByVertex;
  late final String canonicalRecord;
  late final String digest;

  bool get isEmpty => coverageIntervals.isEmpty && continuationVertices.isEmpty;

  String get physicalRecord => <String>[
    if (isEmpty) 'empty',
    for (final interval in coverageIntervals)
      'coverage=${interval.canonicalRecord}',
    for (final vertex in continuationVertices)
      'vertex=${vertex.canonicalRecord}',
  ].join(';');
}

/// Exact physical comparison of a right boundary against a left boundary.
final class TerrainBoundaryComparison {
  TerrainBoundaryComparison({
    required this.left,
    required this.right,
    required Iterable<TerrainBoundaryInterval> leftOnlyIntervals,
    required Iterable<TerrainBoundaryInterval> rightOnlyIntervals,
    required Iterable<TerrainBoundaryVertex> leftOnlyVertices,
    required Iterable<TerrainBoundaryVertex> rightOnlyVertices,
    required Iterable<TerrainBoundaryVertex> materialMismatchVertices,
  }) : leftOnlyIntervals = List<TerrainBoundaryInterval>.unmodifiable(
         leftOnlyIntervals,
       ),
       rightOnlyIntervals = List<TerrainBoundaryInterval>.unmodifiable(
         rightOnlyIntervals,
       ),
       leftOnlyVertices = List<TerrainBoundaryVertex>.unmodifiable(
         leftOnlyVertices,
       ),
       rightOnlyVertices = List<TerrainBoundaryVertex>.unmodifiable(
         rightOnlyVertices,
       ),
       materialMismatchVertices = List<TerrainBoundaryVertex>.unmodifiable(
         materialMismatchVertices,
       );

  final TerrainBoundarySignature left;
  final TerrainBoundarySignature right;
  final List<TerrainBoundaryInterval> leftOnlyIntervals;
  final List<TerrainBoundaryInterval> rightOnlyIntervals;
  final List<TerrainBoundaryVertex> leftOnlyVertices;
  final List<TerrainBoundaryVertex> rightOnlyVertices;
  final List<TerrainBoundaryVertex> materialMismatchVertices;

  bool get isCompatible =>
      leftOnlyIntervals.isEmpty &&
      rightOnlyIntervals.isEmpty &&
      leftOnlyVertices.isEmpty &&
      rightOnlyVertices.isEmpty;

  List<int> get mismatchYTicks {
    final values = <int>{};
    for (final interval in <TerrainBoundaryInterval>[
      ...leftOnlyIntervals,
      ...rightOnlyIntervals,
    ]) {
      values
        ..add(interval.minYTicks)
        ..add(interval.maxYTicks);
    }
    for (final vertex in <TerrainBoundaryVertex>[
      ...leftOnlyVertices,
      ...rightOnlyVertices,
    ]) {
      values.add(vertex.yTicks);
    }
    return List<int>.unmodifiable(values.toList()..sort());
  }
}

/// Builds one canonical boundary signature from accepted Core geometry.
TerrainBoundarySignature buildTerrainBoundarySignature({
  required String chunkKey,
  required int chunkWidth,
  required TerrainGeometry geometry,
  required TerrainBoundarySide side,
}) {
  final boundaryXTicks = switch (side) {
    TerrainBoundarySide.left => 0,
    TerrainBoundarySide.right => chunkWidth * terrainPhysicsTicksPerWorldUnit,
  };
  final rawIntervals = <TerrainBoundaryInterval>[];
  final vertices = <TerrainBoundaryVertex>{};
  final edgeRecords = <String>[];
  final materialKeys = <TerrainBoundaryVertex, Set<String?>>{};

  for (final edge in geometry.edges) {
    final startOnBoundary = edge.start.xTicks == boundaryXTicks;
    final endOnBoundary = edge.end.xTicks == boundaryXTicks;
    if (!startOnBoundary && !endOnBoundary) continue;

    edgeRecords.add(_boundaryEdgeRecord(edge));
    if (startOnBoundary && endOnBoundary) {
      final minY = edge.start.yTicks < edge.end.yTicks
          ? edge.start.yTicks
          : edge.end.yTicks;
      final maxY = edge.start.yTicks > edge.end.yTicks
          ? edge.start.yTicks
          : edge.end.yTicks;
      if (minY != maxY) {
        rawIntervals.add(
          TerrainBoundaryInterval(
            collisionMode: edge.collisionMode,
            minYTicks: minY,
            maxYTicks: maxY,
          ),
        );
      }
      continue;
    }

    final point = startOnBoundary ? edge.start : edge.end;
    final vertex = TerrainBoundaryVertex(
      collisionMode: edge.collisionMode,
      surfaceKind: edge.surfaceKind,
      yTicks: point.yTicks,
    );
    vertices.add(vertex);
    materialKeys.putIfAbsent(vertex, () => <String?>{}).add(edge.materialKey);
  }

  return TerrainBoundarySignature(
    chunkKey: chunkKey,
    side: side,
    coverageIntervals: _mergeBoundaryIntervals(rawIntervals),
    continuationVertices: vertices,
    edgeRecords: edgeRecords,
    materialKeysByVertex: materialKeys,
  );
}

/// Compares a right terrain boundary with the following left boundary.
TerrainBoundaryComparison compareTerrainBoundaries({
  required TerrainBoundarySignature left,
  required TerrainBoundarySignature right,
}) {
  if (left.side != TerrainBoundarySide.right ||
      right.side != TerrainBoundarySide.left) {
    throw ArgumentError('Seams require a right signature followed by a left.');
  }
  final leftIntervals = left.coverageIntervals.toSet();
  final rightIntervals = right.coverageIntervals.toSet();
  final leftVertices = left.continuationVertices.toSet();
  final rightVertices = right.continuationVertices.toSet();
  final sharedVertices = leftVertices.intersection(rightVertices).toList()
    ..sort();
  final materialMismatches = sharedVertices
      .where((vertex) {
        final leftMaterials =
            left.materialKeysByVertex[vertex] ?? const <String?>[];
        final rightMaterials =
            right.materialKeysByVertex[vertex] ?? const <String?>[];
        return !_nullableStringListsEqual(leftMaterials, rightMaterials);
      })
      .toList(growable: false);

  return TerrainBoundaryComparison(
    left: left,
    right: right,
    leftOnlyIntervals: (leftIntervals.difference(rightIntervals).toList()
      ..sort()),
    rightOnlyIntervals: (rightIntervals.difference(leftIntervals).toList()
      ..sort()),
    leftOnlyVertices: (leftVertices.difference(rightVertices).toList()..sort()),
    rightOnlyVertices: (rightVertices.difference(leftVertices).toList()
      ..sort()),
    materialMismatchVertices: materialMismatches,
  );
}

List<TerrainBoundaryInterval> _mergeBoundaryIntervals(
  Iterable<TerrainBoundaryInterval> source,
) {
  final ordered = List<TerrainBoundaryInterval>.of(source)..sort();
  final merged = <TerrainBoundaryInterval>[];
  for (final interval in ordered) {
    if (merged.isEmpty) {
      merged.add(interval);
      continue;
    }
    final previous = merged.last;
    if (previous.collisionMode == interval.collisionMode &&
        interval.minYTicks <= previous.maxYTicks) {
      merged[merged.length - 1] = TerrainBoundaryInterval(
        collisionMode: previous.collisionMode,
        minYTicks: previous.minYTicks,
        maxYTicks: interval.maxYTicks > previous.maxYTicks
            ? interval.maxYTicks
            : previous.maxYTicks,
      );
    } else {
      merged.add(interval);
    }
  }
  return merged;
}

String _boundaryEdgeRecord(TerrainEdge edge) => <String>[
  edge.id.canonicalKey,
  '${edge.start.xTicks},${edge.start.yTicks}',
  '${edge.end.xTicks},${edge.end.yTicks}',
  '${edge.tangent.xTicks},${edge.tangent.yTicks}',
  '${edge.outwardNormal.xTicks},${edge.outwardNormal.yTicks}',
  edge.collisionMode.name,
  edge.surfaceKind ?? '',
  edge.materialKey ?? '',
].join('|');

bool _nullableStringListsEqual(List<String?> left, List<String?> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
