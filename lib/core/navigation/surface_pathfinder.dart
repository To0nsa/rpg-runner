import 'types/surface_graph.dart';
import 'types/nav_tolerances.dart';

/// A* pathfinder for surface-based navigation graphs.
///
/// **Algorithm**: Standard A* with:
/// - Admissible heuristic: straight-line horizontal distance / run speed.
/// - Edge costs: transition cost + run distance to takeoff + landing adjustment.
/// - Tie-breaking: lower g-score, then surface ID for determinism.
///
/// **Optimizations**:
/// - Generation-stamp pattern avoids clearing arrays between searches.
/// - Reusable working lists grow once, persist across queries.
/// - Linear open-list scan (adequate for small graphs; swap to binary heap
///   if graph size grows significantly).
///
/// **Usage**:
/// ```dart
/// final pathfinder = SurfacePathfinder(maxExpandedNodes: 500, runSpeedX: 200);
/// final edges = <int>[];
/// if (pathfinder.findPath(graph, startIndex: s, goalIndex: g, outEdges: edges)) {
///   // edges contains edge indices from start to goal.
/// }
/// ```
class SurfacePathfinder {
  SurfacePathfinder({
    required this.maxExpandedNodes,
    required this.runSpeedX,
    this.edgePenaltySeconds = 0.0,
  }) : assert(maxExpandedNodes > 0),
       assert(runSpeedX > 0),
       assert(edgePenaltySeconds >= 0.0);

  /// Maximum nodes to expand before giving up (prevents runaway searches).
  final int maxExpandedNodes;

  /// Horizontal run speed (pixels/second) for cost calculations.
  final double runSpeedX;

  /// Flat penalty added to every edge (discourages excessive transitions).
  final double edgePenaltySeconds;

  // ---------------------------------------------------------------------------
  // Working arrays (reused across searches via generation stamps).
  // ---------------------------------------------------------------------------

  /// Cost from start to each node (g-score).
  final List<double> _gScore = <double>[];

  /// Estimated total cost through each node (f = g + h).
  final List<double> _fScore = <double>[];

  /// Edge index used to reach each node (-1 = start or unvisited).
  final List<int> _cameFromEdge = <int>[];

  /// Predecessor node index (-1 = start or unvisited).
  final List<int> _cameFromNode = <int>[];

  /// Open set (nodes pending expansion).
  final List<int> _open = <int>[];

  /// 1 if node is in open set this search, 0 otherwise.
  final List<int> _openStamp = <int>[];

  /// Scratch space for path reconstruction.
  final List<int> _reconstruct = <int>[];

  /// Generation stamp per node (matches [_searchGeneration] if valid).
  final List<int> _nodeGenerations = <int>[];

  /// Incremented each search to invalidate stale node data.
  int _searchGeneration = 0;

  /// Finds a path from [startIndex] to [goalIndex] in [graph].
  ///
  /// **Parameters**:
  /// - [startIndex], [goalIndex]: Surface indices in [graph.surfaces].
  /// - [outEdges]: Receives ordered edge indices from start to goal.
  /// - [startX], [goalX]: Optional precise X positions for cost accuracy.
  /// - [preferredDirectionX]: Preferred horizontal edge direction (-1/0/+1).
  /// - [restrictToPreferredDirection]: When `true`, edges that explicitly move
  ///   opposite to [preferredDirectionX] are ignored.
  ///
  /// **Returns**: `true` if a path was found, `false` otherwise.
  bool findPath(
    SurfaceGraph graph, {
    required int startIndex,
    required int goalIndex,
    required List<int> outEdges,
    double? startX,
    double? goalX,
    int preferredDirectionX = 0,
    bool restrictToPreferredDirection = false,
  }) {
    assert(preferredDirectionX >= -1 && preferredDirectionX <= 1);
    outEdges.clear();
    if (startIndex == goalIndex) return true;

    _ensureSize(graph.surfaces.length);
    _searchGeneration += 1;

    // Initialize start node.
    _touch(startIndex);
    _open.clear();
    _open.add(startIndex);
    _openStamp[startIndex] = 1;
    _gScore[startIndex] = 0.0;
    _fScore[startIndex] = _heuristic(graph, startIndex, goalIndex);

    var expanded = 0;
    while (_open.isNotEmpty && expanded < maxExpandedNodes) {
      final current = _popBest(graph);
      if (current == goalIndex) {
        _reconstructPath(goalIndex, outEdges);
        return true;
      }

      expanded += 1;

      // Iterate outgoing edges (CSR format).
      final start = graph.edgeOffsets[current];
      final end = graph.edgeOffsets[current + 1];
      final originX = _originX(
        graph,
        current,
        startIndex: startIndex,
        startX: startX,
      );
      for (var ei = start; ei < end; ei += 1) {
        final edge = graph.edges[ei];
        if (restrictToPreferredDirection && preferredDirectionX != 0) {
          final edgeDirX = _edgeDirectionX(edge);
          if (edgeDirX != 0 && edgeDirX != preferredDirectionX) {
            continue;
          }
        }
        final neighbor = edge.to;
        _touch(neighbor);

        // Total edge cost: base + run-to-takeoff + landing adjustment + penalty.
        final edgeCost =
            edge.cost +
            _runCost(edge, originX: originX) +
            _goalLandingCost(
              edge,
              neighbor: neighbor,
              goalIndex: goalIndex,
              goalX: goalX,
            ) +
            edgePenaltySeconds;

        final tentative = _gScore[current] + edgeCost;
        if (tentative >= _gScore[neighbor]) continue;

        // Better path found—update neighbor.
        _cameFromEdge[neighbor] = ei;
        _cameFromNode[neighbor] = current;
        _gScore[neighbor] = tentative;
        _fScore[neighbor] = tentative + _heuristic(graph, neighbor, goalIndex);

        // Add to open set if not already present.
        if (_openStamp[neighbor] != 1) {
          _open.add(neighbor);
          _openStamp[neighbor] = 1;
        }
      }
    }

    return false; // No path found within expansion limit.
  }

  /// Admissible heuristic: horizontal distance / run speed.
  ///
  /// Ignores vertical distance (platforms can be reached by jumps/falls
  /// with minimal time penalty relative to horizontal travel).
  double _heuristic(SurfaceGraph graph, int from, int goal) {
    final dx = (graph.surfaces[goal].centerX - graph.surfaces[from].centerX)
        .abs();
    return dx / runSpeedX;
  }

  /// Effective horizontal origin used when leaving [nodeIndex].
  ///
  /// Uses predecessor landing position when available, so path costs reflect
  /// where the entity actually arrives on intermediate surfaces.
  double _originX(
    SurfaceGraph graph,
    int nodeIndex, {
    required int startIndex,
    required double? startX,
  }) {
    if (nodeIndex == startIndex && startX != null) {
      return startX;
    }
    final fromEdge = _cameFromEdge[nodeIndex];
    if (fromEdge >= 0) {
      return graph.edges[fromEdge].landingX;
    }
    return graph.surfaces[nodeIndex].centerX;
  }

  /// Cost to run from current position to edge takeoff point.
  double _runCost(SurfaceEdge edge, {required double originX}) {
    final dx = (edge.takeoffX - originX).abs();
    return dx / runSpeedX;
  }

  /// Resolved horizontal direction for an edge: -1, 0, or +1.
  int _edgeDirectionX(SurfaceEdge edge) {
    if (edge.commitDirX != 0) return edge.commitDirX;
    final dx = edge.landingX - edge.takeoffX;
    if (dx > 0.0) return 1;
    if (dx < 0.0) return -1;
    return 0;
  }

  /// Additional cost for landing distance to goal (only on final edge).
  double _goalLandingCost(
    SurfaceEdge edge, {
    required int neighbor,
    required int goalIndex,
    required double? goalX,
  }) {
    if (goalX == null) return 0.0;
    if (neighbor != goalIndex) return 0.0;
    final dx = (edge.landingX - goalX).abs();
    return dx / runSpeedX;
  }

  /// Extracts and removes the node with lowest f-score from [_open].
  ///
  /// Uses linear scan (O(n)) which is fine for small open sets.
  /// For larger graphs, consider a binary heap.
  int _popBest(SurfaceGraph graph) {
    var bestIndex = 0;
    var bestNode = _open[0];
    for (var i = 1; i < _open.length; i += 1) {
      final node = _open[i];
      if (_isBetter(graph, node, bestNode)) {
        bestIndex = i;
        bestNode = node;
      }
    }

    // Swap-remove: replace extracted element with last, then pop.
    final last = _open.removeLast();
    if (bestIndex < _open.length) {
      _open[bestIndex] = last;
    }
    _openStamp[bestNode] = 0;
    return bestNode;
  }

  /// Compares two nodes for priority (lower f-score wins).
  ///
  /// Tie-breaking order:
  /// 1. Lower f-score.
  /// 2. Lower g-score (prefer nodes closer to start).
  /// 3. Lower surface ID (determinism).
  bool _isBetter(SurfaceGraph graph, int a, int b) {
    final fa = _fScore[a];
    final fb = _fScore[b];
    if (fa < fb - navTieEps) return true;
    if (fa > fb + navTieEps) return false;
    final ga = _gScore[a];
    final gb = _gScore[b];
    if (ga < gb - navTieEps) return true;
    if (ga > gb + navTieEps) return false;
    return graph.surfaces[a].id < graph.surfaces[b].id;
  }

  /// Reconstructs path by walking [_cameFromEdge] back to start.
  ///
  /// Edges are collected in reverse order, then reversed into [outEdges].
  void _reconstructPath(int goalIndex, List<int> outEdges) {
    _reconstruct.clear();
    var current = goalIndex;
    while (_cameFromEdge[current] != -1) {
      _reconstruct.add(_cameFromEdge[current]);
      current = _cameFromNode[current];
    }
    // Reverse into output.
    for (var i = _reconstruct.length - 1; i >= 0; i -= 1) {
      outEdges.add(_reconstruct[i]);
    }
  }

  /// Grows working arrays to accommodate [count] nodes.
  void _ensureSize(int count) {
    while (_gScore.length < count) {
      _gScore.add(double.infinity);
      _fScore.add(double.infinity);
      _cameFromEdge.add(-1);
      _cameFromNode.add(-1);
      _openStamp.add(0);
      _nodeGenerations.add(0);
    }
  }

  /// Lazily initializes node data for the current search generation.
  ///
  /// Avoids O(n) clearing of all arrays between searches.
  void _touch(int index) {
    if (_nodeGenerations[index] != _searchGeneration) {
      _gScore[index] = double.infinity;
      _fScore[index] = double.infinity;
      _cameFromEdge[index] = -1;
      _cameFromNode[index] = -1;
      _openStamp[index] = 0;
      _nodeGenerations[index] = _searchGeneration;
    }
  }
}
