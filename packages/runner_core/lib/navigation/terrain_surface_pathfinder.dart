import '../collision/terrain/terrain_numeric.dart';
import 'types/terrain_surface_graph.dart';

/// Deterministic integer-cost A* over a [TerrainSurfaceGraph].
///
/// Working storage is retained across searches and generation-stamped, so a
/// warmed pathfinder does not clear or replace node-sized arrays per query.
class TerrainSurfacePathfinder {
  TerrainSurfacePathfinder({
    required this.maxExpandedNodes,
    this.edgePenaltyCostUnits = 0,
  }) {
    if (maxExpandedNodes <= 0 || edgePenaltyCostUnits < 0) {
      throw ArgumentError(
        'Pathfinder expansion bounds must be positive and penalties non-negative.',
      );
    }
  }

  final int maxExpandedNodes;
  final int edgePenaltyCostUnits;

  final List<int> _gScore = <int>[];
  final List<int> _fScore = <int>[];
  final List<int> _cameFromEdge = <int>[];
  final List<int> _cameFromNode = <int>[];
  final List<int> _open = <int>[];
  final List<int> _openStamp = <int>[];
  final List<int> _nodeGeneration = <int>[];
  final List<int> _reconstruct = <int>[];
  int _searchGeneration = 0;

  /// Nodes expanded by the most recent search.
  int lastExpandedNodeCount = 0;

  /// Finds an edge-index path and writes it in traversal order to [outEdges].
  bool findPath(
    TerrainSurfaceGraph graph, {
    required int startIndex,
    required int goalIndex,
    required List<int> outEdges,
    int? startBodyXTicks,
    int? goalBodyXTicks,
    int preferredDirectionX = 0,
    bool restrictToPreferredDirection = false,
  }) {
    if (startIndex < 0 || startIndex >= graph.surfaces.length) {
      throw RangeError.index(startIndex, graph.surfaces, 'startIndex');
    }
    if (goalIndex < 0 || goalIndex >= graph.surfaces.length) {
      throw RangeError.index(goalIndex, graph.surfaces, 'goalIndex');
    }
    if (preferredDirectionX < -1 || preferredDirectionX > 1) {
      throw ArgumentError.value(
        preferredDirectionX,
        'preferredDirectionX',
        'Must be -1, 0, or 1.',
      );
    }
    outEdges.clear();
    lastExpandedNodeCount = 0;
    if (!graph.eligibility[startIndex] || !graph.eligibility[goalIndex]) {
      return false;
    }
    if (startIndex == goalIndex) return true;

    _ensureSize(graph.surfaces.length);
    _nextGeneration();
    _touch(startIndex);
    _open.clear();
    _open.add(startIndex);
    _openStamp[startIndex] = _searchGeneration;
    _gScore[startIndex] = 0;
    _fScore[startIndex] = _heuristic(graph, startIndex, goalIndex);

    while (_open.isNotEmpty && lastExpandedNodeCount < maxExpandedNodes) {
      final current = _popBest(graph);
      if (current == goalIndex) {
        _reconstructPath(goalIndex, outEdges);
        return true;
      }
      lastExpandedNodeCount += 1;

      final originX = _originBodyX(
        graph,
        current,
        startIndex: startIndex,
        startBodyXTicks: startBodyXTicks,
      );
      final edgeStart = graph.edgeOffsets[current];
      final edgeEnd = graph.edgeOffsets[current + 1];
      for (var edgeIndex = edgeStart; edgeIndex < edgeEnd; edgeIndex += 1) {
        final edge = graph.edges[edgeIndex];
        if (restrictToPreferredDirection && preferredDirectionX != 0) {
          if (edge.commitDirectionX != preferredDirectionX) continue;
        }
        final neighbor = edge.to;
        _touch(neighbor);
        final approachCost = edge.kind == TerrainSurfaceEdgeKind.walk
            ? 0
            : _surfaceDistanceCost(
                graph,
                current,
                originX,
                edge.takeoffPoint.xTicks,
              );
        final goalAdjustment = neighbor == goalIndex && goalBodyXTicks != null
            ? _surfaceDistanceCost(
                graph,
                neighbor,
                edge.landingPoint.xTicks,
                goalBodyXTicks,
              )
            : 0;
        final tentative =
            _gScore[current] +
            edge.costUnits +
            approachCost +
            goalAdjustment +
            edgePenaltyCostUnits;
        final currentBest = _gScore[neighbor];
        if (tentative > currentBest ||
            (tentative == currentBest &&
                !_predecessorIsCanonicalImprovement(
                  graph,
                  candidateNode: current,
                  candidateEdge: edgeIndex,
                  currentNode: _cameFromNode[neighbor],
                  currentEdge: _cameFromEdge[neighbor],
                ))) {
          continue;
        }

        _cameFromEdge[neighbor] = edgeIndex;
        _cameFromNode[neighbor] = current;
        _gScore[neighbor] = tentative;
        _fScore[neighbor] = tentative + _heuristic(graph, neighbor, goalIndex);
        if (_openStamp[neighbor] != _searchGeneration) {
          _open.add(neighbor);
          _openStamp[neighbor] = _searchGeneration;
        }
      }
    }
    return false;
  }

  int _heuristic(TerrainSurfaceGraph graph, int from, int goal) {
    final fromSurface = graph.surfaces[from];
    final goalSurface = graph.surfaces[goal];
    final fromCenter = (fromSurface.xMinTicks + fromSurface.xMaxTicks) >> 1;
    final goalCenter = (goalSurface.xMinTicks + goalSurface.xMaxTicks) >> 1;
    final horizontalDistance = (goalCenter - fromCenter).abs();
    final airSpeedTicksPerSecond = physicsCoordinateToTicks(
      graph.buildProfile.jumpTemplate.profile.airSpeedX,
      name: 'jumpTemplate.profile.airSpeedX',
    );
    final fastestHorizontalSpeed =
        airSpeedTicksPerSecond >
            graph.buildProfile.locomotionSpeedTicksPerSecond
        ? airSpeedTicksPerSecond
        : graph.buildProfile.locomotionSpeedTicksPerSecond;
    return (horizontalDistance * terrainNavigationCostUnitsPerSecond) ~/
        fastestHorizontalSpeed;
  }

  int _originBodyX(
    TerrainSurfaceGraph graph,
    int nodeIndex, {
    required int startIndex,
    required int? startBodyXTicks,
  }) {
    if (nodeIndex == startIndex && startBodyXTicks != null) {
      return startBodyXTicks;
    }
    final predecessorEdge = _cameFromEdge[nodeIndex];
    if (predecessorEdge >= 0) {
      return graph.edges[predecessorEdge].landingPoint.xTicks;
    }
    final surface = graph.surfaces[nodeIndex];
    return (surface.xMinTicks + surface.xMaxTicks) >> 1;
  }

  int _surfaceDistanceCost(
    TerrainSurfaceGraph graph,
    int surfaceIndex,
    int fromBodyX,
    int toBodyX,
  ) {
    final surface = graph.surfaces[surfaceIndex];
    final clampedFrom = fromBodyX.clamp(surface.xMinTicks, surface.xMaxTicks);
    final clampedTo = toBodyX.clamp(surface.xMinTicks, surface.xMaxTicks);
    final horizontalDistance = (clampedTo - clampedFrom).abs();
    final distanceAlongSurface = _divideRoundNearest(
      horizontalDistance * surface.lengthTicks,
      surface.dxTicks,
    );
    return _divideRoundNearest(
      distanceAlongSurface * terrainNavigationCostUnitsPerSecond,
      graph.buildProfile.locomotionSpeedTicksPerSecond,
    );
  }

  bool _predecessorIsCanonicalImprovement(
    TerrainSurfaceGraph graph, {
    required int candidateNode,
    required int candidateEdge,
    required int currentNode,
    required int currentEdge,
  }) {
    if (currentNode < 0 || currentEdge < 0) return true;
    final nodeOrder = graph.surfaces[candidateNode].id.compareTo(
      graph.surfaces[currentNode].id,
    );
    if (nodeOrder != 0) return nodeOrder < 0;
    return compareTerrainSurfaceGraphEdges(
          graph.edges[candidateEdge],
          graph.edges[currentEdge],
          graph.surfaceSet,
        ) <
        0;
  }

  int _popBest(TerrainSurfaceGraph graph) {
    var bestListIndex = 0;
    var bestNode = _open.first;
    for (var index = 1; index < _open.length; index += 1) {
      final node = _open[index];
      if (_isBetter(graph, node, bestNode)) {
        bestListIndex = index;
        bestNode = node;
      }
    }
    final last = _open.removeLast();
    if (bestListIndex < _open.length) _open[bestListIndex] = last;
    _openStamp[bestNode] = 0;
    return bestNode;
  }

  bool _isBetter(TerrainSurfaceGraph graph, int left, int right) {
    final fOrder = _fScore[left].compareTo(_fScore[right]);
    if (fOrder != 0) return fOrder < 0;
    final gOrder = _gScore[left].compareTo(_gScore[right]);
    if (gOrder != 0) return gOrder < 0;
    return graph.surfaces[left].id.compareTo(graph.surfaces[right].id) < 0;
  }

  void _reconstructPath(int goalIndex, List<int> outEdges) {
    _reconstruct.clear();
    var current = goalIndex;
    while (_cameFromEdge[current] >= 0) {
      _reconstruct.add(_cameFromEdge[current]);
      current = _cameFromNode[current];
    }
    for (var index = _reconstruct.length - 1; index >= 0; index -= 1) {
      outEdges.add(_reconstruct[index]);
    }
  }

  void _ensureSize(int count) {
    while (_gScore.length < count) {
      _gScore.add(0);
      _fScore.add(0);
      _cameFromEdge.add(-1);
      _cameFromNode.add(-1);
      _openStamp.add(0);
      _nodeGeneration.add(0);
    }
  }

  void _nextGeneration() {
    _searchGeneration += 1;
    if (_searchGeneration == 0x7fffffff) {
      _nodeGeneration.fillRange(0, _nodeGeneration.length, 0);
      _openStamp.fillRange(0, _openStamp.length, 0);
      _searchGeneration = 1;
    }
  }

  void _touch(int index) {
    if (_nodeGeneration[index] == _searchGeneration) return;
    _nodeGeneration[index] = _searchGeneration;
    _gScore[index] = 0x7fffffffffffffff;
    _fScore[index] = 0x7fffffffffffffff;
    _cameFromEdge[index] = -1;
    _cameFromNode[index] = -1;
    _openStamp[index] = 0;
  }
}

int _divideRoundNearest(int numerator, int positiveDenominator) =>
    (numerator + positiveDenominator ~/ 2) ~/ positiveDenominator;
