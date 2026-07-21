/// Stable source lineage and total order for one compiled terrain edge.
///
/// Ordering is independent of object hash codes and is shared by compilation,
/// spatial candidates, signatures, and equal-time collision ties.
class TerrainEdgeId implements Comparable<TerrainEdgeId> {
  factory TerrainEdgeId({
    required int chunkIndex,
    required String chunkKey,
    required String shapeId,
    required int localEdgeIndex,
    String? placementKey,
    int subEdgeIndex = 0,
  }) {
    if (chunkKey.isEmpty || shapeId.isEmpty) {
      throw ArgumentError('Terrain edge keys must not be empty.');
    }
    if (placementKey != null && placementKey.isEmpty) {
      throw ArgumentError('A present placement key must not be empty.');
    }
    if (localEdgeIndex < 0 || subEdgeIndex < 0) {
      throw ArgumentError('Terrain edge indices must be non-negative.');
    }
    return TerrainEdgeId._(
      chunkIndex: chunkIndex,
      chunkKey: chunkKey,
      placementKey: placementKey,
      shapeId: shapeId,
      localEdgeIndex: localEdgeIndex,
      subEdgeIndex: subEdgeIndex,
    );
  }

  const TerrainEdgeId._({
    required this.chunkIndex,
    required this.chunkKey,
    required this.shapeId,
    required this.localEdgeIndex,
    required this.placementKey,
    required this.subEdgeIndex,
  });

  /// Signed authored chunk order; base terrain may use a negative index.
  final int chunkIndex;

  /// Stable chunk key within [chunkIndex].
  final String chunkKey;

  /// Stable placed-prefab selection key, or `null` for direct chunk source.
  final String? placementKey;

  /// Stable source shape key within the chunk or placement.
  final String shapeId;

  /// Edge position in the canonical source polygon loop.
  final int localEdgeIndex;

  /// Stable interval index when collinear splitting divides a source edge.
  final int subEdgeIndex;

  @override
  int compareTo(TerrainEdgeId other) {
    var order = chunkIndex.compareTo(other.chunkIndex);
    if (order != 0) return order;
    order = chunkKey.compareTo(other.chunkKey);
    if (order != 0) return order;
    order = _compareNullable(placementKey, other.placementKey);
    if (order != 0) return order;
    order = shapeId.compareTo(other.shapeId);
    if (order != 0) return order;
    order = localEdgeIndex.compareTo(other.localEdgeIndex);
    if (order != 0) return order;
    return subEdgeIndex.compareTo(other.subEdgeIndex);
  }

  @override
  bool operator ==(Object other) =>
      other is TerrainEdgeId &&
      chunkIndex == other.chunkIndex &&
      chunkKey == other.chunkKey &&
      placementKey == other.placementKey &&
      shapeId == other.shapeId &&
      localEdgeIndex == other.localEdgeIndex &&
      subEdgeIndex == other.subEdgeIndex;

  /// Collection hash only; canonical signatures serialize ordered fields.
  @override
  int get hashCode => Object.hash(
    chunkIndex,
    chunkKey,
    placementKey,
    shapeId,
    localEdgeIndex,
    subEdgeIndex,
  );

  /// Canonical text form used by diagnostics and signature records.
  String get canonicalKey =>
      '$chunkIndex/${_field(chunkKey)}/'
      '${placementKey == null ? '-' : _field(placementKey!)}/'
      '${_field(shapeId)}/$localEdgeIndex/$subEdgeIndex';

  @override
  String toString() => canonicalKey;
}

String _field(String value) => '${value.length}:$value';

int _compareNullable(String? left, String? right) {
  if (identical(left, right)) return 0;
  if (left == null) return -1;
  if (right == null) return 1;
  return left.compareTo(right);
}
