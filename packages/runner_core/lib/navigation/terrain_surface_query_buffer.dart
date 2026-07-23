import 'types/terrain_navigation_surface.dart';

/// Caller-owned scratch state for allocation-free surface-index queries.
///
/// A buffer grows only when used with a different surface count. Candidate
/// indices always refer to the canonical order of the queried
/// [TerrainSurfaceSet].
class TerrainSurfaceQueryBuffer {
  /// Creates scratch arrays with optional initial [surfaceCapacity].
  TerrainSurfaceQueryBuffer({int surfaceCapacity = 0})
    : _stamps = List<int>.filled(surfaceCapacity, 0),
      _candidateIndices = List<int>.filled(surfaceCapacity, 0);

  List<int> _stamps;
  List<int> _candidateIndices;
  int _generation = 0;
  int _candidateCount = 0;

  /// Counters from the most recent query.
  final TerrainSurfaceQueryStats stats = TerrainSurfaceQueryStats();

  /// Number of storage replacements since construction.
  int resizeCount = 0;

  /// Number of exact segment-bound candidates from the most recent query.
  int get candidateCount => _candidateCount;

  /// Returns one candidate from [canonicalSurfaces].
  TerrainNavigationSurface surfaceAt(
    int candidateIndex,
    List<TerrainNavigationSurface> canonicalSurfaces,
  ) {
    if (candidateIndex < 0 || candidateIndex >= _candidateCount) {
      throw RangeError.index(candidateIndex, this, 'candidateIndex');
    }
    return canonicalSurfaces[_candidateIndices[candidateIndex]];
  }

  /// Resets query state and grows storage only when [surfaceCount] changes.
  void prepare(int surfaceCount) {
    if (_stamps.length != surfaceCount) {
      _stamps = List<int>.filled(surfaceCount, 0);
      _candidateIndices = List<int>.filled(surfaceCount, 0);
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

  /// Marks [surfaceIndex] once for the current query generation.
  bool mark(int surfaceIndex) {
    if (_stamps[surfaceIndex] == _generation) return false;
    _stamps[surfaceIndex] = _generation;
    return true;
  }

  /// Appends one unique surface index before canonical sorting/filtering.
  void appendCandidateIndex(int surfaceIndex) {
    _candidateIndices[_candidateCount] = surfaceIndex;
    _candidateCount += 1;
  }

  /// Sorts candidates by the canonical surface-list index without allocating.
  void sortCandidateIndices() {
    for (var index = 1; index < _candidateCount; index += 1) {
      final value = _candidateIndices[index];
      var cursor = index - 1;
      while (cursor >= 0 && _candidateIndices[cursor] > value) {
        _candidateIndices[cursor + 1] = _candidateIndices[cursor];
        cursor -= 1;
      }
      _candidateIndices[cursor + 1] = value;
    }
  }

  /// Returns one raw canonical index for index-owned compaction.
  int candidateSurfaceIndexAt(int candidateIndex) =>
      _candidateIndices[candidateIndex];

  /// Writes one raw canonical index during exact-bound compaction.
  void writeCandidateSurfaceIndex(int candidateIndex, int surfaceIndex) {
    _candidateIndices[candidateIndex] = surfaceIndex;
  }

  /// Truncates the visible prefix after exact segment-bound filtering.
  void truncateCandidates(int count) {
    if (count < 0 || count > _candidateCount) {
      throw RangeError.range(count, 0, _candidateCount, 'count');
    }
    _candidateCount = count;
  }
}

/// Mutable counters populated without allocation by a surface-index query.
class TerrainSurfaceQueryStats {
  /// Closed grid cells traversed by the latest query.
  int cellsVisited = 0;

  /// Bucket references visited before stamp-based deduplication.
  int rawCandidates = 0;

  /// Exact segment-bound candidates retained by the latest query.
  int uniqueCandidates = 0;

  /// Clears counters without replacing this object.
  void reset() {
    cellsVisited = 0;
    rawCandidates = 0;
    uniqueCandidates = 0;
  }
}
