import 'dart:collection';

import 'terrain_edge_id.dart';
import 'terrain_numeric.dart';

/// Collision behavior authored independently from semantic/render metadata.
enum TerrainCollisionMode { solid, oneWay }

/// Stable source identity shared by polygons and their compiled edges.
class TerrainSourceIdentity implements Comparable<TerrainSourceIdentity> {
  factory TerrainSourceIdentity({
    required int chunkIndex,
    required String chunkKey,
    required String shapeId,
    String? placementKey,
  }) {
    if (chunkKey.isEmpty || shapeId.isEmpty) {
      throw ArgumentError('Terrain source keys must not be empty.');
    }
    if (placementKey != null && placementKey.isEmpty) {
      throw ArgumentError('A present placement key must not be empty.');
    }
    return TerrainSourceIdentity._(
      chunkIndex: chunkIndex,
      chunkKey: chunkKey,
      placementKey: placementKey,
      shapeId: shapeId,
    );
  }

  const TerrainSourceIdentity._({
    required this.chunkIndex,
    required this.chunkKey,
    required this.placementKey,
    required this.shapeId,
  });

  /// Signed authored chunk order; base terrain may use a negative index.
  final int chunkIndex;

  /// Stable chunk key within [chunkIndex].
  final String chunkKey;

  /// Stable placed-prefab selection key, or `null` for direct chunk source.
  final String? placementKey;

  /// Stable shape key within the chunk or placement.
  final String shapeId;

  /// Derives deterministic edge lineage from this source identity.
  TerrainEdgeId edgeId(int localEdgeIndex, {int subEdgeIndex = 0}) =>
      TerrainEdgeId(
        chunkIndex: chunkIndex,
        chunkKey: chunkKey,
        placementKey: placementKey,
        shapeId: shapeId,
        localEdgeIndex: localEdgeIndex,
        subEdgeIndex: subEdgeIndex,
      );

  @override
  int compareTo(TerrainSourceIdentity other) =>
      edgeId(0).compareTo(other.edgeId(0));

  @override
  bool operator ==(Object other) =>
      other is TerrainSourceIdentity &&
      chunkIndex == other.chunkIndex &&
      chunkKey == other.chunkKey &&
      placementKey == other.placementKey &&
      shapeId == other.shapeId;

  /// Collection hash only; canonical signatures serialize ordered fields.
  @override
  int get hashCode => Object.hash(chunkIndex, chunkKey, placementKey, shapeId);
}

/// Untrusted source polygon passed to runtime-safe canonicalization.
///
/// Vertices remain in authored half-world-unit ticks until [transform] is
/// applied exactly once by the compiler.
class TerrainPolygonInput {
  TerrainPolygonInput({
    required this.sourcePath,
    required this.identity,
    required Iterable<SourceTerrainPoint> vertices,
    this.collisionMode = TerrainCollisionMode.solid,
    this.surfaceKind,
    this.materialKey,
    this.transform = const TerrainSourceTransform(),
  }) : vertices = List<SourceTerrainPoint>.unmodifiable(vertices);

  /// Convenience constructor that rejects non-half-grid world coordinates.
  TerrainPolygonInput.fromWorld({
    required String sourcePath,
    required TerrainSourceIdentity identity,
    required Iterable<(double, double)> vertices,
    TerrainCollisionMode collisionMode = TerrainCollisionMode.solid,
    String? surfaceKind,
    String? materialKey,
    TerrainSourceTransform transform = const TerrainSourceTransform(),
  }) : this(
         sourcePath: sourcePath,
         identity: identity,
         vertices: vertices.map(
           (point) => SourceTerrainPoint.fromWorld(point.$1, point.$2),
         ),
         collisionMode: collisionMode,
         surfaceKind: surfaceKind,
         materialKey: materialKey,
         transform: transform,
       );

  /// Stable diagnostic path; compilation rejects an empty value.
  final String sourcePath;

  /// Canonical lineage shared with every compiled edge.
  final TerrainSourceIdentity identity;

  /// Immutable authored loop in half-world-unit ticks.
  final List<SourceTerrainPoint> vertices;

  /// Physical sidedness, independent from semantic metadata.
  final TerrainCollisionMode collisionMode;

  /// Optional gameplay surface classifier retained without interpretation.
  final String? surfaceKind;

  /// Optional material classifier retained without interpretation.
  final String? materialKey;

  /// Placement transform applied once during compilation.
  final TerrainSourceTransform transform;
}

/// Immutable canonical source polygon and its transformed physics loop.
class TerrainPolygon {
  TerrainPolygon({
    required this.sourcePath,
    required this.identity,
    required Iterable<SourceTerrainPoint> sourceVertices,
    required Iterable<TerrainPoint> vertices,
    required this.collisionMode,
    required this.surfaceKind,
    required this.materialKey,
  }) : sourceVertices = UnmodifiableListView<SourceTerrainPoint>(
         List<SourceTerrainPoint>.of(sourceVertices),
       ),
       vertices = UnmodifiableListView<TerrainPoint>(
         List<TerrainPoint>.of(vertices),
       );

  /// Stable diagnostic path inherited from the source.
  final String sourcePath;

  /// Canonical lineage shared with every compiled edge.
  final TerrainSourceIdentity identity;

  /// Clockwise Y-down canonical loop in half-world-unit source ticks.
  final List<SourceTerrainPoint> sourceVertices;

  /// Transformed canonical loop in 1/1024-world-unit physics ticks.
  final List<TerrainPoint> vertices;

  /// Physical sidedness, independent from semantic metadata.
  final TerrainCollisionMode collisionMode;

  /// Optional gameplay surface classifier retained without interpretation.
  final String? surfaceKind;

  /// Optional material classifier retained without interpretation.
  final String? materialKey;

  @override
  bool operator ==(Object other) {
    if (other is! TerrainPolygon ||
        sourcePath != other.sourcePath ||
        identity != other.identity ||
        collisionMode != other.collisionMode ||
        surfaceKind != other.surfaceKind ||
        materialKey != other.materialKey ||
        sourceVertices.length != other.sourceVertices.length ||
        vertices.length != other.vertices.length) {
      return false;
    }
    for (var i = 0; i < vertices.length; i += 1) {
      if (sourceVertices[i] != other.sourceVertices[i] ||
          vertices[i] != other.vertices[i]) {
        return false;
      }
    }
    return true;
  }

  /// Object hashes are suitable for collections, never deterministic digests.
  @override
  int get hashCode => Object.hash(
    sourcePath,
    identity,
    collisionMode,
    surfaceKind,
    materialKey,
    Object.hashAll(sourceVertices),
    Object.hashAll(vertices),
  );
}

/// Stable runtime-safety diagnostic emitted before edge compilation.
class TerrainDiagnostic implements Comparable<TerrainDiagnostic> {
  const TerrainDiagnostic({
    required this.sourcePath,
    required this.shapeId,
    required this.elementIndex,
    required this.code,
    required this.message,
  });

  /// Stable source path used as the first diagnostic sort key.
  final String sourcePath;

  /// Stable source shape key used as the second diagnostic sort key.
  final String shapeId;

  /// Source element position used as the third diagnostic sort key.
  final int elementIndex;

  /// Machine-readable final diagnostic sort key.
  final String code;

  /// Human-readable explanation; excluded from diagnostic ordering.
  final String message;

  @override
  int compareTo(TerrainDiagnostic other) {
    var order = sourcePath.compareTo(other.sourcePath);
    if (order != 0) return order;
    order = shapeId.compareTo(other.shapeId);
    if (order != 0) return order;
    order = elementIndex.compareTo(other.elementIndex);
    if (order != 0) return order;
    return code.compareTo(other.code);
  }

  @override
  String toString() => '$sourcePath:$shapeId:$elementIndex:$code: $message';
}

/// Thrown with canonically ordered diagnostics when geometry is unsafe.
class TerrainValidationException implements Exception {
  TerrainValidationException(Iterable<TerrainDiagnostic> diagnostics)
    : diagnostics = List<TerrainDiagnostic>.unmodifiable(
        List<TerrainDiagnostic>.of(diagnostics)..sort(),
      );

  /// Immutable diagnostics in canonical source/shape/element/code order.
  final List<TerrainDiagnostic> diagnostics;

  @override
  String toString() => 'TerrainValidationException(${diagnostics.join('; ')})';
}
