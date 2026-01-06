import 'surface_graph.dart';
import 'nav_tolerances.dart';

class SurfacePathfinder {
  SurfacePathfinder({
    required this.maxExpandedNodes,
    required this.runSpeedX,
    this.edgePenaltySeconds = 0.0,
  }) : assert(maxExpandedNodes > 0),
       assert(runSpeedX > 0),
       assert(edgePenaltySeconds >= 0.0);

  final int maxExpandedNodes;
  final double runSpeedX;
  final double edgePenaltySeconds;

  final List<double> _gScore = <double>[];
  final List<double> _fScore = <double>[];
  final List<int> _cameFromEdge = <int>[];
  final List<int> _cameFromNode = <int>[];
  final List<int> _open = <int>[];
  final List<int> _openStamp = <int>[];
  final List<int> _reconstruct = <int>[];
  final List<int> _nodeGenerations = <int>[];
  int _searchGeneration = 0;

  bool findPath(
    SurfaceGraph graph, {
    required int startIndex,
    required int goalIndex,
    required List<int> outEdges,
    double? startX,
    double? goalX,
  }) {
    outEdges.clear();
    if (startIndex == goalIndex) return true;

    _ensureSize(graph.surfaces.length);
    _searchGeneration += 1;

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

      final start = graph.edgeOffsets[current];
      final end = graph.edgeOffsets[current + 1];
      for (var ei = start; ei < end; ei += 1) {
        final edge = graph.edges[ei];
        final neighbor = edge.to;
        _touch(neighbor);
        final edgeCost = edge.cost +
            _runCost(
              graph,
              current,
              edge,
              startIndex: startIndex,
              startX: startX,
            ) +
            _goalLandingCost(
              edge,
              neighbor: neighbor,
              goalIndex: goalIndex,
              goalX: goalX,
            ) +
            edgePenaltySeconds;
        final tentative = _gScore[current] + edgeCost;
        if (tentative >= _gScore[neighbor]) continue;

        _cameFromEdge[neighbor] = ei;
        _cameFromNode[neighbor] = current;
        _gScore[neighbor] = tentative;
        _fScore[neighbor] =
            tentative + _heuristic(graph, neighbor, goalIndex);

        if (_openStamp[neighbor] != 1) {
          _open.add(neighbor);
          _openStamp[neighbor] = 1;
        }
      }
    }

    return false;
  }

  double _heuristic(SurfaceGraph graph, int from, int goal) {
    final dx = (graph.surfaces[goal].centerX - graph.surfaces[from].centerX).abs();
    return dx / runSpeedX;
  }

  double _runCost(
    SurfaceGraph graph,
    int fromIndex,
    SurfaceEdge edge, {
    required int startIndex,
    required double? startX,
  }) {
    final fromSurface = graph.surfaces[fromIndex];
    final originX =
        (fromIndex == startIndex && startX != null) ? startX : fromSurface.centerX;
    final dx = (edge.takeoffX - originX).abs();
    return dx / runSpeedX;
  }

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

    final last = _open.removeLast();
    if (bestIndex < _open.length) {
      _open[bestIndex] = last;
    }
    _openStamp[bestNode] = 0;
    return bestNode;
  }

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

  void _reconstructPath(int goalIndex, List<int> outEdges) {
    _reconstruct.clear();
    var current = goalIndex;
    while (_cameFromEdge[current] != -1) {
      _reconstruct.add(_cameFromEdge[current]);
      current = _cameFromNode[current];
    }
    for (var i = _reconstruct.length - 1; i >= 0; i -= 1) {
      outEdges.add(_reconstruct[i]);
    }
  }

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
