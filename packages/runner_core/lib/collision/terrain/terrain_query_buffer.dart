import 'terrain_edge.dart';

/// Caller-owned scratch state for allocation-free terrain-index queries.
///
/// A buffer is bound to an index edge count on first use or rebuild. Repeated
/// queries then mutate only preallocated integer arrays and counters.
class TerrainQueryBuffer {
  TerrainQueryBuffer({int edgeCapacity = 0})
    : _stamps = List<int>.filled(edgeCapacity, 0),
      _candidateIndices = List<int>.filled(edgeCapacity, 0);

  List<int> _stamps;
  List<int> _candidateIndices;
  int _generation = 0;
  int _candidateCount = 0;

  /// Counters from the most recent query.
  final TerrainQueryStats stats = TerrainQueryStats();

  /// Number of storage replacements since construction.
  ///
  /// Steady-state query tests require this to remain unchanged.
  int resizeCount = 0;

  /// Number of unique canonical candidates from the most recent query.
  int get candidateCount => _candidateCount;

  /// Returns the candidate at [candidateIndex] from [canonicalEdges].
  TerrainEdge edgeAt(int candidateIndex, List<TerrainEdge> canonicalEdges) {
    if (candidateIndex < 0 || candidateIndex >= _candidateCount) {
      throw RangeError.index(candidateIndex, this, 'candidateIndex');
    }
    return canonicalEdges[_candidateIndices[candidateIndex]];
  }

  /// Resets query state and grows storage only when [edgeCount] changes.
  void prepare(int edgeCount) {
    if (_stamps.length != edgeCount) {
      _stamps = List<int>.filled(edgeCount, 0);
      _candidateIndices = List<int>.filled(edgeCount, 0);
      _generation = 0;
      resizeCount += 1;
    }
    _candidateCount = 0;
    stats.reset();
    _generation += 1;
    if (_generation == 0x7FFFFFFF) {
      _stamps.fillRange(0, _stamps.length, 0);
      _generation = 1;
    }
  }

  /// Marks [edgeIndex] once for the current query generation.
  ///
  /// Returns `true` only on its first occurrence.
  bool mark(int edgeIndex) {
    if (_stamps[edgeIndex] == _generation) return false;
    _stamps[edgeIndex] = _generation;
    return true;
  }

  /// Appends one unique edge index before canonical sorting/filtering.
  void appendCandidateIndex(int edgeIndex) {
    _candidateIndices[_candidateCount] = edgeIndex;
    _candidateCount += 1;
  }

  /// Sorts candidate indices numerically, matching canonical edge-list order.
  ///
  /// Candidate lists are intentionally small; insertion sort avoids comparator
  /// and temporary-list allocation in the query hot path.
  void sortCandidateIndices() {
    for (var i = 1; i < _candidateCount; i += 1) {
      final value = _candidateIndices[i];
      var cursor = i - 1;
      while (cursor >= 0 && _candidateIndices[cursor] > value) {
        _candidateIndices[cursor + 1] = _candidateIndices[cursor];
        cursor -= 1;
      }
      _candidateIndices[cursor + 1] = value;
    }
  }

  /// Returns a raw canonical edge index for index-owned compaction.
  int candidateEdgeIndexAt(int candidateIndex) =>
      _candidateIndices[candidateIndex];

  /// Writes a raw canonical edge index during index-owned compaction.
  void writeCandidateEdgeIndex(int candidateIndex, int edgeIndex) {
    _candidateIndices[candidateIndex] = edgeIndex;
  }

  /// Truncates the visible candidate prefix after exact AABB filtering.
  void truncateCandidates(int count) {
    assert(count >= 0 && count <= _candidateCount);
    _candidateCount = count;
  }
}

/// Mutable, allocation-free counters populated by a terrain-index query.
class TerrainQueryStats {
  /// Number of closed grid cells traversed by the latest query.
  int cellsVisited = 0;

  /// Total bucket entries visited before deduplication.
  int rawCandidates = 0;

  /// Exact-AABB candidates retained after deduplication.
  int uniqueCandidates = 0;

  /// Clears all counters without replacing this stats object.
  void reset() {
    cellsVisited = 0;
    rawCandidates = 0;
    uniqueCandidates = 0;
  }
}
