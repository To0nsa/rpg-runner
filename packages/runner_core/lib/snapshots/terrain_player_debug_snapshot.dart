import 'dart:collection';

import '../collision/terrain/capsule_segment_kernel.dart';
import '../collision/terrain/terrain_contact_policy.dart';
import '../collision/terrain/terrain_controller_diagnostic.dart';
import '../collision/terrain/terrain_edge_id.dart';

/// Immutable ordered blocker recorded by a terrain player solve.
class TerrainBlockingContactSnapshot {
  const TerrainBlockingContactSnapshot({
    required this.edgeId,
    required this.kind,
    required this.feature,
    required this.normalXTicks,
    required this.normalYTicks,
  });

  final TerrainEdgeId edgeId;
  final TerrainContactKind kind;
  final TerrainSegmentFeature feature;
  final int normalXTicks;
  final int normalYTicks;
}

/// On-demand, read-only diagnostic view of one terrain-integrated player.
///
/// Every numeric collision field is expressed in 1/1024-world-unit physics
/// ticks. Constructing this snapshot may allocate; the normal simulation tick
/// never constructs it.
class TerrainPlayerDebugSnapshot {
  TerrainPlayerDebugSnapshot({
    required this.entityId,
    required this.tick,
    required this.capsuleCenterXTicks,
    required this.capsuleCenterYTicks,
    required this.capsuleRadiusTicks,
    required this.capsuleVerticalHalfSegmentTicks,
    required this.requestedXTicks,
    required this.requestedYTicks,
    required this.gravityXTicks,
    required this.gravityYTicks,
    required this.resolvedXTicks,
    required this.resolvedYTicks,
    required this.supportedTravelTicks,
    required this.groundedLocomotionPhaseBp,
    required this.finalBodyXTicks,
    required this.finalBodyYTicks,
    required this.finalVelocityXTicks,
    required this.finalVelocityYTicks,
    required this.geometryVersion,
    required this.grounded,
    required this.supportEdgeId,
    required this.supportPointXTicks,
    required this.supportPointYTicks,
    required this.supportNormalXTicks,
    required this.supportNormalYTicks,
    required this.supportTangentXTicks,
    required this.supportTangentYTicks,
    required Iterable<TerrainBlockingContactSnapshot> blockingContacts,
    required this.hitLeft,
    required this.hitRight,
    required this.hitCeiling,
    required this.wallNormalXTicks,
    required this.wallNormalYTicks,
    required this.ceilingNormalXTicks,
    required this.ceilingNormalYTicks,
    required this.usedStep,
    required this.usedSnap,
    required this.usedRecovery,
    required this.contactIterations,
    required this.recoveryIterations,
    required this.candidateCount,
    required this.queryCellsVisited,
    required this.diagnostic,
  }) : blockingContacts = UnmodifiableListView<TerrainBlockingContactSnapshot>(
         List<TerrainBlockingContactSnapshot>.of(blockingContacts),
       );

  final int entityId;
  final int tick;
  final int capsuleCenterXTicks;
  final int capsuleCenterYTicks;
  final int capsuleRadiusTicks;
  final int capsuleVerticalHalfSegmentTicks;
  final int requestedXTicks;
  final int requestedYTicks;
  final int gravityXTicks;
  final int gravityYTicks;
  final int resolvedXTicks;
  final int resolvedYTicks;
  final int supportedTravelTicks;
  final int groundedLocomotionPhaseBp;
  final int finalBodyXTicks;
  final int finalBodyYTicks;
  final int finalVelocityXTicks;
  final int finalVelocityYTicks;
  final int geometryVersion;
  final bool grounded;
  final TerrainEdgeId? supportEdgeId;
  final int supportPointXTicks;
  final int supportPointYTicks;
  final int supportNormalXTicks;
  final int supportNormalYTicks;
  final int supportTangentXTicks;
  final int supportTangentYTicks;
  final List<TerrainBlockingContactSnapshot> blockingContacts;
  final bool hitLeft;
  final bool hitRight;
  final bool hitCeiling;
  final int wallNormalXTicks;
  final int wallNormalYTicks;
  final int ceilingNormalXTicks;
  final int ceilingNormalYTicks;
  final bool usedStep;
  final bool usedSnap;
  final bool usedRecovery;
  final int contactIterations;
  final int recoveryIterations;
  final int candidateCount;
  final int queryCellsVisited;
  final TerrainControllerDiagnostic diagnostic;
}
