/// Stable source lineage and total order for one compiled terrain edge.
///
/// Ordering is independent of object hash codes and is shared by compilation,
/// spatial candidates, signatures, and equal-time collision ties.
class TerrainEdgeId implements Comparable<TerrainEdgeId> {
  const TerrainEdgeId({
    required this.chunkIndex,
    required this.chunkKey,
    required this.shapeId,
    required this.localEdgeIndex,
    this.placementKey,
    this.subEdgeIndex = 0,
  }) : assert(chunkKey != ''),
       assert(shapeId != ''),
       assert(localEdgeIndex >= 0),
       assert(subEdgeIndex >= 0);

  final int chunkIndex;
  final String chunkKey;

  /// Stable placed-prefab selection key, or `null` for direct chunk source.
  final String? placementKey;

  final String shapeId;
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
      '$chunkIndex/$chunkKey/${placementKey ?? "-"}/$shapeId/'
      '$localEdgeIndex/$subEdgeIndex';

  @override
  String toString() => canonicalKey;
}

int _compareNullable(String? left, String? right) {
  if (identical(left, right)) return 0;
  if (left == null) return -1;
  if (right == null) return 1;
  return left.compareTo(right);
}
