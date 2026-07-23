import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../collision/terrain/terrain_edge_id.dart';
import '../../collision/terrain/terrain_numeric.dart';
import '../../collision/terrain/terrain_traversal_profile.dart';
import '../terrain_placement_query.dart';
import '../utils/jump_template.dart';
import 'terrain_navigation_surface.dart';

/// Stable traversal kind shared by the future sloped graph consumers.
enum TerrainSurfaceEdgeKind { walk, jump, drop }

/// Immutable profile inputs used to derive one graph view.
class TerrainSurfaceGraphBuildProfile {
  factory TerrainSurfaceGraphBuildProfile({
    required String profileKey,
    required TerrainTraversalProfile traversalProfile,
    required int radiusTicks,
    required int verticalHalfSegmentTicks,
    required int authoredOffsetXTicks,
    required int offsetYTicks,
    required TerrainSupportRequirement supportRequirement,
    required int locomotionSpeedTicksPerSecond,
    required JumpReachabilityTemplate jumpTemplate,
    int simulationTicksPerSecond = 60,
  }) {
    if (profileKey.isEmpty) {
      throw ArgumentError.value(profileKey, 'profileKey', 'Must not be empty.');
    }
    if (radiusTicks <= 0 || verticalHalfSegmentTicks < 0) {
      throw ArgumentError('Graph profile capsule dimensions are invalid.');
    }
    if (locomotionSpeedTicksPerSecond <= 0 || simulationTicksPerSecond <= 0) {
      throw ArgumentError(
        'Graph profile speeds and tick rate must be positive.',
      );
    }
    if (traversalProfile.isKinematic ||
        !traversalProfile.useGravity ||
        !traversalProfile.groundedMobilityHelpersEnabled) {
      throw ArgumentError(
        'Ordinary surface graphs require a grounded dynamic traversal profile.',
      );
    }
    if (supportRequirement.kind !=
        TerrainSupportRequirementKind.runtimeNavigation) {
      throw ArgumentError(
        'Ordinary surface graphs require a runtime support fraction.',
      );
    }
    final jump = jumpTemplate.profile;
    if (!jump.jumpSpeed.isFinite ||
        !jump.gravityY.isFinite ||
        !jump.airSpeedX.isFinite ||
        jump.jumpSpeed <= 0 ||
        jump.gravityY <= 0 ||
        jump.airSpeedX <= 0 ||
        jump.maxAirTicks <= 0) {
      throw ArgumentError(
        'Jump-template speed, gravity, and air-tick inputs must be positive.',
      );
    }
    final jumpHalfWidthTicks = physicsCoordinateToTicks(
      jump.agentHalfWidth,
      name: 'jumpTemplate.profile.agentHalfWidth',
    );
    final jumpHalfHeightTicks = physicsCoordinateToTicks(
      jump.effectiveHalfHeight,
      name: 'jumpTemplate.profile.agentHalfHeight',
    );
    if (jumpHalfWidthTicks != radiusTicks ||
        jumpHalfHeightTicks != radiusTicks + verticalHalfSegmentTicks) {
      throw ArgumentError(
        'Jump-template dimensions must match the graph capsule.',
      );
    }
    final expectedSupportFraction =
        supportRequirement.numerator / supportRequirement.denominator;
    if ((jump.requiredSupportFraction - expectedSupportFraction).abs() >
        1e-12) {
      throw ArgumentError(
        'Jump-template foothold must match the graph support requirement.',
      );
    }
    if ((jump.dtSeconds * simulationTicksPerSecond - 1).abs() > 1e-12) {
      throw ArgumentError(
        'Jump-template timestep must match the graph simulation rate.',
      );
    }
    if (jump.collideCeilings != traversalProfile.collideCeilings ||
        jump.collideLeftWalls != traversalProfile.collideLeftWalls ||
        jump.collideRightWalls != traversalProfile.collideRightWalls) {
      throw ArgumentError(
        'Jump-template collision masks must match the traversal profile.',
      );
    }
    return TerrainSurfaceGraphBuildProfile._(
      profileKey: profileKey,
      traversalProfile: traversalProfile,
      radiusTicks: radiusTicks,
      verticalHalfSegmentTicks: verticalHalfSegmentTicks,
      authoredOffsetXTicks: authoredOffsetXTicks,
      offsetYTicks: offsetYTicks,
      supportRequirement: supportRequirement,
      locomotionSpeedTicksPerSecond: locomotionSpeedTicksPerSecond,
      jumpTemplate: jumpTemplate,
      simulationTicksPerSecond: simulationTicksPerSecond,
    );
  }

  const TerrainSurfaceGraphBuildProfile._({
    required this.profileKey,
    required this.traversalProfile,
    required this.radiusTicks,
    required this.verticalHalfSegmentTicks,
    required this.authoredOffsetXTicks,
    required this.offsetYTicks,
    required this.supportRequirement,
    required this.locomotionSpeedTicksPerSecond,
    required this.jumpTemplate,
    required this.simulationTicksPerSecond,
  });

  final String profileKey;
  final TerrainTraversalProfile traversalProfile;
  final int radiusTicks;
  final int verticalHalfSegmentTicks;

  /// Authored right-facing offset; left-facing traversal mirrors its sign.
  final int authoredOffsetXTicks;
  final int offsetYTicks;
  final TerrainSupportRequirement supportRequirement;

  /// Constant distance-along-surface speed in physics ticks per second.
  final int locomotionSpeedTicksPerSecond;

  /// Existing semi-implicit-Euler reachability template used by runtime AI.
  final JumpReachabilityTemplate jumpTemplate;

  /// Fixed simulation frequency used only to estimate integer travel ticks.
  final int simulationTicksPerSecond;

  /// Resolves the body-relative capsule offset for a signed walk direction.
  TerrainPlacementCapsule capsuleForDirection(int directionX) {
    if (directionX != -1 && directionX != 1) {
      throw ArgumentError.value(directionX, 'directionX', 'Must be -1 or 1.');
    }
    return TerrainPlacementCapsule(
      radiusTicks: radiusTicks,
      verticalHalfSegmentTicks: verticalHalfSegmentTicks,
      resolvedOffsetXTicks: authoredOffsetXTicks * directionX,
      offsetYTicks: offsetYTicks,
    );
  }
}

/// Directed CSR edge using integer geometry and quantized time cost.
class TerrainSurfaceGraphEdge {
  /// Builds an ordinary walk edge from exact surface distance and speed.
  factory TerrainSurfaceGraphEdge.walk({
    required int to,
    required TerrainPoint takeoffPoint,
    required TerrainPoint landingPoint,
    required int commitDirectionX,
    required int distanceTicks,
    required int locomotionSpeedTicksPerSecond,
    required int simulationTicksPerSecond,
  }) {
    if (distanceTicks <= 0 || locomotionSpeedTicksPerSecond <= 0) {
      throw ArgumentError('Walk distance and speed must be positive.');
    }
    final travelTicks = _divideCeil(
      distanceTicks * simulationTicksPerSecond,
      locomotionSpeedTicksPerSecond,
    );
    final quantizedCost = _divideRoundNearest(
      distanceTicks * terrainNavigationCostUnitsPerSecond,
      locomotionSpeedTicksPerSecond,
    );
    return TerrainSurfaceGraphEdge._(
      to: to,
      kind: TerrainSurfaceEdgeKind.walk,
      takeoffPoint: takeoffPoint,
      landingPoint: landingPoint,
      commitDirectionX: commitDirectionX,
      travelTicks: travelTicks,
      distanceTicks: distanceTicks,
      costUnits: quantizedCost > 0 ? quantizedCost : 1,
    );
  }

  /// Builds a jump/drop edge whose cost is its deterministic travel time.
  factory TerrainSurfaceGraphEdge.airborne({
    required int to,
    required TerrainSurfaceEdgeKind kind,
    required TerrainPoint takeoffPoint,
    required TerrainPoint landingPoint,
    required int commitDirectionX,
    required int travelTicks,
    required int simulationTicksPerSecond,
  }) {
    if (kind == TerrainSurfaceEdgeKind.walk) {
      throw ArgumentError('Airborne edges must be jump or drop.');
    }
    if (travelTicks <= 0 || simulationTicksPerSecond <= 0) {
      throw ArgumentError(
        'Airborne travel ticks and tick rate must be positive.',
      );
    }
    return TerrainSurfaceGraphEdge._(
      to: to,
      kind: kind,
      takeoffPoint: takeoffPoint,
      landingPoint: landingPoint,
      commitDirectionX: commitDirectionX,
      travelTicks: travelTicks,
      distanceTicks: 0,
      costUnits: _divideRoundNearest(
        travelTicks * terrainNavigationCostUnitsPerSecond,
        simulationTicksPerSecond,
      ),
    );
  }

  const TerrainSurfaceGraphEdge._({
    required this.to,
    required this.kind,
    required this.takeoffPoint,
    required this.landingPoint,
    required this.commitDirectionX,
    required this.travelTicks,
    required this.distanceTicks,
    required this.costUnits,
  }) : assert(commitDirectionX == -1 || commitDirectionX == 1);

  /// Destination index in the graph's shared canonical surface list.
  final int to;
  final TerrainSurfaceEdgeKind kind;

  /// Body centers in authoritative physics ticks.
  final TerrainPoint takeoffPoint;
  final TerrainPoint landingPoint;

  final int commitDirectionX;
  final int travelTicks;

  /// Walk distance in physics ticks; airborne edges store zero.
  final int distanceTicks;

  /// Quantized seconds where one second equals one million units.
  final int costUnits;
}

/// Number of deterministic graph-cost units in one second.
const int terrainNavigationCostUnitsPerSecond = 1000000;

/// One immutable profile view over a shared canonical surface set.
class TerrainSurfaceGraph {
  factory TerrainSurfaceGraph({
    required TerrainSurfaceSet surfaceSet,
    required TerrainSurfaceGraphBuildProfile buildProfile,
    required Iterable<bool> eligibility,
    required Iterable<int> edgeOffsets,
    required Iterable<TerrainSurfaceGraphEdge> edges,
  }) {
    final eligible = List<bool>.of(eligibility);
    final offsets = List<int>.of(edgeOffsets);
    final edgeList = List<TerrainSurfaceGraphEdge>.of(edges);
    final nodeCount = surfaceSet.surfaces.length;
    if (eligible.length != nodeCount || offsets.length != nodeCount + 1) {
      throw ArgumentError(
        'Graph eligibility/CSR dimensions do not match nodes.',
      );
    }
    if (offsets.first != 0 || offsets.last != edgeList.length) {
      throw ArgumentError(
        'Graph CSR offsets must span the complete edge list.',
      );
    }
    for (var source = 0; source < nodeCount; source += 1) {
      final start = offsets[source];
      final end = offsets[source + 1];
      if (start < 0 || start > end || end > edgeList.length) {
        throw ArgumentError('Graph CSR offsets must be monotonic and bounded.');
      }
      TerrainSurfaceGraphEdge? previous;
      for (var edgeIndex = start; edgeIndex < end; edgeIndex += 1) {
        final edge = edgeList[edgeIndex];
        if (edge.to < 0 || edge.to >= nodeCount) {
          throw ArgumentError('Graph edge destination is out of bounds.');
        }
        if (!eligible[source] || !eligible[edge.to]) {
          throw ArgumentError(
            'Graph edges require eligible source/destination.',
          );
        }
        if (previous != null &&
            compareTerrainSurfaceGraphEdges(previous, edge, surfaceSet) >= 0) {
          throw ArgumentError(
            'Each CSR row must be uniquely canonically sorted.',
          );
        }
        previous = edge;
      }
    }
    return TerrainSurfaceGraph._(
      surfaceSet: surfaceSet,
      buildProfile: buildProfile,
      eligibility: UnmodifiableListView<bool>(eligible),
      edgeOffsets: UnmodifiableListView<int>(offsets),
      edges: UnmodifiableListView<TerrainSurfaceGraphEdge>(edgeList),
    );
  }

  const TerrainSurfaceGraph._({
    required this.surfaceSet,
    required this.buildProfile,
    required this.eligibility,
    required this.edgeOffsets,
    required this.edges,
  });

  final TerrainSurfaceSet surfaceSet;
  final TerrainSurfaceGraphBuildProfile buildProfile;
  final List<bool> eligibility;
  final List<int> edgeOffsets;
  final List<TerrainSurfaceGraphEdge> edges;

  String get profileKey => buildProfile.profileKey;
  int get geometryVersion => surfaceSet.geometryVersion;
  List<TerrainNavigationSurface> get surfaces => surfaceSet.surfaces;

  int? indexOfSurfaceId(TerrainEdgeId id) => surfaceSet.indexOfId(id);

  Iterable<TerrainSurfaceGraphEdge> edgesFor(int surfaceIndex) sync* {
    if (surfaceIndex < 0 || surfaceIndex >= surfaces.length) {
      throw RangeError.index(surfaceIndex, surfaces, 'surfaceIndex');
    }
    for (
      var edgeIndex = edgeOffsets[surfaceIndex];
      edgeIndex < edgeOffsets[surfaceIndex + 1];
      edgeIndex += 1
    ) {
      yield edges[edgeIndex];
    }
  }

  /// Canonical integer records for the `nav-graphs-v1` content signature.
  List<String> canonicalRecords() {
    final traversal = buildProfile.traversalProfile;
    final records = <String>[
      _canonicalRecord(<String>[
        'nav-graphs-v1',
        profileKey,
        buildProfile.radiusTicks.toString(),
        buildProfile.verticalHalfSegmentTicks.toString(),
        buildProfile.authoredOffsetXTicks.toString(),
        buildProfile.offsetYTicks.toString(),
        buildProfile.supportRequirement.kind.name,
        buildProfile.supportRequirement.numerator.toString(),
        buildProfile.supportRequirement.denominator.toString(),
        buildProfile.locomotionSpeedTicksPerSecond.toString(),
        buildProfile.simulationTicksPerSecond.toString(),
        physicsCoordinateToTicks(
          buildProfile.jumpTemplate.profile.jumpSpeed,
        ).toString(),
        physicsCoordinateToTicks(
          buildProfile.jumpTemplate.profile.gravityY,
        ).toString(),
        physicsCoordinateToTicks(
          buildProfile.jumpTemplate.profile.airSpeedX,
        ).toString(),
        buildProfile.jumpTemplate.profile.maxAirTicks.toString(),
        buildProfile.jumpTemplate.profile.collideCeilings ? '1' : '0',
        buildProfile.jumpTemplate.profile.collideLeftWalls ? '1' : '0',
        buildProfile.jumpTemplate.profile.collideRightWalls ? '1' : '0',
        traversal.minimumSupportUpComponent.toString(),
        traversal.stepHeightTicks.toString(),
        traversal.snapDistanceTicks.toString(),
        traversal.oneWaySupportEnabled ? '1' : '0',
      ]),
    ];
    for (var nodeIndex = 0; nodeIndex < surfaces.length; nodeIndex += 1) {
      records.add(
        _canonicalRecord(<String>[
          'nav-graphs-v1-node',
          profileKey,
          nodeIndex.toString(),
          surfaces[nodeIndex].id.canonicalKey,
          eligibility[nodeIndex] ? '1' : '0',
          edgeOffsets[nodeIndex].toString(),
          edgeOffsets[nodeIndex + 1].toString(),
        ]),
      );
      for (final edge in edgesFor(nodeIndex)) {
        records.add(
          _canonicalRecord(<String>[
            'nav-graphs-v1-edge',
            profileKey,
            surfaces[nodeIndex].id.canonicalKey,
            surfaces[edge.to].id.canonicalKey,
            edge.kind.name,
            edge.takeoffPoint.xTicks.toString(),
            edge.takeoffPoint.yTicks.toString(),
            edge.landingPoint.xTicks.toString(),
            edge.landingPoint.yTicks.toString(),
            edge.commitDirectionX.toString(),
            edge.travelTicks.toString(),
            edge.distanceTicks.toString(),
            edge.costUnits.toString(),
          ]),
        );
      }
    }
    return List<String>.unmodifiable(records);
  }

  String signature() =>
      sha256.convert(utf8.encode(canonicalRecords().join('\n'))).toString();
}

/// Validated publication of multiple profile views over one node instance.
class TerrainSurfaceGraphPublication {
  factory TerrainSurfaceGraphPublication(
    Iterable<TerrainSurfaceGraph> graphViews,
  ) {
    final graphs = List<TerrainSurfaceGraph>.of(graphViews)
      ..sort((left, right) => left.profileKey.compareTo(right.profileKey));
    if (graphs.isEmpty) {
      throw ArgumentError(
        'A graph publication must contain at least one view.',
      );
    }
    final sharedSet = graphs.first.surfaceSet;
    for (var index = 0; index < graphs.length; index += 1) {
      if (!identical(graphs[index].surfaceSet, sharedSet)) {
        throw ArgumentError(
          'Published graph views must share the exact same surface set.',
        );
      }
      if (index > 0 &&
          graphs[index - 1].profileKey == graphs[index].profileKey) {
        throw ArgumentError('Published graph profile keys must be unique.');
      }
    }
    return TerrainSurfaceGraphPublication._(
      surfaceSet: sharedSet,
      graphs: UnmodifiableListView<TerrainSurfaceGraph>(graphs),
      byProfileKey: Map<String, TerrainSurfaceGraph>.unmodifiable(
        <String, TerrainSurfaceGraph>{
          for (final graph in graphs) graph.profileKey: graph,
        },
      ),
    );
  }

  const TerrainSurfaceGraphPublication._({
    required this.surfaceSet,
    required this.graphs,
    required Map<String, TerrainSurfaceGraph> byProfileKey,
  }) : _byProfileKey = byProfileKey;

  final TerrainSurfaceSet surfaceSet;
  final List<TerrainSurfaceGraph> graphs;
  final Map<String, TerrainSurfaceGraph> _byProfileKey;

  int get geometryVersion => surfaceSet.geometryVersion;

  TerrainSurfaceGraph operator [](String profileKey) {
    final graph = _byProfileKey[profileKey];
    if (graph == null) {
      throw StateError('No terrain graph view exists for $profileKey.');
    }
    return graph;
  }

  List<String> canonicalRecords() => List<String>.unmodifiable(<String>[
    for (final graph in graphs) ...graph.canonicalRecords(),
  ]);

  String signature() =>
      sha256.convert(utf8.encode(canonicalRecords().join('\n'))).toString();
}

/// Canonical row order used by builders and validated graph construction.
int compareTerrainSurfaceGraphEdges(
  TerrainSurfaceGraphEdge left,
  TerrainSurfaceGraphEdge right,
  TerrainSurfaceSet surfaceSet,
) {
  final destinationOrder = surfaceSet.surfaces[left.to].id.compareTo(
    surfaceSet.surfaces[right.to].id,
  );
  if (destinationOrder != 0) return destinationOrder;
  final kindOrder = left.kind.index.compareTo(right.kind.index);
  if (kindOrder != 0) return kindOrder;
  final takeoffXOrder = left.takeoffPoint.xTicks.compareTo(
    right.takeoffPoint.xTicks,
  );
  if (takeoffXOrder != 0) return takeoffXOrder;
  final takeoffYOrder = left.takeoffPoint.yTicks.compareTo(
    right.takeoffPoint.yTicks,
  );
  if (takeoffYOrder != 0) return takeoffYOrder;
  final landingXOrder = left.landingPoint.xTicks.compareTo(
    right.landingPoint.xTicks,
  );
  if (landingXOrder != 0) return landingXOrder;
  final landingYOrder = left.landingPoint.yTicks.compareTo(
    right.landingPoint.yTicks,
  );
  if (landingYOrder != 0) return landingYOrder;
  return left.commitDirectionX.compareTo(right.commitDirectionX);
}

int _divideCeil(int numerator, int positiveDenominator) =>
    (numerator + positiveDenominator - 1) ~/ positiveDenominator;

int _divideRoundNearest(int numerator, int positiveDenominator) =>
    (numerator + positiveDenominator ~/ 2) ~/ positiveDenominator;

String _canonicalRecord(List<String> fields) =>
    fields.map((field) => '${utf8.encode(field).length}:$field').join('|');
